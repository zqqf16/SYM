import Cocoa
import Combine
import SnapKit

private class DsymTableRowView: NSTableCellView {
    let statusImage = NSImageView()
    let titleField = NSTextField(labelWithString: "")
    let uuidField = NSTextField(labelWithString: "")
    let pathField = NSTextField(labelWithString: "")
    let actionButton = NSButton(
        title: NSLocalizedString("Import", comment: "Import a dSYM file"),
        target: nil,
        action: nil
    )

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
        titleField.lineBreakMode = .byTruncatingTail
        uuidField.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        uuidField.textColor = .secondaryLabelColor
        pathField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        pathField.textColor = .secondaryLabelColor
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Compact control like the old storyboard prototype (inline + small).
        actionButton.bezelStyle = .inline
        actionButton.setButtonType(.momentaryPushIn)
        actionButton.isBordered = true
        actionButton.controlSize = .small
        actionButton.font = .boldSystemFont(ofSize: 10)
        actionButton.setContentHuggingPriority(.required, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
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
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
        }
        uuidField.snp.makeConstraints { make in
            make.leading.equalTo(titleField)
            make.top.equalTo(titleField.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualToSuperview().offset(-8)
        }
        // Old layout: action sits on the path row, path yields width to the button.
        pathField.snp.makeConstraints { make in
            make.leading.equalTo(titleField)
            make.top.equalTo(uuidField.snp.bottom).offset(2)
            make.bottom.equalToSuperview().offset(-6)
        }
        actionButton.snp.makeConstraints { make in
            make.leading.equalTo(pathField.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-8)
            make.firstBaseline.equalTo(pathField.snp.firstBaseline)
            make.width.greaterThanOrEqualTo(40)
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
        actionButton.isHidden = false
        actionButton.sizeToFit()
        needsLayout = true
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
    private let doneButton = NSButton(title: NSLocalizedString("Done", comment: ""), target: nil, action: nil)
    private let progressBar = NSProgressIndicator()
    private let mainColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))

    private var binaries: [BinaryImage] = []
    private var dsymFiles: [String: DsymFile] = [:]
    private var dsymStorage = Set<AnyCancellable>()
    private var taskCancellable: AnyCancellable?
    private var reloadScheduled = false

    var dsymManager: DsymManager? {
        didSet {
            dsymStorage.forEach { $0.cancel() }
            dsymStorage.removeAll()
            guard let dsymManager else {
                binaries = []
                dsymFiles = [:]
                scheduleReload()
                return
            }

            // Single pipeline so binaries + dSYM maps don't each trigger a full reload.
            Publishers.CombineLatest(dsymManager.$binaries, dsymManager.$dsymFiles)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] binaries, dsymFiles in
                    guard let self else { return }
                    self.binaries = binaries
                    self.dsymFiles = dsymFiles
                    self.scheduleReload()
                }
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

        mainColumn.title = "Binary Images"
        mainColumn.minWidth = 200
        mainColumn.width = 520
        mainColumn.resizingMask = [.autoresizingMask, .userResizingMask]
        tableView.addTableColumn(mainColumn)
        tableView.headerView = nil
        tableView.rowHeight = 66
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAutomaticRowHeights = false
        tableView.selectionHighlightStyle = .none
        tableView.allowsEmptySelection = true
        tableView.backgroundColor = .clear
        tableView.autoresizingMask = [.width, .height]

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        progressBar.isIndeterminate = true
        progressBar.isHidden = true

        downloadButton.target = self
        downloadButton.action = #selector(didClickDownloadButton(_:))
        downloadButton.setContentHuggingPriority(.required, for: .horizontal)

        doneButton.target = self
        doneButton.action = #selector(didClickDoneButton(_:))
        doneButton.keyEquivalent = "\r"
        doneButton.setContentHuggingPriority(.required, for: .horizontal)

        view.addSubview(scrollView)
        view.addSubview(downloadButton)
        view.addSubview(doneButton)
        view.addSubview(progressBar)

        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(downloadButton.snp.top).offset(-12)
        }
        downloadButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        doneButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(downloadButton)
        }
        progressBar.snp.makeConstraints { make in
            make.leading.equalTo(downloadButton.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(doneButton.snp.leading).offset(-12)
            make.centerY.equalTo(downloadButton)
            make.width.equalTo(200)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        downloadButton.isEnabled = dsymManager?.crash != nil
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        tableView.sizeLastColumnToFit()
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

    private func scheduleReload() {
        guard isViewLoaded, !reloadScheduled else { return }
        reloadScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.reloadScheduled = false
            self.tableView.sizeLastColumnToFit()
            self.tableView.reloadData()
        }
    }

    private func dsymFile(forBinary binary: BinaryImage) -> DsymFile? {
        guard let uuid = binary.uuid else { return nil }
        return dsymFiles[uuid] ?? dsymManager?.dsymFile(withUuid: uuid)
    }

    @objc private func didClickDownloadButton(_: NSButton) {
        if let crashInfo = dsymManager?.crash {
            DsymDownloader.shared.download(crashInfo: crashInfo, fileURL: nil)
        }
    }

    @objc private func didClickDoneButton(_: NSButton) {
        dismiss(nil)
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
            downloadButton.isEnabled = true
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
        let identifier = NSUserInterfaceItemIdentifier("DsymRow")
        let cell: DsymTableRowView
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? DsymTableRowView {
            cell = existing
        } else {
            cell = DsymTableRowView()
            cell.identifier = identifier
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
