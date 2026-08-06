import Cocoa
import Combine
import SnapKit

protocol DownloadStatusViewControllerDelegate: AnyObject {
    func cancelDownload()
    @discardableResult
    func startDownloading() -> Bool
    func currentDownloadTask() -> DsymDownloadTask?
}

class DownloadStatusViewController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let infoLabel = NSTextField(labelWithString: "")
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let downloadButton = NSButton(title: NSLocalizedString("Download", comment: ""), target: nil, action: nil)

    weak var delegate: DownloadStatusViewControllerDelegate?
    private var taskCancellable: AnyCancellable?
    private var status: DsymDownloadTask.Status?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 120))

        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        infoLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        infoLabel.lineBreakMode = .byTruncatingTail

        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelDownload(_:))

        downloadButton.bezelStyle = .rounded
        downloadButton.target = self
        downloadButton.action = #selector(startDownloading(_:))
        downloadButton.toolTip = DsymDownloader.downloadActionToolTip

        progressIndicator.isIndeterminate = true

        view.addSubview(titleLabel)
        view.addSubview(progressIndicator)
        view.addSubview(infoLabel)
        view.addSubview(cancelButton)
        view.addSubview(downloadButton)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
        }
        progressIndicator.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        infoLabel.snp.makeConstraints { make in
            make.top.equalTo(progressIndicator.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        downloadButton.snp.makeConstraints { make in
            make.top.equalTo(infoLabel.snp.bottom).offset(10)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }
        cancelButton.snp.makeConstraints { make in
            make.centerY.equalTo(downloadButton)
            make.trailing.equalTo(downloadButton.snp.leading).offset(-8)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        taskCancellable?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind(task: delegate?.currentDownloadTask())
    }

    func bind(task: DsymDownloadTask?) {
        guard isViewLoaded else { return }
        taskCancellable?.cancel()

        guard let downloadTask = task else {
            titleLabel.stringValue = ""
            infoLabel.stringValue = ""
            progressIndicator.isHidden = true
            cancelButton.isHidden = true
            downloadButton.isHidden = false
            downloadButton.toolTip = DsymDownloader.downloadActionToolTip
            return
        }

        downloadButton.isHidden = true
        taskCancellable = Publishers
            .CombineLatest(downloadTask.$status, downloadTask.$progress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status, progress in
                self?.update(status: status, progress: progress)
            }
    }

    func update(status: DsymDownloadTask.Status, progress: DsymDownloadTask.Progress) {
        self.status = status
        switch status {
        case .running:
            cancelButton.isHidden = false
            progressIndicator.isHidden = false
            cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            var title = NSLocalizedString("download_prefix", comment: "Downloading ...")
            if progress.percentage > 0 {
                title += " \(progress.percentage)%"
                progressIndicator.isIndeterminate = false
                progressIndicator.doubleValue = Double(progress.percentage)
            } else {
                progressIndicator.isIndeterminate = true
            }
            infoLabel.stringValue = "\(progress.downloadedSize)/\(progress.totalSize) \(progress.timeLeft) \(progress.speed)/s"
            titleLabel.stringValue = title
        case .canceled:
            titleLabel.stringValue = NSLocalizedString("Canceled", comment: "Canceled")
            infoLabel.stringValue = ""
            cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
        case let .failed(code, message):
            let prefix = NSLocalizedString("Failed", comment: "Failed")
            titleLabel.stringValue = "\(prefix) (\(code))"
            infoLabel.stringValue = message ?? ""
            cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
        case .success:
            titleLabel.stringValue = NSLocalizedString("Success", comment: "Success")
            infoLabel.stringValue = ""
            cancelButton.isHidden = true
        case .waiting:
            titleLabel.stringValue = NSLocalizedString("Waiting", comment: "Waiting ...")
            infoLabel.stringValue = ""
            progressIndicator.isIndeterminate = true
            progressIndicator.isHidden = false
            cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            cancelButton.isHidden = false
        }
    }

    @objc func startDownloading(_: Any?) {
        delegate?.startDownloading()
    }

    @objc func cancelDownload(_: Any?) {
        guard let status else { return }
        switch status {
        case .canceled, .failed:
            delegate?.startDownloading()
        case .running, .waiting:
            delegate?.cancelDownload()
        case .success:
            break
        }
    }
}
