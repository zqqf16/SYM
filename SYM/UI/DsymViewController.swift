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
import Combine

protocol DsymTableCellViewDelegate: AnyObject {
    func didClickSelectButton(_ cell: DsymTableCellView, sender: NSButton)
    func didClickRevealButton(_ cell: DsymTableCellView, sender: NSButton)
}

class DsymTableCellView: NSTableCellView {
    @IBOutlet var image: NSImageView!
    @IBOutlet var title: NSTextField!
    @IBOutlet var uuid: NSTextField!
    @IBOutlet var path: NSTextField!
    @IBOutlet var actionButton: NSButton!

    weak var delegate: DsymTableCellViewDelegate?

    var binary: Binary!
    var dsym: DsymFile?

    func updateUI() {
        title.stringValue = binary.name
        uuid.stringValue = binary.uuid ?? ""
        if let path = dsym?.path {
            self.path.stringValue = path
            actionButton.title = NSLocalizedString("Reveal", comment: "Reveal in Finder")
        } else {
            path.stringValue = NSLocalizedString("dsym_file_not_found", comment: "Dsym file not found")
            actionButton.title = NSLocalizedString("Import", comment: "Import a dSYM file")
        }
    }

    @IBAction func didClickActionButton(_ sender: NSButton) {
        if dsym?.path != nil {
            delegate?.didClickRevealButton(self, sender: sender)
        } else {
            delegate?.didClickSelectButton(self, sender: sender)
        }
    }
}

class DsymViewController: NSViewController {
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var tableViewHeight: NSLayoutConstraint!
    @IBOutlet var downloadButton: NSButton!
    @IBOutlet var progressBar: NSProgressIndicator!

    private var binaries: [Binary] = [] {
        didSet {
            reloadData()
        }
    }

    private var dsymFiles: [String: DsymFile] = [:] {
        didSet {
            reloadData()
        }
    }

    private var dsymStorage = Set<AnyCancellable>()
    private var taskCancellable: AnyCancellable?

    var dsymManager: DsymManager? {
        didSet {
            dsymStorage.forEach { cancellable in
                cancellable.cancel()
            }
            dsymManager?.$binaries
                .receive(on: DispatchQueue.main)
                .assign(to: \.binaries, on: self)
                .store(in: &dsymStorage)

            dsymManager?.$dsymFiles
                .receive(on: DispatchQueue.main)
                .assign(to: \.dsymFiles, on: self)
                .store(in: &dsymStorage)
        }
    }

    private func reloadData() {
        guard tableView != nil else {
            return
        }

        tableView.reloadData()
        updateViewHeight()
    }

    private func dsymFile(forBinary binary: Binary) -> DsymFile? {
        if let uuid = binary.uuid {
            return dsymManager?.dsymFile(withUuid: uuid)
        }
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateViewHeight()
        downloadButton.isEnabled = dsymManager?.crash != nil
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        taskCancellable?.cancel()
        dsymStorage.forEach { cancellable in
            cancellable.cancel()
        }
    }

    func bind(task: DsymDownloadTask?) {
        taskCancellable?.cancel()
        guard let downloadTask = task else {
            return
        }
        taskCancellable = Publishers
            .CombineLatest(downloadTask.$status, downloadTask.$progress)
            .receive(on: DispatchQueue.main)
            .sink { status, progress in
                self.update(status: status, progress: progress)
            }
    }

    // MARK: UI

    private func updateViewHeight() {
        tableViewHeight.constant = min(CGFloat(70 * binaries.count), 520.0)
    }

    @IBAction func didClickDownloadButton(_: NSButton) {
        if let crashInfo = dsymManager?.crash {
            DsymDownloader.shared.download(crashInfo: crashInfo, fileURL: nil)
        }
    }
}

extension DsymViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return binaries.count
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cell"), owner: nil) as? DsymTableCellView
        cell?.delegate = self
        let binary = binaries[row]
        cell?.binary = binary
        cell?.dsym = dsymFile(forBinary: binary)
        cell?.updateUI()
        return cell
    }

    func tableView(_: NSTableView, shouldSelectRow _: Int) -> Bool {
        return false
    }
}

extension DsymViewController: DsymTableCellViewDelegate {
    func didClickSelectButton(_ cell: DsymTableCellView, sender _: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true

        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let url = openPanel?.url else {
                return
            }
            self.dsymManager?.assign(cell.binary!, dsymFileURL: url)
        }
    }

    func didClickRevealButton(_ cell: DsymTableCellView, sender _: NSButton) {
        if let path = cell.dsym?.path {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

extension DsymViewController {
    func update(status: DsymDownloadTask.Status, progress: DsymDownloadTask.Progress) {
        switch status {
        case .running:
            downloadButton.isEnabled = false
            progressBar.isHidden = false
        case .canceled:
            progressBar.isHidden = true
            downloadButton.isEnabled = true
        case .failed:
            progressBar.isHidden = true
            downloadButton.isEnabled = true
        case .success:
            progressBar.isHidden = true
        case .waiting:
            progressBar.isHidden = false
            progressBar.isIndeterminate = true
            progressBar.startAnimation(nil)
            downloadButton.isEnabled = false
        }
        if progress.percentage == 0 {
            progressBar.isIndeterminate = true
        } else {
            progressBar.isIndeterminate = false
            progressBar.doubleValue = Double(progress.percentage)
        }
    }
}
