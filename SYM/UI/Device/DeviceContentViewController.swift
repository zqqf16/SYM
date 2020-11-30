// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
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

typealias TableViewItemIndex = Int

extension TableViewItemIndex {
    static let crashImporterIndex = 0
    static let fileBrowserIndex = 1
}

extension NSToolbarItem.Identifier {
    static let remove = NSToolbarItem.Identifier("ToolbarItemRemove")
}

extension NSToolbar {
    func toggleRemoveItem(visiable: Bool) {
        if visiable {
            if !self.items.contains(where: { $0.itemIdentifier == .remove }) {
                self.insertItem(withItemIdentifier: .remove, at: 1)
            }
        } else {
            self.removeItem(with: .remove)
        }
    }
}

class DeviceContentViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    private func toggleToolbarItems() {
        guard let item = self.tabView.selectedTabViewItem,
              let toolbar = self.view.window?.toolbar
        else {
            return
        }
        
        let index = self.tabView.indexOfTabViewItem(item)
        toolbar.toggleRemoveItem(visiable: index == .fileBrowserIndex)
    }
    
    private var crashViewController: CrashImporterViewController! {
        return self.tabView.tabViewItem(at: .crashImporterIndex).viewController as? CrashImporterViewController
    }
    
    private var fileViewController: FileBrowserViewController! {
        return self.tabView.tabViewItem(at: .fileBrowserIndex).viewController as? FileBrowserViewController
    }
    
    func showCrashList(_ deviceID: String?) {
        self.tabView.selectTabViewItem(at: .crashImporterIndex)
        self.crashViewController.reloadData(withDeviceID: deviceID)
        self.toggleToolbarItems()
    }
    
    func showFileList(_ deviceID: String?, appID: String?) {
        self.tabView.selectTabViewItem(at: .fileBrowserIndex)
        self.fileViewController.reloadData(withDeviceID: deviceID, appID: appID)
        self.toggleToolbarItems()
    }
}
