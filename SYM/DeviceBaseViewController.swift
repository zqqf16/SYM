// The MIT License (MIT)
//
// Copyright (c) 2017 - 2019 zqqf16
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

extension NSPopUpButton {
    func reloadItemsWithDevices(_ devices: [String]) {
        self.removeAllItems()
        var unamed = 0
        devices.forEach({ (udid) in
            let lockdown = MDLockdown(udid: udid)
            var title = lockdown.deviceName
            if title == nil {
                title = "Unnamed device \(unamed)"
                unamed += 1
            }
            self.addItem(withTitle: title!)
        })
    }
}

class DeviceBaseViewController : NSViewController {

    @IBOutlet weak var deviceButton: NSPopUpButton!
    var deviceList: [String] = MDDeviceMonitor.shared().connectedDevices
    var hasLoadDevices: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(_deviceConnected(_:)), name: NSNotification.Name.MDDeviceMonitor, object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        if !self.hasLoadDevices {
            self._deviceConnected(nil)
            self.hasLoadDevices = true
        }
    }
    
    @objc func _deviceConnected(_ notification: Notification?) {
        self.deviceList = MDDeviceMonitor.shared().connectedDevices
        self.deviceButton.reloadItemsWithDevices(self.deviceList)
        self.deviceConnectionChanged()
    }
    
    @IBAction func _changeDevice(_ sender: NSPopUpButton) {
        let index = self.deviceButton.indexOfSelectedItem
        if index < 0 || index > self.deviceList.count - 1 {
            return
        }
        let udid = self.deviceList[index]
        self.deviceSelectionChanged(udid)
    }
    
    open func deviceSelectionChanged(_ udid: String?) {
        
    }
    
    open func deviceConnectionChanged() {
        
    }
}
