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

extension NSPopUpButton {
    func reloadItemsWithApps(_ apps: [MDAppInfo]) {
        self.removeAllItems()
        apps.forEach({ (app) in
            self.addItem(withTitle: "\(app.name)(\(app.identifier))")
        })
    }
}

class FileBrowserViewController: DeviceBaseViewController {

    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var exportIndicator: NSProgressIndicator!
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var appButton: NSPopUpButton!
    
    var rootDir: MDDeviceFile!
    var afcClient: MDAfcClient! {
        didSet {
            self.rootDir = MDDeviceFile(afcClient: self.afcClient)
            self.rootDir.path = "."
            self.rootDir.isDirectory = true
        }
    }
    var appList: [MDAppInfo] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func loadAppList(_ udid: String?) {
        DispatchQueue.global().async {
            let lockdown = MDLockdown()
            let instproxy = MDInstProxy(lockdown: lockdown)
            self.appList = instproxy.listApps().filter { $0.isDeveloping }
            DispatchQueue.main.async {
                self.appButton.reloadItemsWithApps(self.appList)
                self.appButton.selectItem(at: 0)
                self.changeApp(self.appButton)
            }
        }
    }
    
    func loadFiles(_ app: MDAppInfo?) {
        if let appInfo = app {
            let lockdown = MDLockdown()
            let houseArrest = MDHouseArrest(lockdown: lockdown, appID: appInfo.identifier)
            self.afcClient = MDAfcClient.fileClient(with: houseArrest)
        } else {
            self.rootDir = nil
        }
        self.outlineView.reloadData()
    }
    
    override func deviceConnectionChanged() {
        self.loadAppList(self.deviceList.first)
    }
    
    override func deviceSelectionChanged(_ udid: String?) {
        self.loadAppList(udid)
    }
    
    @IBAction func didClickExportButton(_ sender: NSButton) {
        let row = self.outlineView.selectedRow
        self.exportFile(atIndex: row)
    }

    @IBAction func didDoubleClickCell(_ sender: AnyObject?) {
        let row = self.outlineView.clickedRow
        self.exportFile(atIndex: row)
    }

    private func exportFile(atIndex index: Int) {
        guard index >= 0, let file = self.outlineView.item(atRow: index) as? MDDeviceFile else {
            return
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
            self.exportFile(file, toURL: dest)
        }
    }

    private func exportFile(_ file: MDDeviceFile, toURL url: URL) {
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
    
    @IBAction func changeApp(_ sender: NSPopUpButton) {
        var app: MDAppInfo?
        let index = self.appButton.indexOfSelectedItem
        if index >= 0 && index < self.appList.count {
            app = self.appList[index]
        }
        DispatchQueue.main.async {
            self.loadFiles(app)
        }
    }
}

extension FileBrowserViewController: NSOutlineViewDelegate, NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let file = item as? MDDeviceFile, file.isDirectory, let children = file.children {
            return children.count
        }
        
        return self.rootDir?.children?.count ?? 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let file = item as? MDDeviceFile, file.isDirectory, let children = file.children {
            return children[index]
        }
        
        return self.rootDir!.children![index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let file = item as? MDDeviceFile, file.isDirectory, let children = file.children {
            return children.count > 0
        }

        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var view: NSTableCellView?
        guard let file = item as? MDDeviceFile else {
            return view
        }
        
        view = outlineView.makeView(withIdentifier: tableColumn!.identifier, owner: nil) as? NSTableCellView
        if tableColumn == outlineView.tableColumns[0] {
            view?.textField?.stringValue = file.name
            if file.isDirectory {
                view?.imageView?.image = NSImage(named: NSImage.folderName as NSImage.Name)
            } else {
                view?.imageView?.image = NSWorkspace.shared.icon(forFileType: file.extension)
            }
        } else if tableColumn == outlineView.tableColumns[1] {
            view?.textField?.stringValue = file.date.formattedString
        } else {
            view?.textField?.stringValue = "\(file.size.readableSize)"
        }
        
        return view
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
    }
}
