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


class MainViewController: NSViewController, NSTextViewDelegate {
    @IBOutlet var textView: NSTextView!
    
    var crashIndex: Int = -1
    
    var crash: Crash? {
        get {
            if self.crashIndex < 0 {
                return nil
            }
            return CrashManager.sharedInstance.crashes[self.crashIndex]
        }
        set {
            if self.crashIndex < 0 {
                return
            }
            if newValue == nil {
                return
            }
            CrashManager.sharedInstance.crashes[self.crashIndex] = newValue!
        }
    }
    
    var contentChanged: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.textView.font = NSFont(name: "Menlo", size: 11)
        self.textView.delegate = self
        // padding
        self.textView.textContainerInset = CGSize(width: 10, height: 10)
        
        self.registerNotifications()
    }
    
    override func viewWillAppear() {
        self.windowController?.crashRepresenter = self
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func registerNotifications() {
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(didSelectCrash), name: CTDidSelectCrashNotification, object: nil)
        nc.addObserver(self, selector: #selector(doSymbolic), name: DoSymbolicateNotification, object: nil)
    }
    
    func didSelectCrash(notification: NSNotification) {
        self.crashIndex = notification.object as! Int
        self.openCrash(self.crash)
    }

    func openCrash(crash: Crash?) {
        if crash != nil {
            self.textView.setAttributeString(crash!.pretty())
        } else {
            self.textView.string = ""
        }
        self.contentChanged = false
    }

    // MARK: - Text View Delegate
    func textDidChange(notification: NSNotification) {
        self.contentChanged = true
    }
    
    @IBAction func doSymbolic(sender: AnyObject) {
        
        guard let crash = self.currentCrash() else {
            return
        }

        if !crash.isValid() {
            return
        }

        guard let dsym = DsymManager.sharedInstance.dsym(withUUID: crash.uuid!) else {
            let alert = NSAlert()
            alert.addButtonWithTitle("OK")
            alert.addButtonWithTitle("Cancel")
            alert.messageText = "Please import a dSYM with this UUID"
            alert.informativeText = "\(crash.uuid!)"
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: { (result) in
                if result == NSAlertFirstButtonReturn {
                    self.windowController?.choosedSYMFile(nil)
                }
            })
            return
        }

        weak var weakSelf = self
       
        CrashManager.sharedInstance.symbolicate(crash, withDsym: dsym.path) { (crash) in
            dispatch_async(dispatch_get_main_queue(), {
                let crashString: NSAttributedString = crash.pretty()
                weakSelf!.textView.setAttributeString(crashString)
            })
        }
    }
}

extension MainViewController: CrashRepresenter {
    func isCrashChanged() -> Bool {
        return self.contentChanged
    }
    
    func currentCrash() -> Crash? {
        if !self.contentChanged {
            return self.crash
        }
        
        let raw = self.textView.string
        let crash = CrashManager.sharedInstance.parseCrash(raw)
        if self.crash != nil {
            crash.filePath = self.crash!.filePath
        }
        
        crash.isChanged = true
        return crash
    }
}