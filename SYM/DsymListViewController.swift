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

class DsymTableCellView: NSTableCellView {
    @IBOutlet weak var path: NSTextField!
    @IBOutlet weak var uuids: NSTextField?
    
    func config(_ dsym: DsymFile) {
        self.textField?.stringValue = dsym.name
        self.path.stringValue = dsym.path
        self.uuids?.stringValue = dsym.uuids.joined(separator: " - ")
        self.toolTip = dsym.path
    }
}

protocol DsymListViewControllerDelegate: class {
    func didSelectDsym(_ dsym: DsymFile) -> Void
}

class DsymListViewController: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var uuidLabel: NSTextField!

    private var dsymList: [DsymFile] = []

    weak var delegate: DsymListViewControllerDelegate?
    var uuid: String?
    
    func loadData() {
        self.dsymList = DsymFileManager.shared.dsymFiles
        self.dsymList.sort { (a, b) -> Bool in
            return (a.name < b.name)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupMenu()
        self.loadData()
        
        self.outlineView.delegate = self
        self.outlineView.dataSource = self
        self.selectCurrentDsym()
        
        NotificationCenter.default.addObserver(self, selector: #selector(dsymListDidUpdate), name: .dsymListUpdated, object: nil)
        
        let uuid = self.uuid ?? "NULL"
        self.uuidLabel.stringValue = "UUID: \(uuid)"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func dsymListDidUpdate(notification: Notification) {
        DispatchQueue.main.async {
            self.loadData()
            self.outlineView.reloadData()
            self.selectCurrentDsym()
        }
    }
    
    private func selectCurrentDsym() {
        guard let uuid = self.uuid,
              let dsym = DsymFileManager.shared.dsymFile(withUUID: uuid)
        else {
            return
        }
        
        let row = self.outlineView.row(forItem: dsym)
        if row > -1 {
            self.outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu(title: "dSYM")
        let showItem = NSMenuItem(title: "Show in Finder", action: #selector(showDsymFileInFinder), keyEquivalent: "")
        showItem.isEnabled = true
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        self.outlineView.menu = menu
    }
    
    private func selectedItem() -> DsymFile? {
        let selectedRow = self.outlineView.selectedRow;
        if selectedRow == NSNotFound {
            return nil
        }
        if let selectedItem = self.outlineView.item(atRow: selectedRow) as? DsymFile {
            return selectedItem
        };
        
        return nil
    }
    
    @objc func showDsymFileInFinder() {
        let row = self.outlineView.clickedRow
        if row == NSNotFound {
            return
        }
        
        if let dsym = self.outlineView.item(atRow: row) as? DsymFile {
            let fileURL = URL(fileURLWithPath: dsym.path)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        }
    }
    
    @IBAction func didSelectDsym(_ sender: AnyObject?) {
        if let delegate = self.delegate, let selectedItem = self.selectedItem() {
            delegate.didSelectDsym(selectedItem)
        };
        
        self.dismiss(nil)
    }
    
    @IBAction func reload(_ sender: AnyObject?) {
        DsymFileManager.shared.reload()
    }
}

extension NSUserInterfaceItemIdentifier {
    static let dsymCell = NSUserInterfaceItemIdentifier("DsymCell")
}

extension DsymListViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return !(item is XCArchiveFile)
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view = outlineView.makeView(withIdentifier: .dsymCell, owner: self) as? DsymTableCellView
        if let dsym = item as? DsymFile {
            view?.config(dsym)
        }
        
        return view
    }
}

extension DsymListViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let xcarchive = item as? XCArchiveFile {
            return xcarchive.dsyms.count
        }
        
        return self.dsymList.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let xcarchive = item as? XCArchiveFile {
            return xcarchive.dsyms[index]
        }
        
        return self.dsymList[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let _ = item as? XCArchiveFile {
            return true
        }
        
        return false
    }
}
