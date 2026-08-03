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

class FileBrowserViewController: NSViewController, LoadingAble {
    private let searchField = NSSearchField()
    private let breadcrumbControl = NSSegmentedControl()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let previewScrollView = NSScrollView()
    private let previewTextView = NSTextView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    private let splitView = NSSplitView()

    var loadingIndicator: NSProgressIndicator!

    private var deviceID: String?
    private var appID: String?
    private var rootDir: MDDeviceFile?
    private var currentDir: MDDeviceFile?
    private var afcClient: MDAfcClient?
    private var displayedFiles: [MDDeviceFile] = []
    private var errorMessage: String?

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

    private func setupUI() {
        searchField.placeholderString = NSLocalizedString("Search files", comment: "")
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))

        breadcrumbControl.segmentCount = 1
        breadcrumbControl.setLabel("/", forSegment: 0)
        breadcrumbControl.target = self
        breadcrumbControl.action = #selector(breadcrumbClicked(_:))

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Name"))
        nameColumn.title = NSLocalizedString("Name", comment: "")
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
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
        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        previewScrollView.documentView = previewTextView
        previewScrollView.hasVerticalScroller = true
        previewScrollView.borderType = .bezelBorder

        emptyLabel.stringValue = NSLocalizedString("No files", comment: "")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.isHidden = true

        let listContainer = NSView()
        listContainer.addSubview(searchField)
        listContainer.addSubview(breadcrumbControl)
        listContainer.addSubview(scrollView)
        listContainer.addSubview(emptyLabel)
        listContainer.addSubview(errorLabel)

        searchField.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(8)
        }
        breadcrumbControl.snp.makeConstraints { make in
            make.top.equalTo(searchField.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(8)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(breadcrumbControl.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview().inset(8)
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
        view.addSubview(splitView)

        splitView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        splitView.setPosition(view.bounds.height * 0.65, ofDividerAt: 0)
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
        displayedFiles = []
        updateBreadcrumb()
        tableView.reloadData()
        updateEmptyState()
        previewTextView.string = ""

        guard deviceID != nil, appID != nil else { return }

        showLoading()
        DispatchQueue.global().async {
            let lockdown = MDLockdown(udid: deviceID!)
            let houseArrest = MDHouseArrest(lockdown: lockdown, appID: appID!)
            let afcClient = MDAfcClient.fileClient(with: houseArrest)
            let rootDir = MDDeviceFile(afcClient: afcClient)
            rootDir.path = "."
            rootDir.isDirectory = true
            _ = rootDir.children

            DispatchQueue.main.async {
                self.afcClient = afcClient
                self.rootDir = rootDir
                self.navigate(to: rootDir)
                self.hideLoading()
            }
        }
    }

    private func navigate(to dir: MDDeviceFile) {
        currentDir = dir
        refreshFileList()
        updateBreadcrumb()
        previewTextView.string = ""
    }

    private func refreshFileList() {
        guard let children = currentDir?.children else {
            displayedFiles = []
            tableView.reloadData()
            updateEmptyState()
            return
        }
        applyFilter(query: searchField.stringValue, from: children)
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        refreshFileList()
    }

    private func applyFilter(query: String, from files: [MDDeviceFile]? = nil) {
        let source = files ?? currentDir?.children ?? []
        if query.isEmpty {
            displayedFiles = source
        } else {
            let q = query.lowercased()
            displayedFiles = source.filter { $0.lowercaseName.contains(q) }
        }
        if !tableView.sortDescriptors.isEmpty {
            displayedFiles = (displayedFiles as NSArray).sortedArray(using: tableView.sortDescriptors) as! [MDDeviceFile]
        }
        updateEmptyState()
        tableView.reloadData()
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !displayedFiles.isEmpty || errorMessage != nil
        errorLabel.isHidden = errorMessage == nil
        errorLabel.stringValue = errorMessage ?? ""
    }

    private func updateBreadcrumb() {
        breadcrumbControl.segmentCount = 0
        var pathComponents: [(String, MDDeviceFile?)] = [("/", rootDir)]
        if let current = currentDir, let root = rootDir, current !== root {
            var stack: [MDDeviceFile] = []
            var node: MDDeviceFile? = current
            while let n = node, n !== root {
                stack.insert(n, at: 0)
                node = parent(of: n)
            }
            for item in stack {
                pathComponents.append((item.name, item))
            }
        }
        breadcrumbControl.segmentCount = pathComponents.count
        for (index, component) in pathComponents.enumerated() {
            breadcrumbControl.setLabel(component.0, forSegment: index)
            breadcrumbControl.setTag(index, forSegment: index)
        }
    }

    private func parent(of file: MDDeviceFile) -> MDDeviceFile? {
        guard let root = rootDir else { return nil }
        return findParent(of: file, in: root)
    }

    private func findParent(of target: MDDeviceFile, in node: MDDeviceFile) -> MDDeviceFile? {
        guard let children = node.children else { return nil }
        for child in children {
            if child === target { return node }
            if child.isDirectory, let found = findParent(of: target, in: child) {
                return found
            }
        }
        return nil
    }

    @objc private func breadcrumbClicked(_ sender: NSSegmentedControl) {
        let index = sender.selectedSegment
        guard index >= 0 else { return }
        if index == 0, let root = rootDir {
            navigate(to: root)
            return
        }
        guard let root = rootDir else { return }
        var stack: [MDDeviceFile] = []
        var node: MDDeviceFile? = currentDir
        while let n = node, n !== root {
            stack.insert(n, at: 0)
            node = parent(of: n)
        }
        if index - 1 < stack.count {
            navigate(to: stack[index - 1])
        }
    }

    @objc func didClickExportButton(_: NSButton) {
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
        let row = tableView.selectedRow
        openFile(atIndex: row)
    }

    @objc func removeFile(_: AnyObject?) {
        let indexes = tableView.selectedRowIndexes
        guard !indexes.isEmpty, let currentDir = currentDir else { return }
        showLoading()
        let files = indexes.map { displayedFiles[$0] }
        DispatchQueue.global().async {
            var removed = false
            files.forEach { file in
                if currentDir.removeChild(file) {
                    removed = true
                }
            }
            DispatchQueue.main.async {
                if removed {
                    self.refreshFileList()
                }
                self.hideLoading()
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
        DispatchQueue.global().async {
            files.forEach { file in
                let dest = directory.appendingPathComponent(file.name)
                file.copy(dest.path)
            }
            DispatchQueue.main.async { self.hideLoading() }
        }
    }

    private func exportFile(_ file: MDDeviceFile, toURL url: URL) {
        showLoading()
        DispatchQueue.global().async {
            file.copy(url.path)
            DispatchQueue.main.async { self.hideLoading() }
        }
    }

    private func openFile(atIndex index: Int) {
        guard index >= 0, index < displayedFiles.count else { return }
        let file = displayedFiles[index]
        if file.isDirectory {
            navigate(to: file)
            return
        }
        showLoading()
        DispatchQueue.global().async {
            guard let udid = self.deviceID else {
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
        DispatchQueue.global().async {
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

extension FileBrowserViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        displayedFiles.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = displayedFiles[row]
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: nil) as? NSTableCellView ?? NSTableCellView()
        if cell.textField == nil {
            let textField = NSTextField(labelWithString: "")
            let imageView = NSImageView()
            cell.addSubview(imageView)
            cell.addSubview(textField)
            cell.imageView = imageView
            cell.textField = textField
            imageView.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
                make.width.height.equalTo(16)
            }
            textField.snp.makeConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(4)
                make.trailing.centerY.equalToSuperview()
            }
        }
        switch tableColumn?.identifier.rawValue {
        case "Name":
            cell.textField?.stringValue = file.name
            cell.imageView?.image = file.isDirectory
                ? NSImage(named: NSImage.folderName)
                : NSWorkspace.shared.icon(forFileType: file.extension)
        case "Date":
            cell.textField?.stringValue = file.date.formattedString
            cell.imageView?.image = nil
        case "Size":
            cell.textField?.stringValue = file.isDirectory ? "—" : "\(file.size.readableSize)"
            cell.imageView?.image = nil
        default:
            break
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < displayedFiles.count else { return }
        loadPreview(for: displayedFiles[row])
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        displayedFiles = (displayedFiles as NSArray).sortedArray(using: tableView.sortDescriptors) as! [MDDeviceFile]
        tableView.reloadData()
    }
}
