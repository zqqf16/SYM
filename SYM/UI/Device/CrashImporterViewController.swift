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
        guard let content = read(file.path) else {
            return nil
        }

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
    private var fileList: [MDDeviceFile] = []
    private var afcClient: MDAfcClient? {
        // Always create a new one
        let lockdown = MDLockdown(udid: deviceID)
        return MDAfcClient.crash(with: lockdown)
    }

    private var deviceID: String?

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var openButton: NSButton!
    var loadingIndicator: NSProgressIndicator!

    override func viewDidLoad() {
        super.viewDidLoad()

        let descriptorProcess = NSSortDescriptor(keyPath: \MDDeviceFile.lowercaseName, ascending: true)
        let descriptorDate = NSSortDescriptor(keyPath: \MDDeviceFile.date, ascending: true)
        tableView.tableColumns[0].sortDescriptorPrototype = descriptorProcess
        tableView.tableColumns[1].sortDescriptorPrototype = descriptorDate

        tableView.registerForDraggedTypes([.backwardsCompatibleFileURL])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }

    func reloadData(withDeviceID deviceID: String?) {
        if self.deviceID == deviceID {
            return
        }
        self.deviceID = deviceID

        if self.deviceID == nil {
            DispatchQueue.main.async {
                self.fileList = []
                self.tableView.reloadData()
            }
            return
        }

        showLoading()
        DispatchQueue.global().async {
            let lockdown = MDLockdown(udid: self.deviceID)
            if let moveService = lockdown.startService(withIdentifier: "com.apple.crashreportmover") {
                // trigger moving
                moveService.ping()
            }
            let crashList = self.afcClient?.crashFiles() ?? []
            DispatchQueue.main.async {
                self.fileList = crashList.filter { $0.isCrash }.sorted(by: { file1, file2 -> Bool in
                    file1.date > file2.date
                })
                self.tableView.reloadData()
                self.hideLoading()
            }
        }
    }

    func openCrash(atIndex index: Int) {
        if index < 0 || index > fileList.count - 1 {
            return
        }

        showLoading()

        let file = fileList[index]
        DispatchQueue.global().async {
            guard let udid = self.deviceID else {
                self.hideLoading()
                return
            }

            let path = FileManager.default.localCrashDirectory(udid) + "/\(file.localCrashFileName)"
            let url = URL(fileURLWithPath: path)
            if let _ = self.afcClient?.copyCrashFile(file, to: url) {
                DispatchQueue.main.async {
                    DocumentController.shared.openDocument(withContentsOf: url, display: true, completionHandler: { _, _, _ in
                        self.hideLoading()
                    })
                }
            }
        }
    }

    @IBAction func didDoubleClickCell(_: AnyObject?) {
        let row = tableView.clickedRow
        openCrash(atIndex: row)
    }

    @IBAction func openFile(_: AnyObject?) {
        let row = tableView.selectedRow
        openCrash(atIndex: row)
    }

    @IBAction func reloadFiles(_: AnyObject?) {
        let deviceID = self.deviceID
        self.deviceID = nil
        reloadData(withDeviceID: deviceID)
    }

    @IBAction func removeFile(_: AnyObject?) {
        guard let afcClient = afcClient else {
            return
        }

        let selectedIndexes = tableView.selectedRowIndexes
        if selectedIndexes.isEmpty {
            return
        }

        let files = selectedIndexes.map { index in
            self.fileList[index]
        }

        showLoading()
        DispatchQueue.global().async {
            files.forEach { file in
                afcClient.remove(file.path)
            }
            self.reloadFiles(nil)
            self.hideLoading()
        }
    }
}

extension NSUserInterfaceItemIdentifier {
    static let cellProcess = NSUserInterfaceItemIdentifier("Process")
    static let cellDate = NSUserInterfaceItemIdentifier("Date")
}

extension CrashImporterViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return fileList.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cell: NSTableCellView?
        let file = fileList[row]
        if tableColumn == tableView.tableColumns[0] {
            cell = tableView.makeView(withIdentifier: .cellProcess, owner: nil) as? NSTableCellView
            cell?.textField?.stringValue = file.crashFileDisplayName
        } else {
            cell = tableView.makeView(withIdentifier: .cellDate, owner: nil) as? NSTableCellView
            cell?.textField?.stringValue = file.date.formattedString
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        fileList = (fileList as NSArray).sortedArray(using: tableView.sortDescriptors) as! [MDDeviceFile]
        self.tableView.reloadData()
    }

    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let provider = DeviceFileProvider(fileType: "public.plain-text", delegate: self)
        provider.file = fileList[row]
        return provider
    }

    func tableViewSelectionDidChange(_: Notification) {
        // self.openButton.isEnabled = self.tableView.selectedRow >= 0
    }
}

extension CrashImporterViewController: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType _: String) -> String {
        guard let privider = filePromiseProvider as? DeviceFileProvider else {
            return ""
        }
        return privider.file?.localCrashFileName ?? ""
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let privider = filePromiseProvider as? DeviceFileProvider,
              let file = privider.file,
              let afcClient = afcClient
        else {
            completionHandler(FileError.createFailed)
            return
        }

        _ = afcClient.copyCrashFile(file, to: url)
        completionHandler(nil)
    }

    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        return OperationQueue()
    }
}
