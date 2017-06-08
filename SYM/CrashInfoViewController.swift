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
            let name = self.deviceName(device) ?? device
            self.device.stringValue = "\(name) (\(crash.arch))"
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
    
    func deviceName(_ fromModel: String) -> String? {
        let models: [String: String] = [
            "i386":     "i386 Simulator",
            "x86_64":   "x86_64 Simulator",
            
            "iPhone1,1":    "iPhone",
            "iPhone1,2":    "iPhone 3G",
            "iPhone2,1":    "iPhone 3GS",
            "iPhone3,1":    "iPhone 4",
            "iPhone3,2":    "iPhone 4(Rev A)",
            "iPhone3,3":    "iPhone 4(CDMA)",
            "iPhone4,1":    "iPhone 4S",
            "iPhone5,1":    "iPhone 5(GSM)",
            "iPhone5,2":    "iPhone 5(GSM+CDMA)",
            "iPhone5,3":    "iPhone 5c(GSM)",
            "iPhone5,4":    "iPhone 5c(GSM+CDMA)",
            "iPhone6,1":    "iPhone 5s(GSM)",
            "iPhone6,2":    "iPhone 5s(GSM+CDMA)",
            "iPhone7,1":    "iPhone 6+(GSM+CDMA)",
            "iPhone7,2":    "iPhone 6(GSM+CDMA)",
            "iPhone8,1":    "iPhone 6S(GSM+CDMA)",
            "iPhone8,2":    "iPhone 6S+(GSM+CDMA)",
            "iPhone8,4":    "iPhone SE(GSM+CDMA)",
            "iPhone9,1":    "iPhone 7(GSM+CDMA)",
            "iPhone9,2":    "iPhone 7+(GSM+CDMA)",
            "iPhone9,3":    "iPhone 7(GSM+CDMA)",
            "iPhone9,4":    "iPhone 7+(GSM+CDMA)",
            
            "iPad1,1":  "iPad",
            "iPad2,1":  "iPad 2(WiFi)",
            "iPad2,2":  "iPad 2(GSM)",
            "iPad2,3":  "iPad 2(CDMA)",
            "iPad2,4":  "iPad 2(WiFi Rev A)",
            "iPad2,5":  "iPad Mini 1G (WiFi)",
            "iPad2,6":  "iPad Mini 1G (GSM)",
            "iPad2,7":  "iPad Mini 1G (GSM+CDMA)",
            "iPad3,1":  "iPad 3(WiFi)",
            "iPad3,2":  "iPad 3(GSM+CDMA)",
            "iPad3,3":  "iPad 3(GSM)",
            "iPad3,4":  "iPad 4(WiFi)",
            "iPad3,5":  "iPad 4(GSM)",
            "iPad3,6":  "iPad 4(GSM+CDMA)",
            "iPad4,1":  "iPad Air(WiFi)",
            "iPad4,2":  "iPad Air(GSM)",
            "iPad4,3":  "iPad Air(GSM+CDMA)",
            "iPad5,3":  "iPad Air 2 (WiFi)",
            "iPad5,4":  "iPad Air 2 (GSM+CDMA)",
            "iPad4,4":  "iPad Mini 2G (WiFi)",
            "iPad4,5":  "iPad Mini 2G (GSM)",
            "iPad4,6":  "iPad Mini 2G (GSM+CDMA)",
            "iPad4,7":  "iPad Mini 3G (WiFi)",
            "iPad4,8":  "iPad Mini 3G (GSM)",
            "iPad4,9":  "iPad Mini 3G (GSM+CDMA)",
            
            "iPod1,1":  "iPod 1st Gen",
            "iPod2,1":  "iPod 2nd Gen",
            "iPod3,1":  "iPod 3rd Gen",
            "iPod4,1":  "iPod 4th Gen",
            "iPod5,1":  "iPod 5th Gen",
            "iPod7,1":  "iPod 6th Gen",
        ]
        
        return models[fromModel]
    }
    
    @IBAction func showInFinder(_ sender: AnyObject?) {
        let dSym = self.dSym.stringValue
        if dSym == "" || dSym == "Not found" {
            return
        }
        let fileURL = URL(fileURLWithPath: dSym)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}
