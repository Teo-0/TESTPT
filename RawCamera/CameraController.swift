import AVFoundation
import Combine
import CoreVideo
import Foundation

/// All capture-session mutations run on sessionQueue; UI state is published on main.
final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message = "Accesso alla fotocamera…"
    @Published private(set) var lastPhoto: URL?

    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let output = AVCapturePhotoOutput()
    private var configured = false
    private var wantsRunning = false
    private var capturing = false
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
                self?.sessionQueue.async { [weak self] in
                    guard let self else { return }
                    if name == AVCaptureSession.interruptionEndedNotification {
                        self.startIfNeeded()
                    } else {
                        self.publish(ready: false, message: "Fotocamera interrotta. Torna all’app per riprovare.")
                    }
                }
            })
        }
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    func start() {
        sessionQueue.async {
            self.wantsRunning = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: self.startIfNeeded()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.sessionQueue.async {
                        if granted { self.startIfNeeded() }
                        else { self.publish(ready: false, message: "Consenti l’accesso alla fotocamera nelle Impostazioni.") }
                    }
                }
            default:
                self.publish(ready: false, message: "Consenti l’accesso alla fotocamera nelle Impostazioni.")
            }
        }
    }

    func stop() {
        sessionQueue.async {
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            self.publish(ready: false)
        }
    }

    private func startIfNeeded() {
        guard wantsRunning else { return }
        do {
            if !configured { try configure() }
            if !session.isRunning { session.startRunning() }
            guard session.isRunning, !session.isInterrupted else {
                publish(ready: false, message: "Fotocamera non disponibile. Riapri l’app per riprovare.")
                return
            }
            publish(ready: rawFormat != nil, message: rawFormat == nil
                ? "Questo dispositivo non espone RAW Bayer sulla fotocamera posteriore 1×. Nessuna foto elaborata verrà salvata."
                : "RAW Bayer • DNG originale • fotocamera 1×")
        } catch {
            publish(ready: false, message: error.localizedDescription)
        }
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
        // Apple ProRAW includes computational processing: never enable or select it.
        if output.isAppleProRAWSupported { output.isAppleProRAWEnabled = false }
        output.maxPhotoQualityPrioritization = .speed
        session.commitConfiguration()
        rawFormat = output.availableRawPhotoPixelFormatTypes.first {
            AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
        }
        configured = true
    }

    func capture() {
        sessionQueue.async {
            guard self.wantsRunning, self.session.isRunning, !self.session.isInterrupted,
                  !self.capturing, let format = self.rawFormat else { return }
            self.capturing = true
            DispatchQueue.main.async { self.busy = true }
            // RAW only: do not request a processed companion representation.
            let settings = AVCapturePhotoSettings(rawPixelFormatType: format)
            settings.flashMode = .off
            settings.photoQualityPrioritization = .speed
            settings.isAutoStillImageStabilizationEnabled = false
            if let connection = self.output.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            publish(message: "Scatto fallito: \(error.localizedDescription)")
            return
        }
        guard photo.isRawPhoto,
              AVCapturePhotoOutput.isBayerRAWPixelFormat(photo.pixelBuffer.map {
                  CVPixelBufferGetPixelFormatType($0)
              } ?? 0), let data = photo.fileDataRepresentation() else {
            publish(message: "Nessun RAW Bayer valido ricevuto. Il file non è stato salvato.")
            return
        }
        // Move file I/O off the capture callback and retain the exact DNG bytes.
        sessionQueue.async {
            do {
                let directory = try FileManager.default.url(for: .documentDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("RAW", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("RAW-\(UUID().uuidString).dng")
                try data.write(to: url, options: .atomic)
                DispatchQueue.main.async {
                    self.lastPhoto = url
                    self.message = "DNG originale salvato in File → Raw Camera → RAW."
                }
            } catch {
                self.publish(message: "Salvataggio fallito: \(error.localizedDescription)")
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        sessionQueue.async {
            self.capturing = false
            DispatchQueue.main.async { self.busy = false }
            if let error { self.publish(message: "Scatto fallito: \(error.localizedDescription)") }
        }
    }

    private func publish(ready: Bool? = nil, message: String? = nil) {
        DispatchQueue.main.async {
            if let ready { self.ready = ready }
            if let message { self.message = message }
        }
    }

    private enum CameraError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Fotocamera posteriore non disponibile." }
    }
}
