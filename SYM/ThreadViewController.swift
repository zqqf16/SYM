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


class ThreadViewController: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var titleView: ThreadTitleView!

    var crash: CrashReport?
    var threads: [CrashReport.Thread]?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.titleView.delegate = self
        self.titleView.title.placeholderString = nil

        self.outlineView.delegate = self
        self.outlineView.dataSource = self
        
        let _ = NotificationCenter.default.then {
            $0.addObserver(self, selector: #selector(handleOpenCrash), name: .openCrashReport, object: nil)
            $0.addObserver(self, selector: #selector(handleOpenCrash), name: .crashSymbolicated, object: nil)
            $0.addObserver(self, selector: #selector(handleOpenCrash), name: .crashUpdated, object: nil)
        }
    }
    
    func handleOpenCrash(notification: Notification) {
        if let wc = notification.object as? MainWindowController, wc == self.windowController() {
            self.reloadCrash()
        }
    }
    
    func reloadCrash() {
        self.crash = self.currentCrashFile()?.crash
        self.threads = self.crash?.threads
        self.outlineView?.reloadData()
        self.titleView.title.stringValue = self.crash?.reason ?? ""
        self.expandCrashedThread()
    }
    
    private func expandCrashedThread() {
        var firstRow: Int?
        if let ts = self.threads {
            for thread in ts {
                if thread.number == nil || thread.crashed {
                    if firstRow == nil {
                        firstRow = self.outlineView?.row(forItem: thread)
                    }
                    self.outlineView.expandItem(thread)
                }
            }
        }
        
        if let row = firstRow {
            self.outlineView.scrollRowToVisible(row)
        }
    }
    
    func updateThreadState(_ isCollapse: Bool) {
        var fun: (_ item: Any) -> Void
        if isCollapse {
            fun = { (item) in
                self.outlineView.collapseItem(item)
            }
        } else {
            fun = { (item) in
                self.outlineView.expandItem(item)
            }
        }

        if let ts = self.threads {
            for thread in ts {
                fun(thread)
            }
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        if self.crash == nil {
            self.reloadCrash()
        }
    }
}

extension ThreadViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var view: NSTableCellView?
        
        if let thread = item as? CrashReport.Thread {
            view = outlineView.make(withIdentifier: "ThreadCell", owner: self) as? NSTableCellView
            if let textField = view?.textField {
                textField.stringValue = thread.description
            }
        } else if let frame = item as? CrashReport.Frame {
            if frame.isKey {
                view = outlineView.make(withIdentifier: "KeyFrameCell", owner: self) as? NSTableCellView
            } else {
                view = outlineView.make(withIdentifier: "FrameCell", owner: self) as? NSTableCellView
            }
            if let textField = view?.textField {
                textField.stringValue = frame.description()
            }
        }
        
        return view
    }
}

extension ThreadViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let thread = item as? CrashReport.Thread {
            return thread.backtrace.count
        }

        return self.threads?.count ?? 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let thread = item as? CrashReport.Thread {
            return thread.backtrace[index]
        }
        
        return self.threads![index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let _ = item as? CrashReport.Thread {
            return true
        }
        
        return false
    }
}

extension ThreadViewController: ThreadTitleViewDelegate {
    func didCollapseButtonClicked(_ isCollapse: Bool) {
        self.updateThreadState(isCollapse)
    }
    
    @IBAction func expandThreads(_ sender: AnyObject?) {
        if let button = sender as? NSButton {
            if button.state == NSOnState {
                button.image = NSImage(named: "collapse")
                self.didCollapseButtonClicked(false)
            } else {
                button.image = NSImage(named: "expand")
                self.didCollapseButtonClicked(true)
            }
        }
    }
}
