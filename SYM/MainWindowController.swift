// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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


enum ViewMode: Int {
    case text = 0    // NSOffState
    case thread = 1  // NSOnState
}

class MainWindowController: NSWindowController {

    // Toolbar buttons
    @IBOutlet weak var sidebarButton: NSButton!
    @IBOutlet weak var viewModeButton: NSButton!
    @IBOutlet weak var symButton: NSButton!
    @IBOutlet weak var infoButton: NSButton!
    @IBOutlet weak var indicator: NSProgressIndicator!

    var popover: NSPopover?
    
    var viewMode: ViewMode {
        get {
            return ViewMode(rawValue: self.viewModeButton.state)!
        }
        set {
            self.viewModeButton.state = newValue.rawValue
        }
    }
    
    var currentCrashFile: CrashFile?
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    fileprivate func sendNotification(_ name: Notification.Name) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: self)
        }
    }
}


// MARK: - Crash

extension MainWindowController {
    func openCrash(file: CrashFile) {
        self.currentCrashFile = file
        self.sendNotification(.openCrashReport)
        self.autoSymbolicate()
    }
    
    func autoSymbolicate() {
        if NSUserDefaultsController.shared().defaults.bool(forKey: "autoSymbolicate") {
            DispatchQueue.global().async {
                self.symbolicate(nil)
            }
        }
    }
    
    func updateCrash(_ newContent: String) {
        let document = self.document as! CrashDocument
        
        if self.currentCrashFile == nil {
            self.currentCrashFile = document.crashFile
        }
        
        document.update(crashFile: self.currentCrashFile, newContent: newContent) { [weak self] (crash) -> (Void) in
            self?.window?.isDocumentEdited = true
            self?.sendNotification(.crashUpdated)
            self?.autoSymbolicate()
        }
    }
    
    @IBAction func symbolicate(_ sender: AnyObject?) {
        if let crash = self.currentCrashFile?.crash {
            self.indicator.startAnimation(nil)
            
            crash.symbolicate(completion: { [weak self] (crash) in
                DispatchQueue.main.async {
                    self?.indicator.stopAnimation(nil)
                    self?.sendNotification(.crashSymbolicated)
                }
            })
        }
    }
}


// MARK: - UI control

extension MainWindowController {
    @IBAction func toggleFileList(_ sender: AnyObject?) {
        self.sendNotification(.toggleFileList)
    }
    
    @IBAction func swtichViewMode(_ sender: AnyObject?) {
        self.sendNotification(.switchViewMode)
    }
    
    // MARK: dSYM
    @IBAction func importDsymFile(_ sender: AnyObject?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: self.window!) {
            (result) in
            if result != NSFileHandlingPanelOKButton {
                return
            }
            
            if panel.urls.count == 0 {
                return
            }
            
            let url = panel.urls[0]
            
            DsymManager.sharedInstance.importDsym(fromURL: url, completion: { (uuids, success) in
                if uuids == nil {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "Cancel")
                    alert.messageText = "This is not a dSYM file"
                    alert.informativeText = url.path
                    alert.beginSheetModal(for: self.window!, completionHandler: nil)
                    return
                }
                
                if (success) {
                    // NSNotificationCenter.defaultCenter().postNotificationName(DidImportDsymNotification, object: uuids)
                }
            })
        }
    }
    
    @IBAction func togglePopover(sender: AnyObject?) {
        guard let crash = self.currentCrashFile?.crash,
              let button = sender as? NSButton
        else {
            return
        }
        
        if self.popover == nil {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let infoVC = storyboard.instantiateController(withIdentifier: "Crash Info ViewController") as! CrashInfoViewController
            infoVC.crash = crash
            self.popover = NSPopover()
            self.popover!.behavior = .transient
            self.popover!.contentViewController = infoVC
        }
        
        if self.popover!.isShown {
            self.popover!.close()
        } else {
            self.popover!.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
    
    func openCrash(_ file: CrashFile) {
        self.windowController()?.currentCrashFile = file
    }
    
    func currentCrashFile() -> CrashFile? {
        return self.windowController()?.currentCrashFile
    }
}
