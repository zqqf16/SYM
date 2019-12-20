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

protocol DsymTableCellViewDelegate: class {
    func didClickSelectButton(_ cell: DsymTableCellView, sender: NSButton)
    func didClickRevealButton(_ cell: DsymTableCellView, sender: NSButton)
}

class DsymTableCellView: NSTableCellView {
    @IBOutlet weak var image: NSImageView!
    @IBOutlet weak var title: NSTextField!
    @IBOutlet weak var uuid: NSTextField!
    @IBOutlet weak var path: NSTextField!
    @IBOutlet weak var actionButton: NSButton!
    
    weak var delegate: DsymTableCellViewDelegate?
    
    var binary: Binary!
    var dsym: DsymFile?
    
    func updateUI() {
        self.title.stringValue = self.binary.name
        self.uuid.stringValue = self.binary.uuid ?? ""
        if let path = self.dsym?.path {
            self.path.stringValue = path
            self.actionButton.title = NSLocalizedString("Reveal", comment: "Reveal in Finder")
        } else {
            self.path.stringValue = NSLocalizedString("dsym_file_not_found", comment: "Dsym file not found")
            self.actionButton.title = NSLocalizedString("Select", comment: "Select a dSYM file")
        }
    }
    
    @IBAction func didClickActionButton(_ sender: NSButton) {
        if self.dsym?.path != nil {
            self.delegate?.didClickRevealButton(self, sender: sender)
        } else {
            self.delegate?.didClickSelectButton(self, sender: sender)
        }
    }
}

class DsymViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    @IBOutlet weak var downloadButton: NSButton!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
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
    
    private func dsymFile(forBinary binary: Binary) -> DsymFile? {
        if let uuid = binary.uuid {
            return self.dsymManager?.dsymFile(withUuid: uuid)
        }
        return nil
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateViewHeight()
        self.downloadButton.isEnabled = self.dsymManager?.crash != nil
        let eventBus = DsymDownloader.shared.eventBus
        eventBus.sub(self, for: DsymDownloadStatusEvent.self).async { (event) in
            self.updateDownloadStatus(event.task)
        }
        eventBus.sub(self, for: DsymDownloadProgressEvent.self).async { (event) in
            self.updateDownloadStatus(event.task)
        }
    }
    
    @objc func dsymDidUpdated(_ notification: Notification?) {
        self.tableView.reloadData()
    }
    
    //MARK: UI
    private func updateViewHeight() {
        self.tableViewHeight.constant = min(CGFloat(70 * self.binaries.count), 520.0)
    }
    
    @IBAction func didClickDownloadButton(_ sender: NSButton) {
        if let crashInfo = self.dsymManager?.crash {
            DsymDownloader.shared.download(crashInfo: crashInfo, fileURL: nil)
        }
    }
}

extension DsymViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.binaries.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cell"), owner: nil) as? DsymTableCellView
        cell?.delegate = self
        let binary = self.binaries[row]
        cell?.binary = binary
        cell?.dsym = self.dsymFile(forBinary: binary)
        cell?.updateUI()
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}

extension DsymViewController: DsymTableCellViewDelegate {
    func didClickSelectButton(_ cell: DsymTableCellView, sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { [weak openPanel] (result) in
            guard result == .OK, let url = openPanel?.url else {
                return
            }
            self.dsymManager?.assign(cell.binary!, dsymFileURL: url)
        }
    }

    func didClickRevealButton(_ cell: DsymTableCellView, sender: NSButton) {
        if let path = cell.dsym?.path {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

extension DsymViewController {
    private func updateDownloadStatus(_ task: DsymDownloadTask) {
        guard let uuid = self.dsymManager?.crash?.uuid, uuid == task.crashInfo.uuid else {
            self.downloadButton.isEnabled = self.dsymManager?.crash != nil
            self.progressBar.isHidden = true
            return
        }

        let progress = task.progress.percentage
        let status = task.status
        switch status {
        case .running:
            self.downloadButton.isEnabled = false
            self.progressBar.isHidden = false
            if progress > 0 {
                self.progressBar.doubleValue = Double(progress)
                self.progressBar.isIndeterminate = false
            } else {
                self.progressBar.isIndeterminate = true
                self.progressBar.startAnimation(nil)
            }
        case .canceled:
            self.progressBar.isHidden = true
            self.downloadButton.isEnabled = true
        case .failed(_, _):
            self.progressBar.isHidden = true
            self.downloadButton.isEnabled = true
        case .success:
            self.progressBar.isHidden = true
        case .waiting:
            self.progressBar.isHidden = false
            self.progressBar.isIndeterminate = true
            self.progressBar.startAnimation(nil)
            self.downloadButton.isEnabled = false
        }
    }
}
