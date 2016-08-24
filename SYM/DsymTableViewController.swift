// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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

class DsymTableViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self

        //self.tableView.columnAutoresizingStyle = .UniformColumnAutoresizingStyle
        self.setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu(title: "dSYM")
        let showItem = NSMenuItem(title: "Show in Finder", action: #selector(showDsymFileInFinder), keyEquivalent: "")
        showItem.isEnabled = true
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        self.tableView.menu = menu
    }
    
    func showDsymFileInFinder() {
        let row = self.tableView.clickedRow
        let dsym = DsymManager.sharedInstance.dsyms![row]
        let fileURL = URL(fileURLWithPath: dsym.path)
        NSWorkspace.shared().activateFileViewerSelecting([fileURL])
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let dsyms = DsymManager.sharedInstance.dsyms {
            return dsyms.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let dsym = DsymManager.sharedInstance.dsyms![row]

        var cellID: String?
        var text: String?

        if tableColumn == tableView.tableColumns[0] {
            cellID = "DsymNameCell"
            text = dsym.name
        } else if tableColumn == tableView.tableColumns[1] {
            cellID = "DsymUUIDCell"
            text = dsym.uuids.joined(separator: " | ")
        } else if tableColumn == tableView.tableColumns[2] {
            cellID = "DsymPathCell"
            text = dsym.path
        } else {
            return nil
        }
        
        if let cell = tableView.make(withIdentifier: cellID!, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text!
            cell.toolTip = text!
            return cell
        }
        
        return nil
    }
}
