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

extension NSImage {
    static let alert: NSImage = #imageLiteral(resourceName: "alert")
    static let symbol: NSImage = #imageLiteral(resourceName: "symbol")
}

class MainWindowController: NSWindowController {
    // Toolbar items
    @IBOutlet weak var symButton: NSButton!
    
    @IBOutlet weak var deviceItem: NSToolbarItem!
    @IBOutlet weak var indicator: NSProgressIndicator!
    @IBOutlet weak var statusBar: DsymStatusBarItem!
    @IBOutlet weak var dsymPopUpButton: DsymToolBarButton!
    
    var isSymbolicating: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if (self.isSymbolicating) {
                    self.indicator.startAnimation(nil)
                    self.indicator.isHidden = false
                } else {
                    self.indicator.stopAnimation(nil)
                    self.indicator.isHidden = true
                }
            }
        }
    }
    
    // Dsym
    private var dsymManager = DsymManager()
    private var downloader = DsymDownloader()
    private var downloadTask: DsymDownloadTask?

    // Crash
    var crashContentViewController: ContentViewController! {
        if let vc = self.contentViewController as? ContentViewController {
            return vc
        }
        return nil
    }
    
    var crashDocument: CrashDocument? {
        return self.document as? CrashDocument
    }
    
    var crashInfo: CrashInfo? {
        return self.crashDocument?.crashInfo
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.windowFrameAutosaveName = "MainWindow"
        self.deviceItem.isEnabled = MDDeviceMonitor.shared().deviceConnected
        self.statusBar.dsymManager = self.dsymManager
        self.dsymPopUpButton.dsymManager = self.dsymManager

        NotificationCenter.default.addObserver(self, selector: #selector(updateDeviceButton(_:)), name: NSNotification.Name.MDDeviceMonitor, object: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.dsymManager.stop()
        if let document = self.crashDocument {
            document.notificationCenter.removeObserver(self)
        }
    }
    
    override var document: AnyObject? {
        didSet {
            guard let document = document as? CrashDocument else {
                return
            }
            self.crashContentViewController.document = document
            document.notificationCenter.addObserver(self, selector: #selector(updateCrashInfo(_:)), name: .crashInfoUpdated, object: nil)
            document.notificationCenter.addObserver(self, selector: #selector(crashDidSymbolicated(_:)), name: .crashSymbolicated, object: nil)
            self.updateCrashInfo(nil)
        }
    }
    
    // MARK: Notifications
    @objc func updateCrashInfo(_ notification: Notification?) {
        if let crash = self.crashInfo {
            self.dsymManager.update(crash)
        }
    }
    
    @objc func updateDeviceButton(_ notification: Notification) {
        self.deviceItem.isEnabled = MDDeviceMonitor.shared().deviceConnected
    }
    
    @objc func crashDidSymbolicated(_ notification: Notification) {
        self.isSymbolicating = false
    }

    // MARK: IBActions
    @IBAction func symbolicate(_ sender: AnyObject?) {
        let content = self.crashDocument?.textStorage.string ?? ""
        if content.strip().isEmpty {
            return
        }
        
        self.isSymbolicating = true
        let dsyms = self.dsymManager.dsymFiles.values.compactMap {$0.binaryPath}
        self.crashDocument?.symbolicate(withDsymPaths: dsyms)
    }

    @IBAction func showDsymInfo(_ sender: Any) {
        guard self.dsymManager.crash != nil else {
            return
        }
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Dsym"), bundle: nil)
        let vc = storyboard.instantiateController(withIdentifier: "DsymViewController") as! DsymViewController
        vc.dsymManager = self.dsymManager
        self.contentViewController?.presentAsSheet(vc)
    }
    
    @IBAction func downloadDsym(_ sender: AnyObject?) {
        if let crash = self.dsymManager.crash {
            DsymDownloader.shared.download(crashInfo: crash, fileURL: nil)
        }
    }
}

extension MainWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        return item.isEnabled
    }
}
