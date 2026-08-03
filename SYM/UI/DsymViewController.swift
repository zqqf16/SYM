import Cocoa
import Combine
import SnapKit

private class DsymTableRowView: NSTableCellView {
    let statusImage = NSImageView()
    let titleField = NSTextField(labelWithString: "")
    let uuidField = NSTextField(labelWithString: "")
    let pathField = NSTextField(labelWithString: "")
    let actionButton = NSButton(title: "", target: nil, action: nil)

    var binary: BinaryImage?
    var dsym: DsymFile?
    weak var rowDelegate: DsymViewController?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        titleField.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        uuidField.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        pathField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        pathField.lineBreakMode = .byTruncatingMiddle
        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(didClickAction)

        addSubview(statusImage)
        addSubview(titleField)
        addSubview(uuidField)
        addSubview(pathField)
        addSubview(actionButton)

        statusImage.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
        titleField.snp.makeConstraints { make in
            make.leading.equalTo(statusImage.snp.trailing).offset(8)
            make.top.equalToSuperview().offset(6)
            make.trailing.equalTo(actionButton.snp.leading).offset(-8)
        }
        uuidField.snp.makeConstraints { make in
            make.leading.equalTo(titleField)
            make.top.equalTo(titleField.snp.bottom).offset(2)
            make.trailing.equalTo(titleField)
        }
        pathField.snp.makeConstraints { make in
            make.leading.equalTo(titleField)
            make.top.equalTo(uuidField.snp.bottom).offset(2)
            make.trailing.equalTo(titleField)
            make.bottom.equalToSuperview().offset(-6)
        }
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(72)
        }
    }

    func updateUI() {
        guard let binary else { return }
        titleField.stringValue = binary.name
        uuidField.stringValue = binary.uuid ?? ""
        if let path = dsym?.path {
            pathField.stringValue = path
            statusImage.image = .symDsymFound
            actionButton.title = NSLocalizedString("Reveal", comment: "Reveal in Finder")
        } else {
            pathField.stringValue = NSLocalizedString("dsym_file_not_found", comment: "Dsym file not found")
            statusImage.image = .symDsymMissing
            actionButton.title = NSLocalizedString("Import", comment: "Import a dSYM file")
        }
    }

    @objc private func didClickAction(_ sender: NSButton) {
        guard let binary else { return }
        if dsym?.path != nil {
            rowDelegate?.revealDsym(for: binary)
        } else {
            rowDelegate?.importDsym(for: binary)
        }
    }
}

class DsymViewController: NSViewController {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let downloadButton = NSButton(title: NSLocalizedString("Download", comment: ""), target: nil, action: nil)
    private let progressBar = NSProgressIndicator()

    private var binaries: [BinaryImage] = [] {
        didSet { reloadData() }
    }

    private var dsymFiles: [String: DsymFile] = [:] {
        didSet { reloadData() }
    }

    private var dsymStorage = Set<AnyCancellable>()
    private var taskCancellable: AnyCancellable?

    var dsymManager: DsymManager? {
        didSet {
            dsymStorage.forEach { $0.cancel() }
            dsymManager?.$binaries
                .receive(on: DispatchQueue.main)
                .assign(to: \.binaries, on: self)
                .store(in: &dsymStorage)

            dsymManager?.$dsymFiles
                .receive(on: DispatchQueue.main)
                .assign(to: \.dsymFiles, on: self)
                .store(in: &dsymStorage)
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 360))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.title = "Binary Images"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 72
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAutomaticRowHeights = false

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        progressBar.isIndeterminate = true
        progressBar.isHidden = true

        downloadButton.target = self
        downloadButton.action = #selector(didClickDownloadButton(_:))

        view.addSubview(scrollView)
        view.addSubview(downloadButton)
        view.addSubview(progressBar)

        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(downloadButton.snp.top).offset(-12)
        }
        downloadButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        progressBar.snp.makeConstraints { make in
            make.leading.equalTo(downloadButton.snp.trailing).offset(12)
            make.centerY.equalTo(downloadButton)
            make.width.equalTo(200)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        downloadButton.isEnabled = dsymManager?.crash != nil
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        taskCancellable?.cancel()
        dsymStorage.forEach { $0.cancel() }
    }

    func bind(task: DsymDownloadTask?) {
        taskCancellable?.cancel()
        guard let downloadTask = task else { return }
        taskCancellable = Publishers
            .CombineLatest(downloadTask.$status, downloadTask.$progress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status, progress in
                self?.update(status: status, progress: progress)
            }
    }

    private func reloadData() {
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    private func dsymFile(forBinary binary: BinaryImage) -> DsymFile? {
        guard let uuid = binary.uuid else { return nil }
        return dsymManager?.dsymFile(withUuid: uuid)
    }

    @objc private func didClickDownloadButton(_: NSButton) {
        if let crashInfo = dsymManager?.crash {
            DsymDownloader.shared.download(crashInfo: crashInfo, fileURL: nil)
        }
    }

    func importDsym(for binary: BinaryImage) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.begin { [weak self] result in
            guard result == .OK, let url = openPanel.url else { return }
            self?.dsymManager?.assign(binary, dsymFileURL: url)
        }
    }

    func revealDsym(for binary: BinaryImage) {
        guard let dsym = dsymFile(forBinary: binary) else { return }
        let path = dsym.path
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func update(status: DsymDownloadTask.Status, progress: DsymDownloadTask.Progress) {
        switch status {
        case .running:
            downloadButton.isEnabled = false
            progressBar.isHidden = false
        case .canceled, .failed:
            progressBar.isHidden = true
            downloadButton.isEnabled = true
        case .success:
            progressBar.isHidden = true
        case .waiting:
            progressBar.isHidden = false
            progressBar.isIndeterminate = true
            progressBar.startAnimation(nil)
            downloadButton.isEnabled = false
        }
        if progress.percentage == 0 {
            progressBar.isIndeterminate = true
        } else {
            progressBar.isIndeterminate = false
            progressBar.doubleValue = Double(progress.percentage)
        }
    }
}

extension DsymViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int {
        binaries.count
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let cell: DsymTableRowView
        if let existing = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("DsymRow"), owner: self) as? DsymTableRowView {
            cell = existing
        } else {
            cell = DsymTableRowView()
            cell.identifier = NSUserInterfaceItemIdentifier("DsymRow")
        }
        let binary = binaries[row]
        cell.binary = binary
        cell.dsym = dsymFile(forBinary: binary)
        cell.rowDelegate = self
        cell.updateUI()
        return cell
    }

    func tableView(_: NSTableView, shouldSelectRow _: Int) -> Bool {
        false
    }
}
