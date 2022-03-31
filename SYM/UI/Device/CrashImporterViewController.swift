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
        return !self.isDirectory && (self.name.contains(".ips") || self.name.contains(".crash"))
    }
    
    var localCrashFileName: String {
        let name = self.name.components(separatedBy: ".ips")[0]
        return "\(name).crash"
    }
    
    var crashFileDisplayName: String {
        var components = self.name.components(separatedBy: ".")
        if components.last == "synced" {
            components.removeLast()
            return components.joined(separator: ".")
        }
        
        return self.name
    }
}

extension MDAfcClient {
    func copyCrashFile(_ file: MDDeviceFile, to url: URL) -> String? {
        guard let content = self.read(file.path) else {
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
        let lockdown = MDLockdown(udid: self.deviceID)
        return MDAfcClient.crash(with: lockdown)
    }

    private var deviceID: String?
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet weak var openButton: NSButton!
    var loadingIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let descriptorProcess = NSSortDescriptor(keyPath: \MDDeviceFile.lowercaseName, ascending: true)
        let descriptorDate = NSSortDescriptor(keyPath: \MDDeviceFile.date, ascending: true)
        self.tableView.tableColumns[0].sortDescriptorPrototype = descriptorProcess
        self.tableView.tableColumns[1].sortDescriptorPrototype = descriptorDate
        
        self.tableView.registerForDraggedTypes([.backwardsCompatibleFileURL])
        self.tableView.setDraggingSourceOperationMask(.copy, forLocal: false)        
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
        
        self.showLoading()
        DispatchQueue.global().async {
            let lockdown = MDLockdown(udid: self.deviceID)
            if let moveService = lockdown.startService(withIdentifier: "com.apple.crashreportmover") {
                // trigger moving
                moveService.ping()
            }
            let crashList = self.afcClient?.crashFiles() ?? []
            DispatchQueue.main.async {
                self.fileList = crashList.filter { $0.isCrash }.sorted(by: { (file1, file2) -> Bool in
                    return file1.date > file2.date
                })
                self.tableView.reloadData()
                self.hideLoading()
            }
        }
    }
    
    func openCrash(atIndex index: Int) {
        if index < 0 || index > self.fileList.count - 1 {
            return
        }

        self.showLoading()

        let file = self.fileList[index]
        DispatchQueue.global().async {
            guard let udid = self.deviceID else {
                self.hideLoading()
                return
            }
            
            let path = FileManager.default.localCrashDirectory(udid) + "/\(file.localCrashFileName)"
            let url = URL(fileURLWithPath: path)
            if let _ =  self.afcClient?.copyCrashFile(file, to: url) {
                DispatchQueue.main.async {
                    DocumentController.shared.openDocument(withContentsOf: url, display: true, completionHandler: { (document, success, error) in
                        self.hideLoading()
                    })
                }
            }
        }
    }
    
    @IBAction func didDoubleClickCell(_ sender: AnyObject?) {
        let row = self.tableView.clickedRow
        self.openCrash(atIndex: row)
    }

    @IBAction func openFile(_ sender: AnyObject?) {
        let row = self.tableView.selectedRow
        self.openCrash(atIndex: row)
    }
    
    @IBAction func reloadFiles(_ sender: AnyObject?) {
        let deviceID = self.deviceID
        self.deviceID = nil
        self.reloadData(withDeviceID: deviceID)
    }
    
    @IBAction func removeFile(_ sender: AnyObject?) {
        guard let afcClient = afcClient else {
            return
        }

        let selectedIndexes = self.tableView.selectedRowIndexes
        if selectedIndexes.isEmpty {
            return
        }
        
        let files = selectedIndexes.map { index in
            self.fileList[index]
        }
        
        self.showLoading()
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
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.fileList.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cell: NSTableCellView?
        let file = self.fileList[row]
        if tableColumn == tableView.tableColumns[0] {
            cell = tableView.makeView(withIdentifier: .cellProcess, owner: nil) as? NSTableCellView
            cell?.textField?.stringValue = file.crashFileDisplayName
        } else {
            cell = tableView.makeView(withIdentifier: .cellDate, owner: nil) as? NSTableCellView
            cell?.textField?.stringValue = file.date.formattedString
        }
        return cell
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        self.fileList = (self.fileList as NSArray).sortedArray(using: tableView.sortDescriptors) as! [MDDeviceFile]
        self.tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let provider = DeviceFileProvider(fileType: "public.plain-text", delegate: self)
        provider.file = self.fileList[row]
        return provider
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        //self.openButton.isEnabled = self.tableView.selectedRow >= 0
    }
}

extension CrashImporterViewController: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        guard let privider = filePromiseProvider as? DeviceFileProvider else {
            return ""
        }
        return privider.file?.localCrashFileName ?? ""
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let privider = filePromiseProvider as? DeviceFileProvider,
            let file = privider.file,
            let afcClient = self.afcClient
            else {
                completionHandler(FileError.createFailed)
                return
        }
        
        let _ = afcClient.copyCrashFile(file, to: url)
        completionHandler(nil)
    }
    
    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return OperationQueue()
    }
}
