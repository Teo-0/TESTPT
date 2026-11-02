import AVFoundation
import UIKit

final class CameraViewController: UIViewController {
    private let camera = CameraController()
    private let preview = PreviewView()
    private let status = UILabel()
    private let shutter = UIButton(type: .system)
    private let share = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .white)
    private var lastPhoto: URL?
    private var observers: [NSObjectProtocol] = []
    private var visible = false

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let title = label("RAW CAMERA LEGACY", size: 21)
        let subtitle = label("iOS 11+ · RAW BAYER · DNG", size: 12)
        subtitle.textColor = .yellow
        let explanation = label("L’anteprima è elaborata da iOS. Il DNG contiene il RAW Bayer, senza filtri aggiunti dall’app.", size: 13)
        explanation.textColor = .lightGray
        status.textColor = .white
        status.numberOfLines = 0
        status.font = .systemFont(ofSize: 15)
        status.accessibilityIdentifier = "cameraStatus"
        preview.previewLayer.session = camera.session
        preview.previewLayer.videoGravity = .resizeAspectFill
        preview.clipsToBounds = true
        preview.layer.cornerRadius = 16
        shutter.setTitle("Scatta RAW", for: .normal)
        shutter.titleLabel?.font = .boldSystemFont(ofSize: 20)
        shutter.backgroundColor = UIColor(white: 0.18, alpha: 1)
        shutter.layer.cornerRadius = 12
        shutter.heightAnchor.constraint(equalToConstant: 56).isActive = true
        shutter.addTarget(self, action: #selector(capture), for: .touchUpInside)
        share.setTitle("Condividi DNG", for: .normal)
        share.addTarget(self, action: #selector(sharePhoto), for: .touchUpInside)
        let settings = UIButton(type: .system)
        settings.setTitle("Impostazioni", for: .normal)
        settings.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [share, settings])
        actions.distribution = .fillEqually
        let stack = UIStackView(arrangedSubviews: [title, subtitle, preview, explanation, status, spinner, shutter, actions])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            preview.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
        // The preview absorbs remaining space, leaving controls visible on iPhone 8.
        preview.setContentHuggingPriority(.defaultLow, for: .vertical)
        spinner.hidesWhenStopped = true
        camera.onChange = { [weak self] state in
            guard let owner = self else { return }
            owner.status.text = state.message
            owner.shutter.isEnabled = state.ready && !state.busy
            owner.shutter.alpha = owner.shutter.isEnabled ? 1 : 0.4
            owner.lastPhoto = state.lastPhoto
            owner.share.isEnabled = state.lastPhoto != nil
            if state.busy { owner.spinner.startAnimating() } else { owner.spinner.stopAnimating() }
        }
        shutter.isEnabled = false
        share.isEnabled = false
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let owner = self, owner.visible else { return }
            owner.camera.start()
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.camera.stop() })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        visible = true
        if UIApplication.shared.applicationState == .active { camera.start() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        visible = false
        camera.stop()
    }

    @objc private func capture() { camera.capture() }

    @objc private func sharePhoto() {
        guard let url = lastPhoto else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = share
        sheet.popoverPresentationController?.sourceRect = share.bounds
        present(sheet, animated: true)
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func label(_ text: String, size: CGFloat) -> UILabel {
        let result = UILabel()
        result.text = text
        result.textColor = .white
        result.font = .systemFont(ofSize: size)
        result.numberOfLines = 0
        return result
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { return AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { return layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}
