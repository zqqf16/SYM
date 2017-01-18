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

class CrashInfoViewController: NSViewController {

    @IBOutlet weak var version: NSTextField!
    @IBOutlet weak var osVersion: NSTextField!
    @IBOutlet weak var device: NSTextField!
    @IBOutlet weak var uuid: NSTextField!
    @IBOutlet weak var dSym: NSTextField!
    @IBOutlet weak var showInFinder: NSButton!
    
    var crash: CrashReport?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.device.stringValue = "Unknow device"
        self.uuid.stringValue = "Not found"
        self.dSym.stringValue = "Not found"
        self.showInFinder.isHidden = true
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        if let crash = self.crash {
            self.updateInfo(withCrash: crash)
        }
    }
    
    private func updateInfo(withCrash crash: CrashReport) {
        self.version.stringValue = crash.version ?? ""
        self.osVersion.stringValue = crash.osVersion ?? ""
        if let device = crash.device {
            self.device.stringValue = "\(device) (\(crash.arch))"
        } else {
            self.device.stringValue = "Unknow device (\(crash.arch))"
        }
        
        if let appName = crash.appName, let image = crash.images[appName] {
            if let uuid = image.uuid {
                self.uuid.stringValue = uuid
            }
            if let d = image.dSym {
                self.dSym.stringValue = d
                self.showInFinder.isHidden = false
            }
        }
    }
    
    @IBAction func showInFinder(_ sender: AnyObject?) {
        let dSym = self.dSym.stringValue
        if dSym == "" || dSym == "Not found" {
            return
        }
        let fileURL = URL(fileURLWithPath: dSym)
        NSWorkspace.shared().activateFileViewerSelecting([fileURL])
    }
}
