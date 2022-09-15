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
    var toolTip: String? { get }
}

extension SidebarNode {
    var cellIdentifier: NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(rawValue: isGroup ? "HeaderCell" : "DataCell")
    }
}

protocol DeviceSidebarViewControllerDelegate: AnyObject {
    func sidebar(_ sidebar: DeviceSidebarViewController, didSelectNode node: SidebarNode)
}

class DeviceSidebarViewController: NSViewController {
    @IBOutlet var outlineView: NSOutlineView!

    weak var delegate: DeviceSidebarViewControllerDelegate?
    var nodes: [SidebarNode] = [] {
        didSet {
            outlineView.reloadData()
            outlineView.expandItem(nil, expandChildren: true)
        }
    }

    var selectedNode: SidebarNode? {
        get {
            let row = self.outlineView.selectedRow
            return self.outlineView.item(atRow: row) as? SidebarNode
        }
        set {
            let index = self.outlineView.row(forItem: newValue)
            let indexSet = IndexSet(integer: index)
            self.outlineView.selectRowIndexes(indexSet, byExtendingSelection: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.dataSource = self
        outlineView.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        outlineView.expandItem(nil, expandChildren: true)
    }
}

extension DeviceSidebarViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode,
              let cell = outlineView.makeView(withIdentifier: node.cellIdentifier, owner: self) as? NSTableCellView
        else {
            return nil
        }

        cell.textField?.stringValue = node.title
        cell.imageView?.image = node.image
        cell.toolTip = node.toolTip

        return cell
    }
}

extension DeviceSidebarViewController: NSOutlineViewDataSource {
    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? SidebarNode {
            return node.children?.count ?? 0
        }

        return nodes.count
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? SidebarNode, node.children != nil {
            return node.children![index]
        }

        return nodes[index]
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? SidebarNode, node.children != nil {
            return node.children!.count > 0
        }

        return false
    }

    func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
        if let node = item as? SidebarNode {
            return node.isGroup
        }

        return false
    }

    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if let node = item as? SidebarNode {
            return node.isSelectable
        }

        return false
    }

    func outlineViewSelectionDidChange(_: Notification) {
        guard let delegate = delegate else {
            return
        }

        let row = outlineView.selectedRow
        if let node = outlineView.item(atRow: row) as? SidebarNode {
            delegate.sidebar(self, didSelectNode: node)
        }
    }
}
