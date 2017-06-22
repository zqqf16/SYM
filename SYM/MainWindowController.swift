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
    @IBOutlet weak var dSYMButton: NSPopUpButton!
    @IBOutlet weak var dSYMMenu: NSMenuItem!
    
    private var dSYM: DsymFile? {
        didSet {
            DispatchQueue.main.async {
                let item = self.dSYMButton.item(at: 0)!
                if self.dSYM == nil {
                    item.title = ".dSYM file not found"
                    item.image = NSImage(named: .alert)
                } else {
                    item.title = self.dSYM!.name
                    item.image = NSImage(named: .symbol)
                }
                self.dSYMButton.selectItem(at: 0)
            }
        }
    }
    
    var crashContent: String? {
        return (self.document as? CrashDocument)?.content
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.setupDsymMenu()
        DsymManager.shared.updateDsymList()
        NotificationCenter.default.addObserver(self, selector: #selector(dsymListDidUpdate), name: .dsymListUpdated, object: nil)
    }
    
    @objc func dsymListDidUpdate(notification: Notification) {
        self.setupDsymMenu()
        self.findCurrentDsym()
    }
    
    func findCurrentDsym(_ updateIfNotFound: Bool = false) {
        guard let content = self.crashContent,
            let crash = parseCrash(fromContent: content),
            let image = crash.binaryImage(),
            let uuid = image.uuid
            else {
                return
        }
        
        self.dSYM = DsymManager.shared.findDsymFile(uuid)
        if updateIfNotFound && self.dSYM == nil {
            DsymManager.shared.updateDsymList()
        }
        DispatchQueue.main.async {
            if self.dSYM != nil {
                self.dSYMMenu.isEnabled = false
            } else {
                self.dSYMMenu.isEnabled = true
            }
        }
    }
    
    func setupDsymMenu() {
        let dsymList = DsymManager.shared.dsymList.values
        let unique = Set<DsymFile>(dsymList)
        self.dSYMMenu.submenu!.removeAllItems()

        for file in unique {
            let item = NSMenuItem(title: file.name, action: #selector(self.didSelectDsymFile), keyEquivalent: "")
            item.toolTip = file.displayedPath
            item.representedObject = file
            if file.name == self.dSYM?.name {
                item.state = .on
            }
            self.dSYMMenu.submenu!.addItem(item)
        }
    }
    
    @objc func didSelectDsymFile(_ sender: AnyObject?) {
        if let item = sender as? NSMenuItem, let file = item.representedObject as? DsymFile {
            self.dSYM = file
            item.state = .on
            for menuItem in self.dSYMMenu.submenu!.items {
                if menuItem != item {
                    menuItem.state = .off
                }
            }
        }
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
        self.findCurrentDsym(true)
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
    }
    
    @IBAction func symbolicate(_ sender: AnyObject?) {
        if let content = self.crashContent, let crash = parseCrash(fromContent: content) {
            self.indicator.startAnimation(nil)
            DispatchQueue.global().async {
                let new = SYM.symbolicate(crash: crash, dSYM: self.dSYM?.path)
                DispatchQueue.main.async { [weak self] in
                    self?.indicator.stopAnimation(nil)
                    self?.updateCrash(new)
                    self?.sendNotification(.crashSymbolicated)
                }
            }
        }
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
