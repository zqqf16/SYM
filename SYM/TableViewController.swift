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


class TableViewController: NSViewController, NSTableViewDelegate {
    @IBOutlet weak var tableView: NSTableView!
    var selectedRow: Int?
    
    var selectedBackgroundColor = NSColor(calibratedRed: 15/255, green: 15/255, blue: 15/255, alpha:0.05)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.tableView.setDelegate(self)
    }
    
    func didSelectRowAtIndex(index: Int) {
        // do nothing
    }
    
    func selectRowAtIndex(index: Int) {
        self.tableView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: true)
        self.didSelectRowAtIndex(index)
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let currentRow = tableView.selectedRowIndexes
        for rowIndex in currentRow {
            if let currentRowView = tableView.rowViewAtRow(rowIndex, makeIfNecessary: false) {
                currentRowView.backgroundColor = NSColor.clearColor()
            }
        }
        
        if let rowView = tableView.rowViewAtRow(row, makeIfNecessary: false) {
            rowView.backgroundColor = self.selectedBackgroundColor
        }

        self.selectedRow = row
        self.didSelectRowAtIndex(row)
        return true
    }
    
    func tableView(tableView: NSTableView, didAddRowView rowView: NSTableRowView, forRow row: Int) {
        if row == self.selectedRow {
            rowView.backgroundColor = self.selectedBackgroundColor
        }
    }
}
