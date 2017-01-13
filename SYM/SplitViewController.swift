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
import AppKit


class SplitViewController: NSSplitViewController {

    private var myContext = 0
    
    var sidebar: NSSplitViewItem {
        return self.splitViewItems[0]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleFileList), name: .toggleFileList, object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // check and set sidebar state
        if self.windowController()?.isFileListOpen != !self.sidebar.isCollapsed {
            self.toggleSidebar(nil)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if let doc = self.document(), doc is BundleDocument {
            self.toggleSidebar(nil)
        }
    }
    
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        self.windowController()?.updateSidebarState(!self.sidebar.isCollapsed)
    }
    
    func handleToggleFileList(_ notification: Notification) {
        if let wc = notification.object as? MainWindowController, wc == self.windowController() {
            self.toggleSidebar(nil)
        }
    }
}
