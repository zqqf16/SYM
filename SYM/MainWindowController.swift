// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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
    // Toolbar buttons
    @IBOutlet weak var symButton: NSButton!
    @IBOutlet weak var indicator: NSProgressIndicator!
    @IBOutlet weak var dsymButton: NSButton!
    @IBOutlet weak var deviceLabel: NSTextField!
    
    private var monitor = DsymFileMonitor()
    
    private var dsymFile: DsymFile? {
        didSet {
            DispatchQueue.main.async {
                if self.dsymFile == nil {
                    self.dsymButton.title = "dSYM file not found"
                    self.dsymButton.image = .alert
                } else {
                    self.dsymButton.title = self.dsymFile!.name
                    self.dsymButton.image = .symbol
                }
                self.dsymButton.setNeedsDisplay()
            }
        }
    }
    
    private var device: String? {
        didSet {
            DispatchQueue.main.async {
                if let device = self.device {
                    self.deviceLabel.stringValue = modelToName(device)
                    self.deviceLabel.isHidden = false
                } else {
                    self.deviceLabel.stringValue = ""
                    self.deviceLabel.isHidden = true
                }
            }
        }
    }
        
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
    }
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
        self.monitor.delegate = self
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.monitor.stop()
    }
    
    fileprivate func sendNotification(_ name: Notification.Name) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: self)
        }
    }
    
    override var document: AnyObject? {
        didSet {
            self.dsymFile = nil;
            guard let document = document as? CrashDocument else {
                return
            }
            self.crashContentViewController.document = document
            document.notificationCenter.addObserver(forName: .crashInfoUpdated, object: nil, queue: nil) { [weak self] (notification) in
                self?.updateCrashInfo()
            }
            document.notificationCenter.addObserver(forName: .crashSymbolicated, object: nil, queue: nil) {  [weak self] (notification) in
                self?.crashDidSymbolicated()
            }
            self.updateCrashInfo()
        }
    }
    
    func updateCrashInfo() {
        //self.device = self.crashInfo?.device
        self.findCurrentDsym()
    }
}

// MARK: - Symbolicate
extension MainWindowController {
    func autoSymbolicate() {
        if NSUserDefaultsController.shared.defaults.bool(forKey: "autoSymbolicate") {
            self.symbolicate(nil)
        }
    }
    
    @IBAction func symbolicate(_ sender: AnyObject?) {
        let content = self.crashDocument?.textStorage.string ?? ""
        if content.strip().isEmpty {
            return
        }
        self.indicator.startAnimation(nil)
        self.crashDocument?.symbolicate(withDsymPath: self.dsymFile?.binaryPath)
    }
    
    func crashDidSymbolicated() {
        self.indicator.stopAnimation(nil)
    }
}

// MARK: - dSYM
extension MainWindowController: DsymFileMonitorDelegate {
    func findCurrentDsym() {
        self.monitor.update(uuid: self.crashInfo?.uuid, bundleID: self.crashInfo?.bundleID)
    }
    
    @IBAction func locateDsym(_ sender: AnyObject?) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.begin { [weak openPanel] (result) in
            if result == .OK {
                if let url = openPanel?.url {
                    self.parseSelectResult(url)
                }
            }
        }
    }
    
    func parseSelectResult(_ url: URL) {
        let path = url.path
        let name = url.lastPathComponent
        let uuid = self.crashInfo?.uuid ?? ""
        self.dsymFile = DsymFile(name: name, path: path, binaryPath: path, uuids: [uuid])
    }

    func dsymFileMonitor(_ monitor: DsymFileMonitor, didFindDsymFile dsymFile: DsymFile) {
        self.dsymFile = dsymFile
    }
}
