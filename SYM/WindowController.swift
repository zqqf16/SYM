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


let SidebarNotification = "SidebarNotification"
let DidImportDsymNotification = "DidImportDsymNotification"
let DoSymbolicateNotification = "DoSymbolicateNotification"


enum CloseCrashType {
    case Close
    case Open
    case Import
}

protocol CrashRepresenter: class {
    func isCrashChanged() -> Bool
    func currentCrash() -> Crash?
}


class WindowController: NSWindowController {
    
    @IBOutlet weak var navButtons: NSSegmentedControl!
    
    weak var crashRepresenter: CrashRepresenter?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.center()
    }
    
    
    // MARK: - Sidebar
    
    var sidebarCollapsed: Bool {
        get {
            return !self.navButtons.isSelectedForSegment(0)
        }
        set {
            self.navButtons.setSelected(!newValue, forSegment: 0)
        }
    }
    
    var bottomBarCollapsed: Bool {
        get {
            return !self.navButtons.isSelectedForSegment(1)
        }
        set {
            self.navButtons.setSelected(!newValue, forSegment: 1)
        }
    }

    @IBAction func didClickNavigatorButton(sender: NSSegmentedControl) {
        let clickedSegment = sender.selectedSegment        
        NSNotificationCenter.defaultCenter().postNotificationName(SidebarNotification, object: clickedSegment)
    }

    @IBAction func showBottomBar(sender: AnyObject?) {
        self.bottomBarCollapsed = false
        NSNotificationCenter.defaultCenter().postNotificationName(SidebarNotification, object: 1)
    }
    
    
    // MARK: - dSYM
    
    @IBAction func choosedSYMFile(sender: AnyObject?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModalForWindow(self.window!) {
            (result) in
            if result != NSFileHandlingPanelOKButton {
                return
            }
            
            if panel.URLs.count == 0 {
                return
            }
            
            let url = panel.URLs[0]
            
            DsymManager.sharedInstance.importDsym(fromURL: url, completion: { (uuids, success) in
                if uuids == nil {
                    let alert = NSAlert()
                    alert.addButtonWithTitle("OK")
                    alert.addButtonWithTitle("Cancel")
                    alert.messageText = "This is not a dSYM file"
                    alert.informativeText = url.path!
                    alert.beginSheetModalForWindow(self.window!, completionHandler: nil)
                    return
                }
                
                if (success) {
                    NSNotificationCenter.defaultCenter().postNotificationName(DidImportDsymNotification, object: uuids)
                }
            })
        }
    }
    

    // MARK: - Documents

    func saveCurrentDocument() -> Bool {
        if let crashRepresenter = self.crashRepresenter {
            let cm = CrashManager.sharedInstance
            let changed = crashRepresenter.isCrashChanged()
            if let crash = crashRepresenter.currentCrash() {
                if crash.filePath == nil {
                    if changed {
                        // Crash changed, and it is not opened from file.
                        // Create a new Crash item.
                        cm.new(crash)
                        return true
                    }
                    return false
                }
            }
        }
        return true
    }

    @IBAction func openDocument(sender: AnyObject?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModalForWindow(self.window!) {
            (result) in
            
            if result != NSFileHandlingPanelOKButton {
                return
            }
            
            if panel.URLs.count == 0 {
                return
            }
            
            let cm = CrashManager.sharedInstance
            if cm.crashes.count == 0 {
                self.saveCurrentDocument()
            }
            
            let urls = [panel.URLs[0].path!]
            cm.open(urls)
            
            NSDocumentController.sharedDocumentController().noteNewRecentDocumentURL(panel.URLs[0])
        }
    }
    
    @IBAction func newDocument(sender: AnyObject?) {
        if self.saveCurrentDocument() {
            CrashManager.sharedInstance.new()
        }
    }
    
    @IBAction func performClose(sender: AnyObject?) {
        self.window?.close()
    }
    
    // MARK: Symbolicate
    @IBAction func doSymbolic(sender: AnyObject) {
        NSNotificationCenter.defaultCenter().postNotificationName(DoSymbolicateNotification, object: nil)
    }
}
