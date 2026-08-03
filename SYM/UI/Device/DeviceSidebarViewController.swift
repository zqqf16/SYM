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
import SnapKit

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
        NSUserInterfaceItemIdentifier(rawValue: isGroup ? "HeaderCell" : "DataCell")
    }
}

protocol DeviceSidebarViewControllerDelegate: AnyObject {
    func sidebar(_ sidebar: DeviceSidebarViewController, didSelectNode node: SidebarNode)
}

class DeviceSidebarViewController: NSViewController {
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()

    weak var delegate: DeviceSidebarViewControllerDelegate?
    var nodes: [SidebarNode] = [] {
        didSet {
            outlineView.reloadData()
            outlineView.expandItem(nil, expandChildren: true)
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.title = ""
        outlineView.addTableColumn(column)
        outlineView.headerView = nil
        outlineView.outlineTableColumn = column
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowSizeStyle = .medium

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        outlineView.expandItem(nil, expandChildren: true)
    }

    private func makeCell(for node: SidebarNode) -> NSTableCellView {
        let cell = NSTableCellView()
        let imageView = NSImageView()
        let textField = NSTextField(labelWithString: node.title)
        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField
        imageView.image = node.image
        textField.stringValue = node.title
        cell.toolTip = node.toolTip
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        textField.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
        }
        return cell
    }
}

extension DeviceSidebarViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        let identifier = node.cellIdentifier
        if let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell.imageView?.image = node.image
            cell.textField?.stringValue = node.title
            cell.toolTip = node.toolTip
            return cell
        }
        let cell = makeCell(for: node)
        cell.identifier = identifier
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
        if let node = item as? SidebarNode, let children = node.children {
            return children[index]
        }
        return nodes[index]
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? SidebarNode {
            return (node.children?.count ?? 0) > 0
        }
        return false
    }

    func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? SidebarNode)?.isGroup ?? false
    }

    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? SidebarNode)?.isSelectable ?? false
    }

    func outlineViewSelectionDidChange(_: Notification) {
        let row = outlineView.selectedRow
        if let node = outlineView.item(atRow: row) as? SidebarNode {
            delegate?.sidebar(self, didSelectNode: node)
        }
    }
}
