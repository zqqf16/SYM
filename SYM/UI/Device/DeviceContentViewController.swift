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

class DeviceContentViewController: NSTabViewController {
    private let crashVC = CrashImporterViewController()
    private let fileVC = FileBrowserViewController()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let crashItem = NSTabViewItem(viewController: crashVC)
        crashItem.label = NSLocalizedString("Crash Log", comment: "")
        let fileItem = NSTabViewItem(viewController: fileVC)
        fileItem.label = NSLocalizedString("File Browser", comment: "")
        addTabViewItem(crashItem)
        addTabViewItem(fileItem)
        tabStyle = .toolbar
    }

    private func updateToolbar() {
        guard let item = tabView.selectedTabViewItem else { return }
        let index = tabView.indexOfTabViewItem(item)
        if index == .fileBrowserIndex {
            view.window?.title = NSLocalizedString("File Browser", comment: "")
        } else {
            view.window?.title = NSLocalizedString("Crash Log", comment: "")
        }
    }

    func showCrashList(_ deviceID: String?) {
        tabView.selectTabViewItem(at: .crashImporterIndex)
        crashVC.reloadData(withDeviceID: deviceID)
        updateToolbar()
    }

    func showFileList(_ deviceID: String?, appID: String?) {
        tabView.selectTabViewItem(at: .fileBrowserIndex)
        fileVC.reloadData(withDeviceID: deviceID, appID: appID)
        updateToolbar()
    }
}
