// The MIT License (MIT)
//
// Copyright (c) 2017 - 2019 zqqf16
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

class FileBrowserViewController: DeviceBaseViewController {

    @IBOutlet weak var browser: NSBrowser!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var exportIndicator: NSProgressIndicator!
    
    var afcClient: MDAfcClient!
    var appList: [MDAppInfo] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func loadAppList(_ udid: String?) {
        let lockdown = MDLockdown()
        let instproxy = MDInstProxy(lockdown: lockdown)
        self.appList = instproxy.listApps().filter { $0.isDeveloping }
        self.tableView.reloadData()
    }
    
    func loadFiles(_ app: MDAppInfo) {
        let lockdown = MDLockdown()
        let houseArrest = MDHouseArrest(lockdown: lockdown, appID: app.identifier)
        self.afcClient = MDAfcClient.fileClient(with: houseArrest)
        self.browser.loadColumnZero()
    }
    
    override func deviceConnectionChanged() {
        self.loadAppList(self.deviceList.first)
    }
    
    override func deviceSelectionChanged(_ udid: String?) {
        self.loadAppList(udid)
    }
    
    @IBAction func exportFile(_ sender: NSButton) {
        guard let indexPath = self.browser.selectionIndexPath,
            let file = self.browser.item(at: indexPath) as? MDDeviceFile else {
                return;
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = file.name
        savePanel.beginSheetModal(for: self.view.window!) { [weak savePanel] (result) in
            guard result == .OK, let url = savePanel?.url else {
                return
            }
            var name = savePanel?.nameFieldStringValue ?? ""
            if name.isEmpty {
                name = file.name
            }
            let dest = URL(fileURLWithPath: name, relativeTo: url)
            self.doExport(file, url: dest)
        }
    }
    
    private func doExport(_ file: MDDeviceFile, url: URL) {
        self.exportIndicator.startAnimation(nil)
        self.exportIndicator.isHidden = false
        self.exportButton.isEnabled = false
        DispatchQueue.global().async {
            file.copy(url.path)
            DispatchQueue.main.async {
                self.exportIndicator.stopAnimation(nil)
                self.exportIndicator.isHidden = true
                self.exportButton.isEnabled = true
            }
        }
    }
}

extension FileBrowserViewController: NSBrowserDelegate {
    func rootItem(for browser: NSBrowser) -> Any? {
        if self.afcClient == nil {
            return nil
        }
        let file = MDDeviceFile(afcClient: self.afcClient)
        file.path = "."
        file.isDirectory = true
        return file
    }
    
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        guard let file = item as? MDDeviceFile else {
            return ""
        }
        return file.name
    }
    
    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let file = item as? MDDeviceFile, file.isDirectory else {
            return 0
        }
        return file.children?.count ?? 0
    }
    
    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        guard let file = item as? MDDeviceFile, file.isDirectory else {
            return self.rootItem(for: browser)!
        }
        
        if let fileList = file.children {
            return fileList[index]
        } else {
            return self.rootItem(for: browser)!
        }
    }
    
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        guard let file = item as? MDDeviceFile else {
            return true
        }
        
        return !file.isDirectory
    }
}

extension NSUserInterfaceItemIdentifier {
    static let appName = NSUserInterfaceItemIdentifier("appName")
}

extension FileBrowserViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.appList.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = self.appList[row]
        let cell = tableView.makeView(withIdentifier: .appName, owner: nil) as? NSTableCellView
        cell?.textField?.stringValue = "\(app.name)(\(app.identifier))"
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = self.tableView.selectedRow
        if row >= 0 && row < self.appList.count {
            let app = self.appList[row]
            self.loadFiles(app)
        }
    }
}
