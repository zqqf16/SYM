// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
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

extension Notification.Name {
    static let dsymBinaryListDidUpdated = Notification.Name("sym.dsym.binaryListDidUpdated")
}

class DsymWindowController: NSWindowController {
    let notificationCenter: NotificationCenter = NotificationCenter()
    var binaries: [Binary] = [] {
        didSet {
            self.notificationCenter.post(name: .dsymBinaryListDidUpdated, object: self.binaries)
        }
    }
}

class DsymViewController: NSViewController {
    var dsymWindowController: DsymWindowController? {
        if let wc = self.view.window?.windowController as? DsymWindowController {
            return wc
        }
        return nil
    }
}

struct BinaryGroup {
    let name: String
    let children: [Binary]
}

class DsymBinaryListViewController: DsymViewController {
    @IBOutlet weak var outletView: NSOutlineView!
   
    var binaries: [Binary]? {
        return self.dsymWindowController?.binaries
    }

    private var binaryGroups: [BinaryGroup] = []

    private func updateBinaryGroups() {
        var system: [Binary] = []
        var app: [Binary] = []
        self.binaries?.forEach({ (binary) in
            if binary.inApp {
                app.append(binary)
            } else {
                system.append(binary)
            }
        })
        
        self.binaryGroups.removeAll()
        self.binaryGroups.append(BinaryGroup(name: "App", children: app))
        self.binaryGroups.append(BinaryGroup(name: "System", children: system))
        
        self.outletView.reloadData()
    }
    
    override func viewWillLayout() {
        super.viewWillLayout()
        self.updateBinaryGroups()
        
        self.outletView.expandItem(self.outletView.item(atRow: 0))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.outletView.delegate = self
        self.outletView.dataSource = self
    }
}

extension DsymBinaryListViewController: NSOutlineViewDelegate, NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int{
        if let group = item as? BinaryGroup {
            return group.children.count
        }
        
        if item == nil {
            return self.binaryGroups.count
        }

        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let group = item as? BinaryGroup {
            return group.children[index]
        }
        
        return self.binaryGroups[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier(rawValue: "BinaryName")
        let view = outlineView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView
        
        var title: String
        if let group = item as? BinaryGroup {
            title = group.name
        } else {
            let binary = item as! Binary
            title = binary.name
        }
        view?.textField?.stringValue = title
        
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let group = item as? BinaryGroup {
            return group.children.count > 0
        }
        
        return false
    }

    
    func outlineViewSelectionDidChange(_ notification: Notification) {
    }
}
