import AVFoundation
import SwiftUI
import UIKit

struct CameraView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("RAW CAMERA").font(.headline)
                Spacer()
                Text("BAYER DNG").font(.caption.monospaced()).foregroundStyle(.yellow)
            }
            CameraPreview(session: camera.session)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("Anteprima fotocamera")
            Text("L’anteprima è elaborata da iOS. Il DNG salvato contiene il RAW Bayer, senza filtri aggiunti dall’app.")
                .font(.caption).foregroundStyle(.secondary)
            Text(camera.message)
                .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("cameraStatus")
            Spacer(minLength: 0)
            HStack {
                if let url = camera.lastPhoto {
                    ShareLink(item: url) { Label("DNG", systemImage: "square.and.arrow.up") }
                        .accessibilityLabel("Condividi l’ultimo DNG originale")
                }
                Spacer()
                Button(action: camera.capture) {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 3).frame(width: 76, height: 76)
                        if camera.busy { ProgressView().tint(.white) }
                        else { Circle().fill(.white).frame(width: 62, height: 62) }
                    }
                }
                .disabled(!camera.ready || camera.busy)
                .opacity(camera.ready ? 1 : 0.35)
                .accessibilityLabel("Scatta foto RAW")
                Spacer()
                Button { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } label: {
                    Image(systemName: "gearshape").font(.title2)
                }.accessibilityLabel("Apri impostazioni dell’app")
            }
        }
        .padding().background(.black).foregroundStyle(.white).preferredColorScheme(.dark)
        .onAppear { if scenePhase == .active { camera.start() } }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { camera.start() } else { camera.stop() }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}
