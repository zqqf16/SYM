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


class VSplitViewController: NSSplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.splitView.wantsLayer = true
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.splitViewItems[0].collapsed = self.windowController!.bottomBarCollapsed
        
        if CrashManager.sharedInstance.crashes.count > 1 {
            self.splitViewItems[0].collapsed = false
            self.windowController?.sidebarCollapsed = false
        }
        
        self.registerNotifications()
    }
    
    private func registerNotifications() {
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(didOpenFiles), name: CMDidOpenCrashFilesNotification, object: nil)
        nc.addObserver(self, selector: #selector(didClickNavigationButtons), name: SidebarNotification, object: nil)
    }
    
    private func unregisterNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func didOpenFiles(notification: NSNotification) {
        if CrashManager.sharedInstance.crashes.count > 1 {
            self.splitViewItems[0].collapsed = false
            self.windowController?.sidebarCollapsed = false
        }
    }
    
    func didClickNavigationButtons(notification: NSNotification) {
        self.splitViewItems[0].collapsed = self.windowController!.sidebarCollapsed
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.unregisterNotifications()
    }
}


class HSplitViewController:NSSplitViewController {
    override func viewWillAppear() {
        super.viewWillAppear()
        self.splitViewItems[1].collapsed = self.windowController!.bottomBarCollapsed
        self.registerNotifications()
    }

    private func registerNotifications() {
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(didClickNavigationButtons), name: SidebarNotification, object: nil)
    }
    
    func didClickNavigationButtons(notification: NSNotification) {
        self.splitViewItems[1].collapsed = self.windowController!.bottomBarCollapsed
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.unregisterNotifications()
    }
    
    private func unregisterNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
