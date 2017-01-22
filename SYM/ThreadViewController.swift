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


extension CrashReport.Frame {
    var pretty: String {
        let index = self.index.extendToLength(2)
        let image = self.image.extendToLength(26)
        let symbol = self.symbol ?? ""
        return "\(index) \(image) \(symbol)"
    }
}


class ThreadViewController: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView!
    
    var crash: CrashReport?
    var threads: [CrashReport.Thread]?
    
    @IBOutlet weak var threadButton: NSPopUpButton!

    // MARK: - Load Crash
    
    func handleOpenCrash(notification: Notification) {
        if let wc = notification.object as? MainWindowController, wc == self.windowController() {
            self.reloadCrash()
        }
    }
    
    func reloadCrash() {
        self.crash = self.currentCrashFile()?.crash
        self.threads = self.crash?.threads
        self.outlineView?.reloadData()
        self.updateThreadState()
    }
    
    @IBAction func expandThread(_ sender: NSPopUpButton) {
        self.updateThreadState()
    }

    func updateThreadState() {
        guard let threads = self.threads else {
            return
        }

        let index = self.threadButton.indexOfSelectedItem
        if index == 0 {
            for thread in threads {
                self.outlineView.expandItem(thread)
            }
        } else {
            for thread in threads {
                if thread.number == nil || thread.crashed {
                    self.outlineView.expandItem(thread)
                } else {
                    self.outlineView.collapseItem(thread)
                }
            }
        }
        
        self.outlineView.scrollRowToVisible(0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.outlineView.delegate = self
        self.outlineView.dataSource = self
        
        let _ = NotificationCenter.default.then {
            $0.addObserver(self, selector: #selector(handleOpenCrash), name: .openCrashReport, object: nil)
            $0.addObserver(self, selector: #selector(handleOpenCrash), name: .crashSymbolicated, object: nil)
            $0.addObserver(self, selector: #selector(handleOpenCrash), name: .crashUpdated, object: nil)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if self.crash == nil {
            self.reloadCrash()
        }
    }
}


// MARK: - OutlineView Delegate

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
                textField.stringValue = frame.pretty
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


// MARK: - Find bar

extension ThreadViewController: NSSearchFieldDelegate {
    func showSearchResult(_ text: String) {
        let predicate = NSPredicate(format: "pretty contains[cd] %@", text)
        
        DispatchQueue.main.async {
            var threads: [CrashReport.Thread] = []
            for t in self.crash!.threads {
                let bt = t.backtrace.filter({ predicate.evaluate(with: $0) })
                if bt.count > 0 {
                    let thread = CrashReport.Thread()
                    thread.name = t.name
                    thread.number = t.number
                    thread.crashed = t.crashed
                    thread.backtrace = bt
                    threads.append(thread)
                }
            }
            
            self.threads = threads
            self.outlineView.reloadData()
            self.updateThreadState()
        }
    }
    
    func searchFieldDidStartSearching(_ sender: NSSearchField) {
        guard self.crash != nil else {
            return
        }
        
        self.showSearchResult(sender.stringValue)
    }
    
    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        if let threads = self.crash?.threads {
            self.threads = threads
            self.outlineView.reloadData()
            self.updateThreadState()
        }
    }
}
