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

extension NSImage {
    static let alert: NSImage = #imageLiteral(resourceName: "alert")
    static let symbol: NSImage = #imageLiteral(resourceName: "symbol")
}

class MainWindowController: NSWindowController {
    // Toolbar items
    @IBOutlet var symButton: NSButton!

    @IBOutlet var downloadItem: DownloadToolbarItem!
    @IBOutlet var deviceItem: NSToolbarItem!
    @IBOutlet var indicator: NSProgressIndicator!
    @IBOutlet var dsymPopUpButton: DsymToolBarButton!

    var isSymbolicating: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.isSymbolicating {
                    self.indicator.startAnimation(nil)
                    self.indicator.isHidden = false
                } else {
                    self.indicator.stopAnimation(nil)
                    self.indicator.isHidden = true
                }
            }
        }
    }

    private var crashCancellable = Set<AnyCancellable>()

    // Dsym
    private var dsymManager = DsymManager()
    private weak var dsymViewController: DsymViewController?

    private var downloaderCancellable: AnyCancellable?
    private var downloadTask: DsymDownloadTask?
    private weak var downloadStatusViewController: DownloadStatusViewController?

    // Crash
    var crashContentViewController: ContentViewController! {
        if let vc = contentViewController as? ContentViewController {
            return vc
        }
        return nil
    }

    var crashDocument: CrashDocument? {
        return self.document as? CrashDocument
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        windowFrameAutosaveName = "MainWindow"
        deviceItem.isEnabled = MDDeviceMonitor.shared().deviceConnected
        dsymPopUpButton.dsymManager = dsymManager

        NotificationCenter.default.addObserver(self, selector: #selector(updateDeviceButton(_:)), name: NSNotification.Name.MDDeviceMonitor, object: nil)

        downloaderCancellable = DsymDownloader.shared.$tasks
            .receive(on: DispatchQueue.main)
            .map { [weak self] tasks -> DsymDownloadTask? in
                if let uuid = self?.crashDocument?.crashInfo?.uuid {
                    return tasks[uuid]
                }
                return nil
            }.sink { [weak self] task in
                self?.bind(task: task)
            }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var document: AnyObject? {
        didSet {
            crashCancellable.forEach { cancellable in
                cancellable.cancel()
            }

            guard let document = document as? CrashDocument else {
                crashContentViewController.document = nil
                return
            }
            crashContentViewController.document = document

            document.$crashInfo
                .receive(on: DispatchQueue.main)
                .sink { [weak self] crashInfo in
                    if let crash = crashInfo {
                        self?.dsymManager.update(crash)
                    }
                }
                .store(in: &crashCancellable)

            document.$isSymbolicating
                .receive(on: DispatchQueue.main)
                .assign(to: \.isSymbolicating, on: self)
                .store(in: &crashCancellable)
        }
    }

    // MARK: Notifications

    @objc func updateDeviceButton(_: Notification) {
        deviceItem.isEnabled = MDDeviceMonitor.shared().deviceConnected
    }

    @objc func crashDidSymbolicated(_: Notification) {
        isSymbolicating = false
    }

    // MARK: IBActions

    @IBAction func symbolicate(_: AnyObject?) {
        let content = crashDocument?.textStorage.string ?? ""
        if content.strip().isEmpty {
            return
        }

        isSymbolicating = true
        let dsyms = dsymManager.dsymFiles.values.compactMap { $0.binaryPath }
        crashDocument?.symbolicate(withDsymPaths: dsyms)
    }

    @IBAction func showDsymInfo(_: Any) {
        guard dsymManager.crash != nil else {
            return
        }
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Dsym"), bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: "DsymViewController") as! DsymViewController
        vc.dsymManager = dsymManager
        vc.bind(task: downloadTask)
        dsymViewController = vc
        contentViewController?.presentAsSheet(vc)
    }

    @IBAction func downloadDsym(_: AnyObject?) {
        startDownloading()
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let vc = segue.destinationController as? DownloadStatusViewController {
            vc.delegate = self
            downloadStatusViewController = vc
        }
    }
}

extension MainWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        return item.isEnabled
    }
}

extension MainWindowController: DownloadStatusViewControllerDelegate {
    func bind(task: DsymDownloadTask?) {
        downloadTask = task
        downloadStatusViewController?.bind(task: task)
        downloadItem.bind(task: task)
        dsymViewController?.bind(task: task)
        if let files = task?.dsymFiles {
            dsymManager.dsymFileDidUpdate(files)
        }
    }

    func startDownloading() {
        if let crash = dsymManager.crash {
            DsymDownloader.shared.download(crashInfo: crash, fileURL: nil)
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    func currentDownloadTask() -> DsymDownloadTask? {
        return downloadTask
    }
}
