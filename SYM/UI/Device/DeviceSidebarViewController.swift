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
            selectFirstLeafIfNeeded()
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
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.floatsGroupRows = true
        outlineView.allowsEmptySelection = false
        outlineView.allowsMultipleSelection = false
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.backgroundColor = .clear

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        outlineView.expandItem(nil, expandChildren: true)
    }

    func selectFirstLeafIfNeeded() {
        guard outlineView.selectedRow < 0 else { return }
        guard let leaf = firstSelectableLeaf(in: nodes) else { return }
        let row = outlineView.row(forItem: leaf)
        guard row >= 0 else { return }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    private func firstSelectableLeaf(in nodes: [SidebarNode]) -> SidebarNode? {
        for node in nodes {
            if node.isSelectable, !(node.isGroup) {
                return node
            }
            if let children = node.children,
               let found = firstSelectableLeaf(in: children) {
                return found
            }
        }
        return nil
    }

    private func makeCell(for node: SidebarNode) -> NSTableCellView {
        let cell = NSTableCellView()
        let imageView = NSImageView()
        let textField = NSTextField(labelWithString: node.title)
        textField.lineBreakMode = .byTruncatingTail
        textField.font = node.isGroup
            ? .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
            : .systemFont(ofSize: NSFont.systemFontSize)
        cell.addSubview(imageView)
        cell.addSubview(textField)
        cell.imageView = imageView
        cell.textField = textField
        imageView.image = node.image
        imageView.contentTintColor = .secondaryLabelColor
        textField.stringValue = node.title
        cell.toolTip = node.toolTip

        if node.isGroup {
            imageView.isHidden = true
            textField.textColor = .secondaryLabelColor
            textField.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(2)
                make.trailing.equalToSuperview().offset(-4)
                make.centerY.equalToSuperview()
            }
        } else {
            imageView.isHidden = false
            textField.textColor = .labelColor
            imageView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(2)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(18)
            }
            textField.snp.makeConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(6)
                make.trailing.equalToSuperview().offset(-4)
                make.centerY.equalToSuperview()
            }
        }
        return cell
    }
}

extension DeviceSidebarViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        let identifier = NSUserInterfaceItemIdentifier(node.isGroup ? "HeaderCell" : "DataCell")
        if let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell.imageView?.image = node.image
            cell.imageView?.isHidden = node.isGroup
            cell.textField?.stringValue = node.title
            cell.textField?.textColor = node.isGroup ? .secondaryLabelColor : .labelColor
            cell.toolTip = node.toolTip
            return cell
        }
        let cell = makeCell(for: node)
        cell.identifier = identifier
        return cell
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
}
