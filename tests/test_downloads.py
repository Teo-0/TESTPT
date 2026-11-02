"""Functional checks for the actual downloadable packages and static site."""
import functools
from html.parser import HTMLParser
import http.server
import io
from pathlib import Path
import plistlib
import subprocess
import sys
import threading
import unittest
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.downloads = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "download" in attrs:
            self.downloads.append(attrs["href"])


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


class DownloadsTests(unittest.TestCase):
    def test_downloads_match_current_sources(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/package_downloads.py"), "--check"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_both_choices_download_complete_separate_projects_over_http(self):
        handler = functools.partial(QuietHandler, directory=str(ROOT / "docs"))
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                base = "http://127.0.0.1:%d/" % server.server_address[1]
                with urllib.request.urlopen(base) as response:
                    self.assertEqual(response.status, 200)
                    page = response.read().decode("utf-8")
                parser = Links()
                parser.feed(page)
                expected = {
                    "downloads/raw-camera-ios11-source.zip": ("RawCameraLegacy", "AppDelegate.swift"),
                    "downloads/raw-camera-ios17-source.zip": ("RawCamera", "RawCameraApp.swift"),
                }
                self.assertCountEqual(parser.downloads, expected)
                for href, (project, entrypoint) in expected.items():
                    with self.subTest(download=href):
                        with urllib.request.urlopen(base + href) as response:
                            self.assertEqual(response.status, 200)
                            body = response.read()
                        with zipfile.ZipFile(io.BytesIO(body)) as archive:
                            self.assertIsNone(archive.testzip())
                            names = set(archive.namelist())
                            prefix = project + "/"
                            required = {
                                prefix + "README.md",
                                prefix + project + "/" + entrypoint,
                                prefix + project + "/CameraController.swift",
                                prefix + project + "/Info.plist",
                                prefix + project + ".xcodeproj/project.pbxproj",
                                prefix + project + ".xcodeproj/xcshareddata/xcschemes/" + project + ".xcscheme",
                            }
                            self.assertTrue(required.issubset(names), required - names)
                            for name in names:
                                self.assertTrue(name.startswith(prefix))
                                self.assertNotIn("..", Path(name).parts)
                                self.assertNotIn("xcuserdata", Path(name).parts)
                                if name != prefix + "README.md":
                                    original = ROOT / name[len(prefix):]
                                    self.assertEqual(archive.read(name), original.read_bytes())
                            info = plistlib.loads(archive.read(prefix + project + "/Info.plist"))
                            self.assertTrue(info["NSCameraUsageDescription"])
                            self.assertTrue(info["UIFileSharingEnabled"])
                            ET.fromstring(archive.read(prefix + project + ".xcodeproj/xcshareddata/xcschemes/" + project + ".xcscheme"))
                            other = "RawCamera" if project == "RawCameraLegacy" else "RawCameraLegacy"
                            self.assertFalse(any(name.startswith(prefix + other + "/") for name in names))
            finally:
                server.shutdown()
                thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
