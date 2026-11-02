#!/usr/bin/env python3
"""Build reproducible, separate source downloads. No Xcode or dependencies needed."""
import argparse
import io
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSIONS = {
    "ios17": ("RawCamera", "modern.md"),
    "ios11": ("RawCameraLegacy", "legacy.md"),
}


def archive(version):
    project, instructions = VERSIONS[version]
    entries = {"README.md": ROOT / "distribution" / instructions}
    for folder in (project, project + ".xcodeproj"):
        allowed_suffixes = {".swift", ".plist"} if folder == project else {".pbxproj", ".xcscheme"}
        for path in sorted((ROOT / folder).rglob("*")):
            if path.is_symlink():
                raise ValueError("Symlinks are not allowed in source archives")
            if not path.is_file() or "xcuserdata" in path.parts or path.suffix == ".xcuserstate":
                continue
            # Never package provisioning profiles, signing keys, or build products.
            if path.suffix not in allowed_suffixes:
                continue
            entries[path.relative_to(ROOT).as_posix()] = path
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED) as output:
        for name, path in sorted(entries.items()):
            entry = zipfile.ZipInfo(project + "/" + name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            output.writestr(entry, path.read_bytes())
    return buffer.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if published ZIPs differ from current sources")
    args = parser.parse_args()
    for version in VERSIONS:
        path = ROOT / "docs" / "downloads" / ("raw-camera-" + version + "-source.zip")
        data = archive(version)
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                print("Missing or stale source download: " + str(path), file=sys.stderr)
                return 1
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        print(("Verified " if args.check else "Created ") + path.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
