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

        showLoading()
        DispatchQueue.global().async {
            let lockdown = MDLockdown(udid: deviceID!)
            if let moveService = lockdown.startService(withIdentifier: "com.apple.crashreportmover") {
                moveService.ping()
            }
            let crashList = self.afcClient?.crashFiles() ?? []
            DispatchQueue.main.async {
                self.fileList = crashList.filter { $0.isCrash }.sorted { $0.date > $1.date }
                self.applyFilter(query: self.searchField.stringValue)
                self.hideLoading()
            }
        }
    }

    func openCrash(atIndex index: Int) {
        guard index >= 0, index < filteredList.count else { return }
        showLoading()
        let file = filteredList[index]
        DispatchQueue.global().async {
            guard let udid = self.deviceID else {
                DispatchQueue.main.async { self.hideLoading() }
                return
            }
            let path = FileManager.default.localCrashDirectory(udid) + "/\(file.localCrashFileName)"
            let url = URL(fileURLWithPath: path)
            if self.afcClient?.copyCrashFile(file, to: url) != nil {
                DispatchQueue.main.async {
                    DocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in
                        self.hideLoading()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = NSLocalizedString("Failed to copy crash log", comment: "")
                    self.updateEmptyState()
                    self.hideLoading()
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
        guard let afcClient = afcClient else { return }
        let selectedIndexes = tableView.selectedRowIndexes
        if selectedIndexes.isEmpty { return }

        let files = selectedIndexes.map { filteredList[$0] }
        showLoading()
        DispatchQueue.global().async {
            files.forEach { afcClient.remove($0.path) }
            DispatchQueue.main.async {
                self.reloadFiles(nil)
                self.hideLoading()
            }
        }
    }
}

extension CrashImporterViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        filteredList.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = filteredList[row]
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: nil) as? NSTableCellView ?? NSTableCellView()
        if cell.textField == nil {
            cell.addSubview(NSTextField(labelWithString: ""))
            cell.textField = cell.subviews.first as? NSTextField
        }
        if tableColumn?.identifier.rawValue == "Process" {
            cell.textField?.stringValue = file.crashFileDisplayName
        } else {
            cell.textField?.stringValue = file.date.formattedString
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        filteredList = (filteredList as NSArray).sortedArray(using: tableView.sortDescriptors) as! [MDDeviceFile]
        tableView.reloadData()
    }

    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let provider = DeviceFileProvider(fileType: "public.plain-text", delegate: self)
        provider.file = filteredList[row]
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
              let afcClient = afcClient
        else {
            completionHandler(FileError.createFailed)
            return
        }
        _ = afcClient.copyCrashFile(file, to: url)
        completionHandler(nil)
    }

    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        OperationQueue()
    }
}
