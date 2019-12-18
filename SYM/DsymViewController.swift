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

class DsymTableCellView: NSTableCellView {
    @IBOutlet weak var image: NSImageView!
    @IBOutlet weak var title: NSTextField!
    @IBOutlet weak var uuid: NSTextField!
    @IBOutlet weak var path: NSTextField!
    @IBOutlet weak var actionButton: NSButton!
    
    var binary: Binary!
    var dsymManager: DsymManager?
    var dsym: DsymFile? {
        if let uuid = self.binary.uuid {
            return self.dsymManager?.dsymFile(withUuid: uuid)
        }
        return nil
    }
    
    func updateUI(binary: Binary, dsymManager: DsymManager?) {
        self.binary = binary
        self.dsymManager = dsymManager

        self.title.stringValue = self.binary.name
        self.uuid.stringValue = self.binary.uuid ?? ""
        if let path = self.dsym?.path {
            self.path.stringValue = path
            self.actionButton.title = NSLocalizedString("Reveal", comment: "Reveal in Finder")
        } else {
            self.path.stringValue = ""
            self.actionButton.title = NSLocalizedString("Select", comment: "Select a dSYM file")
        }
    }
    
    @IBAction func didClickActionButton(_ sender: NSButton) {
        guard let path = self.dsym?.path else {
            // select
            self.chooseDsymFile(self)
            return
        }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    func chooseDsymFile(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { (result) in
            //
        }
        
        /*
        openPanel.beginSheetModal(for: self.window!) { [weak openPanel] (result) in
            guard result == .OK, let url = openPanel?.url else {
                return
            }
            
            let path = url.path
            let name = url.lastPathComponent
            //let uuid = self.crashInfo?.uuid ?? ""
            //self.dsymFiles = [DsymFile(name: name, path: path, binaryPath: path, uuids: [uuid])]
        }
 */
    }
}

class DsymViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    
    private var binaries: [Binary] = [] {
        didSet {
            self.reloadData()
        }
    }
    
    var dsymManager: DsymManager? {
        didSet {
            self.binaries = self.dsymManager?.binaries ?? []
            self.dsymManager?.nc.addObserver(self, selector: #selector(dsymDidUpdated(_:)), name: .dsymDidUpdate, object: nil)
        }
    }

    private func reloadData() {
        guard self.tableView != nil else {
            return
        }
        
        self.tableView.reloadData()
        self.updateViewHeight()
    }
    
    private func updateViewHeight() {
        self.tableViewHeight.constant = CGFloat(70 * self.binaries.count)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateViewHeight()
    }
    
    @objc func dsymDidUpdated(_ notification: Notification?) {
        self.tableView.reloadData()
    }
}

extension DsymViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.binaries.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cell"), owner: nil) as? DsymTableCellView
        cell?.updateUI(binary: self.binaries[row], dsymManager: self.dsymManager!)
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}
