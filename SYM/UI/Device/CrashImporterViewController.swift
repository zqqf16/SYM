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

extension MDDeviceFile {
    var isCrash: Bool {
        return !isDirectory && (name.contains(".ips") || name.contains(".crash"))
    }

    var localCrashFileName: String {
        let name = self.name.components(separatedBy: ".ips")[0]
        return "\(name).crash"
    }

    var crashFileDisplayName: String {
        var components = name.components(separatedBy: ".")
        if components.last == "synced" {
            components.removeLast()
            return components.joined(separator: ".")
        }
        return name
    }
}

extension MDAfcClient {
    func copyCrashFile(_ file: MDDeviceFile, to url: URL) -> String? {
        guard let content = read(file.path) else { return nil }
        do {
            try content.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return url.path
    }
}

class DeviceFileProvider: NSFilePromiseProvider {
    var file: MDDeviceFile?
    var deviceID: String?
}

class CrashImporterViewController: NSViewController, LoadingAble {
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")

    private var fileList: [MDDeviceFile] = []
    private var filteredList: [MDDeviceFile] = []
    private var deviceID: String?
    private var errorMessage: String?

    var loadingIndicator: NSProgressIndicator!

    /// All AFC traffic goes through one queue (mirrors FileBrowserViewController;
    /// afc clients are not safe to use concurrently).
    private let afcQueue = DispatchQueue(label: "im.zorro.SYM.crashImporter.afc")

    private var afcClient: MDAfcClient? {
        guard let deviceID = deviceID else { return nil }
        let lockdown = MDLockdown(udid: deviceID)
        return MDAfcClient.crash(with: lockdown)
    }

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
        tableView.registerForDraggedTypes([.backwardsCompatibleFileURL])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }

    private func setupUI() {
        searchField.placeholderString = NSLocalizedString("Search crashes", comment: "")
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Process"))
        nameColumn.title = NSLocalizedString("Name", comment: "")
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(keyPath: \MDDeviceFile.lowercaseName, ascending: true)
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Date"))
        dateColumn.title = NSLocalizedString("Date", comment: "")
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(keyPath: \MDDeviceFile.date, ascending: false)
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(dateColumn)
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        emptyLabel.stringValue = NSLocalizedString("No crash logs found", comment: "")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.isHidden = true

        view.addSubview(searchField)
        view.addSubview(scrollView)
        view.addSubview(emptyLabel)
        view.addSubview(errorLabel)

        searchField.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(searchField.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(scrollView)
        }
        errorLabel.snp.makeConstraints { make in
            make.centerX.equalTo(scrollView)
            make.bottom.equalTo(emptyLabel.snp.top).offset(-8)
        }
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        applyFilter(query: sender.stringValue)
    }

    private func applyFilter(query: String) {
        if query.isEmpty {
            filteredList = fileList
        } else {
            let q = query.lowercased()
            filteredList = fileList.filter { $0.lowercaseName.contains(q) }
        }
        updateEmptyState()
        tableView.reloadData()
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !filteredList.isEmpty || errorMessage != nil
        errorLabel.isHidden = errorMessage == nil
        errorLabel.stringValue = errorMessage ?? ""
    }

    func reloadData(withDeviceID deviceID: String?) {
        if self.deviceID == deviceID { return }
        self.deviceID = deviceID
        errorMessage = nil

        if deviceID == nil {
            fileList = []
            filteredList = []
            tableView.reloadData()
            updateEmptyState()
            return
        }
        guard let deviceID else { return }

        showLoading()
        afcQueue.async { [weak self] in
            let lockdown = MDLockdown(udid: deviceID)
            if let moveService = lockdown.startService(withIdentifier: "com.apple.crashreportmover") {
                moveService.ping()
            }
            let client: MDAfcClient? = MDAfcClient.crash(with: lockdown)
            let crashList = client?.crashFiles() ?? []
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.fileList = crashList.filter { $0.isCrash }.sorted { $0.date > $1.date }
                self.applyFilter(query: self.searchField.stringValue)
                self.hideLoading()
            }
        }
    }

    func openCrash(atIndex index: Int) {
        guard index >= 0, index < filteredList.count else { return }
        guard let udid = deviceID else { return }
        showLoading()
        let file = filteredList[index]
        afcQueue.async { [weak self] in
            let path = FileManager.default.localCrashDirectory(udid) + "/\(file.localCrashFileName)"
            let url = URL(fileURLWithPath: path)
            if self?.afcClient?.copyCrashFile(file, to: url) != nil {
                DispatchQueue.main.async { [weak self] in
                    DocumentController.shared.openDocument(withContentsOf: url, display: true) { [weak self] _, _, _ in
                        self?.hideLoading()
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = NSLocalizedString("Failed to copy crash log", comment: "")
                    self?.updateEmptyState()
                    self?.hideLoading()
                }
            }
        }
    }

    @objc func didDoubleClickCell(_: AnyObject?) {
        openCrash(atIndex: tableView.clickedRow)
    }

    @objc func reloadFiles(_: AnyObject?) {
        let deviceID = self.deviceID
        self.deviceID = nil
        reloadData(withDeviceID: deviceID)
    }

    @objc func removeFile(_: AnyObject?) {
        let selectedIndexes = tableView.selectedRowIndexes
        guard !selectedIndexes.isEmpty else { return }

        // Files are deleted from the device immediately — confirm first.
        confirmDeletion(count: selectedIndexes.count) { [weak self] in
            guard let self else { return }
            let files = selectedIndexes.map { self.filteredList[$0] }
            guard let afcClient = self.afcClient else { return }
            self.showLoading()
            self.afcQueue.async {
                files.forEach { afcClient.remove($0.path) }
                DispatchQueue.main.async { [weak self] in
                    self?.reloadFiles(nil)
                    self?.hideLoading()
                }
            }
        }
    }
}

extension CrashImporterViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        filteredList.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let file = filteredList[row]
        let identifier = tableColumn.identifier
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeTextCell(identifier: identifier)
        }
        if identifier.rawValue == "Process" {
            cell.textField?.stringValue = file.crashFileDisplayName
        } else {
            cell.textField?.stringValue = file.date.formattedString
        }
        return cell
    }

    private func makeTextCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.lineBreakMode = .byTruncatingTail
        textField.drawsBackground = false
        textField.isEditable = false
        textField.isBordered = false
        cell.addSubview(textField)
        cell.textField = textField
        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        filteredList = (filteredList as NSArray).sortedArray(using: tableView.sortDescriptors) as? [MDDeviceFile] ?? filteredList
        tableView.reloadData()
    }

    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let deviceID else { return nil }
        let provider = DeviceFileProvider(fileType: "public.plain-text", delegate: self)
        provider.file = filteredList[row]
        provider.deviceID = deviceID
        return provider
    }
}

extension CrashImporterViewController: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType _: String) -> String {
        guard let provider = filePromiseProvider as? DeviceFileProvider else { return "" }
        return provider.file?.localCrashFileName ?? ""
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let provider = filePromiseProvider as? DeviceFileProvider,
              let file = provider.file,
              let deviceID = provider.deviceID
        else {
            completionHandler(FileError.createFailed)
            return
        }
        // Runs on the provider's own operation queue (background). The importer's
        // AFC client is confined to its queue, so open a dedicated connection and
        // report failures instead of silently promising an empty file.
        let client: MDAfcClient? = MDAfcClient.crash(with: MDLockdown(udid: deviceID))
        guard let client, client.copyCrashFile(file, to: url) != nil else {
            completionHandler(FileError.createFailed)
            return
        }
        completionHandler(nil)
    }

    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        OperationQueue()
    }
}
