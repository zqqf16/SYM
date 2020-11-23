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

protocol SidebarNode {
    var title: String { get }
    var children: [SidebarNode]? { get }
    var image: NSImage? { get }
    var isGroup: Bool { get }
    var isSelectable: Bool { get }
}

extension SidebarNode {
    var cellIdentifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(rawValue: isGroup ? "HeaderCell" : "DataCell")
    }
}

protocol DeviceSidebarViewControllerDelegate: class {
    func sidebar(_ sidebar: DeviceSidebarViewController, didSelectNode node: SidebarNode)
}

class DeviceSidebarViewController: NSViewController {
    @IBOutlet weak var outlineView: NSOutlineView!
    
    weak var delegate: DeviceSidebarViewControllerDelegate?
    var nodes: [SidebarNode] = [] {
        didSet {
            self.outlineView.reloadData()
            self.outlineView.expandItem(nil, expandChildren: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.outlineView.dataSource = self
        self.outlineView.delegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.outlineView.expandItem(nil, expandChildren: true)
    }
}

extension DeviceSidebarViewController : NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode,
              let cell = outlineView.makeView(withIdentifier: node.cellIdentifier, owner: self) as? NSTableCellView else {
            return nil
        }
        
        cell.textField?.stringValue = node.title
        cell.imageView?.image = node.image

        return cell
    }
}

extension DeviceSidebarViewController : NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? SidebarNode {
            return node.children?.count ?? 0
        }

        return self.nodes.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? SidebarNode, node.children != nil {
            return node.children![index]
        }
        
        return self.nodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? SidebarNode, node.children != nil {
            return node.children!.count > 0
        }
        
        return false
    }
        
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        if let node = item as? SidebarNode {
            return node.isGroup
        }
        
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if let node = item as? SidebarNode {
            return node.isSelectable
        }

        return false
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let delegate = self.delegate else {
            return
        }
        
        let row = self.outlineView.selectedRow
        if let node = self.outlineView.item(atRow: row) as? SidebarNode {
            delegate.sidebar(self, didSelectNode: node)
        }
    }
}
