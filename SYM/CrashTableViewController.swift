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


let CTDidSelectCrashNotification = "CTDidSelectCrashNotification"


class CrashTableCellView: NSTableCellView {
    @IBOutlet weak var subtitle: NSTextField!
    @IBOutlet weak var deleteButton: NSButton!
}

class CrashTableViewController: TableViewController {
    @IBOutlet weak var deleteCell: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.registerNotifications()
    }

    @IBAction func deleteCell(sender: NSButton) {
        let row = self.tableView.rowForView(sender)
        CrashManager.sharedInstance.crashes.removeAtIndex(row)
        self.tableView.removeRowsAtIndexes(NSIndexSet(index: row), withAnimation: .SlideLeft)
        let selectedRow = self.tableView.selectedRow
        self.selectRowAtIndex(selectedRow)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func registerNotifications() {
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(didOpenCrash), name: CMDidOpenCrashFilesNotification, object: nil)
    }

    func didOpenCrash(notification: NSNotification) {
        self.selectedRow = 0
        self.tableView.reloadData()
        self.selectRowAtIndex(0)
    }
    
    override func didSelectRowAtIndex(index: Int) {
        NSNotificationCenter.defaultCenter().postNotificationName(CTDidSelectCrashNotification, object: index)
    }
}

extension CrashTableViewController: NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return CrashManager.sharedInstance.crashes.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeViewWithIdentifier("CrashTableCellView", owner: nil) as? CrashTableCellView {
            let crash = CrashManager.sharedInstance.crashes[row]
            cell.textField?.stringValue = crash.reason ?? "Untitled"
            cell.subtitle.stringValue = crash.extraInfo
            if crash.crashInfo != nil {
                cell.toolTip = crash.crashInfo
            } else {
                cell.toolTip = crash.filePath
            }
            return cell
        }
        
        return nil
    }

}

extension Crash {
    var extraInfo: String {
        var info: String = ""
        if self.appVersion != nil {
            info += "Version: \(self.appVersion!) "
        }
        if self.numberOfErrors != nil {
            info += "Errors: \(self.numberOfErrors!)"
        }
        
        if info.characters.count == 0 {
            if self.filePath != nil {
                info = (self.filePath! as NSString).lastPathComponent
            }
        }
        
        return info
    }
}