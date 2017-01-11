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


extension NSViewController {
    func document() -> CrashDocument? {
        if let windowController = self.view.window?.windowController {
            return windowController.document as? CrashDocument
        }
        return nil
    }
    
    func window() -> MainWindow? {
        return self.view.window as? MainWindow
    }
    
    func windowController() -> MainWindowController? {
        return self.view.window?.windowController as? MainWindowController
    }
    
    func updateNavigationState(_ index: Int) {
        self.windowController()?.updateNavigationState(index)
    }
    
    func updateSidebarState(_ on: Bool) {
        self.windowController()?.updateSidebarState(on)
    }
    
    func openCrash(_ file: CrashFile) {
        self.windowController()?.currentCrashFile = file
    }
    
    func currentCrashFile() -> CrashFile? {
        return self.windowController()?.currentCrashFile
    }
}

class MainWindowController: NSWindowController {

    @IBOutlet weak var navigationButton: NSSegmentedControl!
    @IBOutlet weak var sidebarButton: NSButton!

    var sidebarDelegate: ((_ sender: Any?)->Void)?
    var tabDelegate: ((_ index: Int)->Void)?
    
    var currentCrashFile: CrashFile? {
        didSet {
            NotificationCenter.default.post(name: .openCrashReport, object: self)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
    }
    
    func updateNavigationState(_ index: Int) {
        self.navigationButton.selectSegment(withTag: index)
    }
    
    func updateSidebarState(_ on: Bool) {
        var state = NSOnState
        if (!on) {
            state = NSOffState
        }

        if self.sidebarButton.state == state {
            return
        }
        
        self.sidebarButton.state = state
    }
    
    func openCrash(file: CrashFile) {
        self.currentCrashFile = file
    }
    
    func updateCrash(_ newContent: String) {
        let document = self.document as! CrashDocument
        
        if self.currentCrashFile == nil {
            self.currentCrashFile = document.crashFile
        }
        document.update(crashFile: self.currentCrashFile, newContent: newContent)
        self.window!.isDocumentEdited = true
        NotificationCenter.default.post(name: .crashUpdated, object: self.currentCrashFile?.crash)
    }
}

extension MainWindowController {
    @IBAction func toggleFileList(_ sender: Any?) {
        if let delegate = self.sidebarDelegate {
            delegate(sender)
        }
    }
    
    @IBAction func selectTabViewController(_ sender: Any?) {
        if let delegate = self.tabDelegate, let ctrl = sender as? NSSegmentedControl {
            delegate(ctrl.selectedSegment)
        }
    }
}

extension MainWindowController {
    
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
    
    private func updateSymbolicateProgress(start: Bool) {
        (self.window as? MainWindow)?.updateProgress(start: start)
    }
    
    @IBAction func symbolicate(_ sender: AnyObject?) {
        if let crash = self.currentCrashFile?.crash {
            self.updateSymbolicateProgress(start: true)

            crash.symbolicate(completion: { [weak self] (crash) in
                DispatchQueue.main.async {
                    self?.updateSymbolicateProgress(start: false)
                    NotificationCenter.default.post(name: .crashSymbolicated, object: crash)
                }
            })
        }
    }
}
