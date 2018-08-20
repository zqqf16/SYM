// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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

extension NSPasteboard.PasteboardType {
    static let backwardsCompatibleFileURL: NSPasteboard.PasteboardType = {
        if #available(OSX 10.13, *) {
            return NSPasteboard.PasteboardType.fileURL
        } else {
            return NSPasteboard.PasteboardType(kUTTypeFileURL as String)
        }
    } ()
}

extension SYMDeviceFile {
    var isCrash: Bool {
        return !self.isDirectory && self.name.contains(".ips")
    }
    
    var localFileName: String {
        let name = self.name.components(separatedBy: ".ips")[0]
        return "\(name).crash"
    }
}

extension SYMDevice {
    func copyFile(_ file: SYMDeviceFile, to directory: String) -> String? {
        guard let content = self.read(file) else {
            return nil
        }
        
        let path = (directory as NSString).appendingPathComponent(file.localFileName)
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }
        return path
    }
}

class DeviceFileProvider: NSFilePromiseProvider {
    var device: SYMDevice?
    var file: SYMDeviceFile?
}

class CrashImporterViewController: NSViewController {
    
    private var device: SYMDevice?
    private var fileList: [SYMDeviceFile] = []

    @IBOutlet var tableView: NSTableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.deviceConnected(nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceConnected(_:)), name: NSNotification.Name.SYMDeviceMonitor, object: nil)
        
        let descriptorProcess = NSSortDescriptor(keyPath: \SYMDeviceFile.name, ascending: true)
        let descriptorDate = NSSortDescriptor(keyPath: \SYMDeviceFile.date, ascending: true)
        self.tableView.tableColumns[0].sortDescriptorPrototype = descriptorProcess
        self.tableView.tableColumns[1].sortDescriptorPrototype = descriptorDate
        
        self.tableView.registerForDraggedTypes([.backwardsCompatibleFileURL])
        self.tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }
    
    @objc func deviceConnected(_ notification:Notification?) {
        DispatchQueue.global().async {
            if SYMDeviceMonitor.shared().deviceConnected {
                self.device = SYMDevice(deviceID: nil)
            } else {
                self.device = nil;
            }
            
            let list = self.device?.crashList() ?? []
            
            DispatchQueue.main.async {
                self.fileList = list.filter { $0.isCrash }.sorted(by: { (file1, file2) -> Bool in
                    return file1.date > file2.date
                })
                self.tableView.reloadData()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func didDoubleClickCell(_ sender: AnyObject?) {
        let row = self.tableView.clickedRow
        if row < 0 || row > self.fileList.count - 1 {
            return
        }
        
        let file = self.fileList[row]
        DispatchQueue.global().async {
            guard let udid = self.device?.deviceID(),
                let path = self.device?.copyFile(file, to: FileManager.default.localCrashDirectory(udid))
            else {
                return
            }
            DispatchQueue.main.async {
                DocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: path), display: true, completionHandler: { (document, success, error) in
                    //
                })
            }
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
            cell?.textField?.stringValue = file.name
        } else {
            cell = tableView.makeView(withIdentifier: .cellDate, owner: nil) as? NSTableCellView
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            cell?.textField?.stringValue = formatter.string(from: file.date)
        }
        return cell
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        self.fileList = (self.fileList as NSArray).sortedArray(using: tableView.sortDescriptors) as! [SYMDeviceFile]
        self.tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let provider = DeviceFileProvider(fileType: "public.plain-text", delegate: self)
        provider.device = self.device
        provider.file = self.fileList[row]
        return provider
    }
}

extension CrashImporterViewController: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        guard let privider = filePromiseProvider as? DeviceFileProvider else {
            return ""
        }
        return privider.file?.localFileName ?? ""
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let privider = filePromiseProvider as? DeviceFileProvider,
            let device = privider.device,
            let file = privider.file,
            let content = device.read(file)
            else {
                completionHandler(FileError.createFailed)
                return
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            
        }
        completionHandler(nil)
    }
    
    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return OperationQueue()
    }
}
