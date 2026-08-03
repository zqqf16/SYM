// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Cocoa
import SnapKit

private let previewSizeLimit = 512 * 1024

protocol FileBrowserNavigationDelegate: AnyObject {
    func fileBrowserNavigationDidChange(_ browser: FileBrowserViewController)
}

class FileBrowserViewController: NSViewController, LoadingAble {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let previewScrollView = NSScrollView()
    private let previewTextView = NSTextView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    private let splitView = NSSplitView()
    private let pathBar = FilePathBarView()

    var loadingIndicator: NSProgressIndicator!
    weak var navigationDelegate: FileBrowserNavigationDelegate?

    private var deviceID: String?
    private var appID: String?
    private var rootDir: MDDeviceFile?
    private var currentDir: MDDeviceFile?
    private var afcClient: MDAfcClient?
    private var displayedFiles: [MDDeviceFile] = []
    private var errorMessage: String?

    private var history: [MDDeviceFile] = []
    private var historyIndex: Int = -1
    /// All AFC traffic for this browser goes through one queue (afc_client is not thread-safe).
    private let afcQueue = DispatchQueue(label: "im.zorro.SYM.fileBrowser.afc")

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex >= 0 && historyIndex < history.count - 1 }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        tableView.doubleAction = #selector(didDoubleClickCell(_:))
        tableView.target = self
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = false
        tableView.menu = buildContextMenu()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        navigationDelegate?.fileBrowserNavigationDidChange(self)
    }

    private func setupUI() {
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Name"))
        nameColumn.title = NSLocalizedString("Name", comment: "")
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(
            key: "name",
            ascending: true,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Date"))
        dateColumn.title = NSLocalizedString("Date", comment: "")
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(keyPath: \MDDeviceFile.date, ascending: false)
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Size"))
        sizeColumn.title = NSLocalizedString("Size", comment: "")
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(keyPath: \MDDeviceFile.size, ascending: false)
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(dateColumn)
        tableView.addTableColumn(sizeColumn)
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.style = .inset
        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        previewTextView.drawsBackground = false
        previewScrollView.documentView = previewTextView
        previewScrollView.hasVerticalScroller = true
        previewScrollView.borderType = .noBorder
        previewScrollView.backgroundColor = .textBackgroundColor

        emptyLabel.stringValue = NSLocalizedString("No files", comment: "")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.isHidden = true

        let listContainer = NSView()
        listContainer.addSubview(scrollView)
        listContainer.addSubview(emptyLabel)
        listContainer.addSubview(errorLabel)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(scrollView)
        }
        errorLabel.snp.makeConstraints { make in
            make.centerX.equalTo(scrollView)
            make.bottom.equalTo(emptyLabel.snp.top).offset(-8)
        }

        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.addSubview(listContainer)
        splitView.addSubview(previewScrollView)

        pathBar.onSelectComponent = { [weak self] file in
            guard let self, let file else { return }
            self.navigate(to: file, recordHistory: true)
        }

        view.addSubview(splitView)
        view.addSubview(pathBar)
        pathBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(28)
        }
        splitView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(pathBar.snp.top)
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Open", comment: ""), action: #selector(openFile(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Export", comment: ""), action: #selector(didClickExportButton(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Delete", comment: ""), action: #selector(removeFile(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("Copy Path", comment: ""), action: #selector(copyPath(_:)), keyEquivalent: "")
        return menu
    }

    func reloadData(withDeviceID deviceID: String?, appID: String?) {
        if deviceID == self.deviceID && appID == self.appID { return }
        self.deviceID = deviceID
        self.appID = appID
        errorMessage = nil
        rootDir = nil
        currentDir = nil
        history = []
        historyIndex = -1
        displayedFiles = []
        tableView.reloadData()
        updateEmptyState()
        updatePathBar()
        previewTextView.string = ""
        navigationDelegate?.fileBrowserNavigationDidChange(self)

        guard deviceID != nil, appID != nil else { return }

        showLoading()
        let deviceID = deviceID!
        let appID = appID!
        afcQueue.async {
            let lockdown = MDLockdown(udid: deviceID)
            let houseArrest = MDHouseArrest(lockdown: lockdown, appID: appID)
            let afcClient = MDAfcClient.fileClient(with: houseArrest)
            let rootDir = MDDeviceFile(afcClient: afcClient)
            rootDir.path = "."
            rootDir.isDirectory = true
            _ = rootDir.children

            DispatchQueue.main.async {
                self.afcClient = afcClient
                self.rootDir = rootDir
                self.navigate(to: rootDir, recordHistory: true)
                self.hideLoading()
            }
        }
    }

    @objc func goBack(_: Any?) {
        guard canGoBack else { return }
        historyIndex -= 1
        navigate(to: history[historyIndex], recordHistory: false)
    }

    @objc func goForward(_: Any?) {
        guard canGoForward else { return }
        historyIndex += 1
        navigate(to: history[historyIndex], recordHistory: false)
    }

    private func navigate(to dir: MDDeviceFile, recordHistory: Bool) {
        if recordHistory {
            if historyIndex >= 0, historyIndex < history.count - 1 {
                history = Array(history[0 ... historyIndex])
            }
            if history.last !== dir {
                history.append(dir)
            }
            historyIndex = history.count - 1
        }
        currentDir = dir
        reloadDirectoryListing()
        previewTextView.string = ""
        navigationDelegate?.fileBrowserNavigationDidChange(self)
    }

    private func reloadDirectoryListing() {
        guard let dir = currentDir else {
            displayedFiles = []
            applySortAndReload()
            updatePathBar()
            return
        }

        showLoading()
        afcQueue.async {
            let children = dir.reloadChildren() ?? dir.children ?? []
            DispatchQueue.main.async {
                self.displayedFiles = children
                self.applySortAndReload()
                self.updatePathBar()
                self.hideLoading()
            }
        }
    }

    private func applySortAndReload() {
        if !tableView.sortDescriptors.isEmpty {
            displayedFiles = (displayedFiles as NSArray).sortedArray(using: tableView.sortDescriptors) as! [MDDeviceFile]
        }
        updateEmptyState()
        tableView.reloadData()
    }

    private func updateEmptyState() {
        emptyLabel.stringValue = NSLocalizedString("No files", comment: "")
        emptyLabel.isHidden = !displayedFiles.isEmpty || errorMessage != nil
        errorLabel.isHidden = errorMessage == nil
        errorLabel.stringValue = errorMessage ?? ""
    }

    private func updatePathBar() {
        pathBar.setComponents(pathComponents(to: currentDir))
    }

    private func displayPath(for file: MDDeviceFile) -> String {
        var path = file.path
        if path == "." {
            return "/"
        }
        if path.hasPrefix("./") {
            path = String(path.dropFirst(1))
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        return path
    }

    private func pathComponents(to dir: MDDeviceFile?) -> [(title: String, file: MDDeviceFile?)] {
        guard let root = rootDir else {
            return [(title: "/", file: nil)]
        }
        guard let dir, dir !== root else {
            return [(title: "/", file: root)]
        }

        let display = displayPath(for: dir)
        let parts = display.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        var components: [(title: String, file: MDDeviceFile?)] = [(title: "/", file: root)]
        for (index, part) in parts.enumerated() {
            let isLast = index == parts.count - 1
            components.append((title: part, file: isLast ? dir : nil))
        }
        return components
    }

    @objc func didClickExportButton(_: Any?) {
        exportSelectedFiles()
    }

    @objc func didDoubleClickCell(_: AnyObject?) {
        openFile(atIndex: tableView.clickedRow)
    }

    @objc func reloadFiles(_: AnyObject?) {
        let deviceID = self.deviceID
        let appID = self.appID
        self.deviceID = nil
        self.appID = nil
        reloadData(withDeviceID: deviceID, appID: appID)
    }

    @objc func openFile(_: AnyObject?) {
        openFile(atIndex: tableView.selectedRow)
    }

    @objc func removeFile(_: AnyObject?) {
        let indexes = tableView.selectedRowIndexes
        guard !indexes.isEmpty else { return }
        showLoading()
        let files = indexes.map { displayedFiles[$0] }
        afcQueue.async {
            var removed = false
            for file in files {
                if file.remove() {
                    removed = true
                }
            }
            DispatchQueue.main.async {
                if removed {
                    self.reloadDirectoryListing()
                } else {
                    self.hideLoading()
                }
            }
        }
    }

    @objc func copyPath(_: AnyObject?) {
        let row = tableView.selectedRow
        guard row >= 0, row < displayedFiles.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayedFiles[row].path, forType: .string)
    }

    private func exportSelectedFiles() {
        let indexes = tableView.selectedRowIndexes
        guard !indexes.isEmpty else { return }
        if indexes.count == 1 {
            exportFile(atIndex: indexes.first!)
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("Export", comment: "")
        panel.message = NSLocalizedString("Choose export folder", comment: "")
        panel.beginSheetModal(for: view.window!) { [weak panel] result in
            guard result == .OK, let url = panel?.url else { return }
            let files = indexes.map { self.displayedFiles[$0] }
            self.exportFiles(files, toDirectory: url)
        }
    }

    private func exportFile(atIndex index: Int) {
        guard index >= 0, index < displayedFiles.count else { return }
        let file = displayedFiles[index]
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = file.name
        savePanel.beginSheetModal(for: view.window!) { [weak savePanel] result in
            guard result == .OK, let url = savePanel?.url else { return }
            var name = savePanel?.nameFieldStringValue ?? file.name
            if name.isEmpty { name = file.name }
            let dest = URL(fileURLWithPath: name, relativeTo: url)
            self.exportFile(file, toURL: dest)
        }
    }

    private func exportFiles(_ files: [MDDeviceFile], toDirectory directory: URL) {
        showLoading()
        afcQueue.async {
            files.forEach { file in
                let dest = directory.appendingPathComponent(file.name)
                file.copy(dest.path)
            }
            DispatchQueue.main.async { self.hideLoading() }
        }
    }

    private func exportFile(_ file: MDDeviceFile, toURL url: URL) {
        showLoading()
        afcQueue.async {
            file.copy(url.path)
            DispatchQueue.main.async { self.hideLoading() }
        }
    }

    private func openFile(atIndex index: Int) {
        guard index >= 0, index < displayedFiles.count else { return }
        let file = displayedFiles[index]
        if file.isDirectory {
            navigate(to: file, recordHistory: true)
            return
        }
        showLoading()
        let deviceID = self.deviceID
        afcQueue.async {
            guard let udid = deviceID else {
                DispatchQueue.main.async { self.hideLoading() }
                return
            }
            let path = FileManager.default.localCrashDirectory(udid) + "/\(file.name)"
            let url = URL(fileURLWithPath: path)
            file.copy(url.path)
            DispatchQueue.main.async {
                self.hideLoading()
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func loadPreview(for file: MDDeviceFile) {
        guard !file.isDirectory, file.size < previewSizeLimit else {
            previewTextView.string = file.isDirectory
                ? NSLocalizedString("Select a file to preview", comment: "")
                : NSLocalizedString("File too large to preview", comment: "")
            return
        }
        afcQueue.async {
            let text: String
            if let data = file.read(), let content = String(data: data, encoding: .utf8) {
                text = content
            } else {
                text = NSLocalizedString("Unable to preview file", comment: "")
            }
            DispatchQueue.main.async {
                self.previewTextView.string = text
            }
        }
    }
}

// MARK: - Table

extension FileBrowserViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        displayedFiles.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let file = displayedFiles[row]
        let identifier = tableColumn.identifier
        let isNameColumn = identifier.rawValue == "Name"
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeFileCell(identifier: identifier, showsIcon: isNameColumn)
        }

        switch identifier.rawValue {
        case "Name":
            cell.textField?.stringValue = file.name
            cell.toolTip = displayPath(for: file)
            cell.imageView?.image = file.isDirectory
                ? NSImage(named: NSImage.folderName)
                : NSWorkspace.shared.icon(forFileType: file.extension)
            cell.imageView?.isHidden = false
        case "Date":
            cell.textField?.stringValue = file.date.formattedString
            cell.toolTip = nil
            cell.imageView?.isHidden = true
        case "Size":
            cell.textField?.stringValue = file.isDirectory ? "—" : "\(file.size.readableSize)"
            cell.toolTip = nil
            cell.imageView?.isHidden = true
        default:
            break
        }
        return cell
    }

    private func makeFileCell(identifier: NSUserInterfaceItemIdentifier, showsIcon: Bool) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail
        textField.drawsBackground = false
        textField.isEditable = false
        textField.isBordered = false
        cell.addSubview(textField)
        cell.textField = textField

        if showsIcon {
            let imageView = NSImageView()
            cell.addSubview(imageView)
            cell.imageView = imageView
            imageView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(2)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(16)
            }
            textField.snp.makeConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(4)
                make.trailing.equalToSuperview().offset(-4)
                make.centerY.equalToSuperview()
            }
        } else {
            textField.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(4)
                make.trailing.equalToSuperview().offset(-4)
                make.centerY.equalToSuperview()
            }
        }
        return cell
    }

    func tableViewSelectionDidChange(_: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < displayedFiles.count else { return }
        loadPreview(for: displayedFiles[row])
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        applySortAndReload()
    }
}

extension FileBrowserViewController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .deviceFileBack:
            return canGoBack
        case .deviceFileForward:
            return canGoForward
        default:
            return true
        }
    }
}

// MARK: - Path bar

private final class FilePathBarView: NSView {
    var onSelectComponent: ((MDDeviceFile?) -> Void)?

    private let stack = NSStackView()
    private let folderIcon = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        let topLine = NSBox()
        topLine.boxType = .separator
        addSubview(topLine)
        topLine.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }

        folderIcon.image = NSImage.sfSymbol("folder", accessibilityDescription: nil)
        folderIcon.contentTintColor = .secondaryLabelColor
        folderIcon.imageScaling = .scaleProportionallyDown

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2

        addSubview(folderIcon)
        addSubview(stack)
        folderIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
        stack.snp.makeConstraints { make in
            make.leading.equalTo(folderIcon.snp.trailing).offset(6)
            make.trailing.lessThanOrEqualToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    func setComponents(_ components: [(title: String, file: MDDeviceFile?)]) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (index, component) in components.enumerated() {
            if index > 0 {
                let chevron = NSImageView()
                chevron.image = NSImage.sfSymbol("chevron.forward", accessibilityDescription: nil)
                chevron.contentTintColor = .tertiaryLabelColor
                chevron.imageScaling = .scaleProportionallyDown
                chevron.translatesAutoresizingMaskIntoConstraints = false
                chevron.widthAnchor.constraint(equalToConstant: 10).isActive = true
                chevron.heightAnchor.constraint(equalToConstant: 10).isActive = true
                stack.addArrangedSubview(chevron)
            }

            let button = NSButton(title: component.title, target: self, action: #selector(pathClicked(_:)))
            button.bezelStyle = .recessed
            button.isBordered = false
            button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            button.contentTintColor = index == components.count - 1 ? .labelColor : .secondaryLabelColor
            button.refusesFirstResponder = true
            button.isEnabled = component.file != nil
            button.cell?.representedObject = component.file
            stack.addArrangedSubview(button)
        }
    }

    @objc private func pathClicked(_ sender: NSButton) {
        onSelectComponent?(sender.cell?.representedObject as? MDDeviceFile)
    }
}
