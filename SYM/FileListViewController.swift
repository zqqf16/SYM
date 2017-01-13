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


class FileListViewController: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView?

    var crashFile: CrashFile?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.outlineView?.delegate = self
        self.outlineView?.dataSource = self
        
        self.setupMenu()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        // check crash file
        if self.crashFile == nil, let f = self.document()?.crashFile {
            self.crashFile = f
            
            self.outlineView?.reloadData()
            self.outlineView?.expandItem(self.crashFile!)
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu(title: "Crash File")
        let showItem = NSMenuItem(title: "Show in Finder", action: #selector(showCrashFileInFinder), keyEquivalent: "")
        showItem.isEnabled = true
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        self.outlineView?.menu = menu
    }
    
    func showCrashFileInFinder() {
        let row = self.outlineView!.clickedRow
        if let file = self.outlineView?.item(atRow: row) as? CrashFile {
            if file.url != nil {
                NSWorkspace.shared().activateFileViewerSelecting([file.url!])
            }
        }
    }
}

extension FileListViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var view: NSTableCellView?
        view = outlineView.make(withIdentifier: "CrashCell", owner: self) as? NSTableCellView
        if let textField = view?.textField {
            if let file = item as? CrashFile {
                textField.stringValue = file.name
            } else {
                textField.stringValue = "Untitled"
            }
            textField.sizeToFit()
        }
        
        if let image = view?.imageView {
            if let file = item as? CrashFile {
                if file.children != nil && file.children!.count > 0 {
                    image.image = NSImage(named: "floder")
                }
            }
        }
        
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, item: Any, mouseLocation: NSPoint) -> String {
        if let file = item as? CrashFile {
            if let url = file.url {
                return url.absoluteString
            } else {
                return file.name
            }
        }
        
        return ""
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = self.outlineView!.selectedRow
        if let file = self.outlineView!.item(atRow: row) as? CrashFile {
            self.openCrash(file)
        }
    }
}

extension FileListViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let file = item as? CrashFile {
            return file.children?.count ?? 0
        }
        
        if self.crashFile != nil {
            return 1
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let file = item as? CrashFile {
            return file.children![index]
        }
        
        return self.crashFile!
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let file = item as? CrashFile {
            return file.children != nil && file.children!.count > 0
        }
        
        return false
    }
}
