import AVFoundation
import CoreVideo
import Foundation

/// iOS 11 capture pipeline. Session and file operations are serialized off main.
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    struct State {
        var ready = false
        var busy = false
        var message = "Accesso alla fotocamera…"
        var lastPhoto: URL?
    }

    let session = AVCaptureSession()
    /// Set on main before calling start(); callbacks are always delivered on main.
    var onChange: ((State) -> Void)?
    private let queue = DispatchQueue(label: "camera.legacy.session")
    private let output = AVCapturePhotoOutput()
    private var state = State()
    private var configured = false
    private var wantsRunning = false
    private var rawFormat: OSType?
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        for name in [AVCaptureSession.wasInterruptedNotification,
                     AVCaptureSession.interruptionEndedNotification,
                     AVCaptureSession.runtimeErrorNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: session, queue: nil
            ) { [weak self] notification in
                let name = notification.name
                self?.queue.async { [weak self] in
                    guard let owner = self else { return }
                    if name == AVCaptureSession.interruptionEndedNotification {
                        owner.startIfNeeded()
                    } else {
                        owner.state.ready = false
                        owner.state.message = "Fotocamera interrotta. Torna all’app per riprovare."
                        owner.publish()
                    }
                }
            })
        }
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    func start() {
        queue.async {
            self.wantsRunning = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: self.startIfNeeded()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.queue.async {
                        if granted { self.startIfNeeded() }
                        else { self.permissionDenied() }
                    }
                }
            default: self.permissionDenied()
            }
        }
    }

    func stop() {
        queue.async {
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            self.state.ready = false
            self.publish()
        }
    }

    private func permissionDenied() {
        state.ready = false
        state.message = "Consenti l’accesso alla fotocamera nelle Impostazioni."
        publish()
    }

    private func startIfNeeded() {
        guard wantsRunning else { return }
        do {
            if !configured { try configure() }
            if !session.isRunning { session.startRunning() }
            state.ready = session.isRunning && !session.isInterrupted && rawFormat != nil
            if rawFormat == nil {
                state.message = "RAW Bayer non disponibile sulla fotocamera posteriore 1×. Nessuna foto elaborata verrà salvata."
            } else if !state.ready {
                state.message = "Fotocamera non disponibile. Riapri l’app per riprovare."
            } else {
                state.message = "RAW Bayer • DNG originale • fotocamera 1×"
            }
        } catch {
            state.ready = false
            state.message = error.localizedDescription
        }
        publish()
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.unavailable
        }
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            session.commitConfiguration()
            throw CameraError.unavailable
        }
        session.addOutput(output)
        session.commitConfiguration()
        // Bayer only. ProRAW is not requested, including when run on newer iOS.
        rawFormat = output.availableRawPhotoPixelFormatTypes.first {
            CameraController.isBayerFormat($0)
        }
        configured = true
    }

    func capture() {
        queue.async {
            guard self.state.ready, !self.state.busy, self.wantsRunning,
                  self.session.isRunning, !self.session.isInterrupted,
                  let format = self.rawFormat else { return }
            self.state.busy = true
            self.publish()
            let settings = AVCapturePhotoSettings(rawPixelFormatType: format)
            settings.flashMode = .off
            settings.isAutoStillImageStabilizationEnabled = false
            if let connection = self.output.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            report("Scatto fallito: \(error.localizedDescription)")
            return
        }
        guard photo.isRawPhoto, let buffer = photo.pixelBuffer,
              CameraController.isBayerFormat(CVPixelBufferGetPixelFormatType(buffer)),
              let data = photo.fileDataRepresentation() else {
            report("Nessun RAW Bayer valido ricevuto. Il file non è stato salvato.")
            return
        }
        queue.async {
            do {
                let directory = try FileManager.default.url(for: .documentDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("RAW", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("RAW-\(UUID().uuidString).dng")
                try data.write(to: url, options: .atomic)
                self.state.lastPhoto = url
                self.state.message = "DNG salvato in File → Raw Camera Legacy → RAW."
            } catch {
                self.state.message = "Salvataggio fallito: \(error.localizedDescription)"
            }
            self.publish()
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        queue.async {
            self.state.busy = false
            if let error = error { self.state.message = "Scatto fallito: \(error.localizedDescription)" }
            self.publish()
        }
    }

    private func report(_ message: String) {
        queue.async {
            self.state.message = message
            self.publish()
        }
    }

    private func publish() {
        let snapshot = state
        DispatchQueue.main.async { self.onChange?(snapshot) }
    }

    private static func isBayerFormat(_ format: OSType) -> Bool {
        // Apple's convenience predicate was introduced in iOS 14.3, not iOS 11.
        if #available(iOS 14.3, *) {
            return AVCapturePhotoOutput.isBayerRAWPixelFormat(format)
        }
        // These four 14-bit Bayer layouts are available from iOS 10.
        return [kCVPixelFormatType_14Bayer_GRBG, kCVPixelFormatType_14Bayer_RGGB,
                kCVPixelFormatType_14Bayer_BGGR, kCVPixelFormatType_14Bayer_GBRG].contains(format)
    }

    private enum CameraError: LocalizedError {
        case unavailable
        var errorDescription: String? { return "Fotocamera posteriore non disponibile." }
    }
}
