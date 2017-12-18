// The MIT License (MIT)
//
// Copyright (c) 2017 zqqf16
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

extension NSImage.Name {
    static let alert = NSImage.Name(rawValue: "alert")
    static let symbol = NSImage.Name(rawValue: "symbol")
}

class MainWindowController: NSWindowController {
    // Toolbar buttons
    @IBOutlet weak var symButton: NSButton!
    @IBOutlet weak var indicator: NSProgressIndicator!
    @IBOutlet weak var dsymButton: NSButton!
    @IBOutlet weak var deviceLabel: NSTextField!
    
    private var dsym: Dsym? {
        didSet {
            DispatchQueue.main.async {
                if self.dsym == nil {
                    self.dsymButton.title = "Select a dSYM file"
                    self.dsymButton.image = NSImage(named: .alert)
                } else {
                    self.dsymButton.title = self.dsym!.name
                    self.dsymButton.image = NSImage(named: .symbol)
                }
            }
        }
    }
    
    var crashContent: String? {
        return (self.document as? CrashDocument)?.content
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.dsym = nil;
        DsymManager.shared.updateDsymList(nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dsymListDidUpdate), name: .dsymListUpdated, object: nil)
    }
    
    @objc func dsymListDidUpdate(notification: Notification) {
        if self.dsym == nil {
            self.findCurrentDsym()
        }
    }
    
    func findCurrentDsym() {
        guard let content = self.crashContent,
            let crash = Crash.parse(fromContent: content),
            let image = crash.binaryImage(),
            let uuid = image.uuid
        else {
            return
        }
        
        self.dsym = DsymManager.shared.dsym(withUUID: uuid)
    }
    
    func parseDevice() {
        guard let content = self.crashContent,
              let crash = Crash.parse(fromContent: content),
              let device = crash.device
        else {
            self.deviceLabel.stringValue = ""
            self.deviceLabel.isHidden = true
            return
        }
        
        self.deviceLabel.stringValue = modelToName(device)
        self.deviceLabel.isHidden = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
    }
    
    fileprivate func sendNotification(_ name: Notification.Name) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: self)
        }
    }
}

// MARK: - Crash operation
extension MainWindowController {
    func open(crash: String) {
        self.sendNotification(.openCrashReport)
        self.findCurrentDsym()
        self.parseDevice()
    }
    
    func autoSymbolicate() {
        if NSUserDefaultsController.shared.defaults.bool(forKey: "autoSymbolicate") {
            self.symbolicate(nil)
        }
    }
    
    func updateCrash(_ newContent: String) {
        let document = self.document as! CrashDocument
        document.content = newContent
        self.window?.isDocumentEdited = (self.crashContent != newContent)
        self.sendNotification(.crashUpdated)
        self.findCurrentDsym()
        self.parseDevice()
    }
    
    @IBAction func symbolicate(_ sender: AnyObject?) {
        if let content = self.crashContent, let crash = Crash.parse(fromContent: content) {
            self.indicator.startAnimation(nil)
            DispatchQueue.global().async {
                let new = SYM.symbolicate(crash: crash, dsym: self.dsym?.path)
                DispatchQueue.main.async { [weak self] in
                    self?.indicator.stopAnimation(nil)
                    self?.updateCrash(new)
                    self?.sendNotification(.crashSymbolicated)
                }
            }
        }
    }
}

extension MainWindowController: DsymListViewControllerDelegate {
    func didSelectDsym(_ dsym: Dsym) {
        self.dsym = dsym
    }
    
    @IBAction func showDsymList(_ sender: AnyObject?) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let viewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "DsymListViewController")) as! DsymListViewController
        viewController.delegate = self
        
        if let content = self.crashContent,
            let crash = Crash.parse(fromContent: content),
            let image = crash.binaryImage(),
            let uuid = image.uuid {
            viewController.uuid = uuid
        }
        
        self.window?.contentViewController?.presentViewControllerAsSheet(viewController)
    }
}

// MARK: - NSViewController extensions
extension NSViewController {
    func document() -> CrashDocument? {
        if let windowController = self.view.window?.windowController {
            return windowController.document as? CrashDocument
        }
        return nil
    }
    
    func window() -> BaseWindow? {
        return self.view.window as? BaseWindow
    }
    
    func windowController() -> MainWindowController? {
        return self.view.window?.windowController as? MainWindowController
    }
}
