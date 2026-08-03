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
import SnapKit

/// Detail pane for the device window. Hosts crash / file browsers without a
/// toolbar tab bar — navigation lives only in the sidebar.
class DeviceContentViewController: NSViewController {
    private let crashVC = CrashImporterViewController()
    private let fileVC = FileBrowserViewController()
    private let placeholderLabel = NSTextField(wrappingLabelWithString: "")

    private var currentChild: NSViewController?
    var onFileBrowserVisibilityChange: ((FileBrowserViewController?) -> Void)?

    var contentTitle: String = NSLocalizedString("Devices", comment: "") {
        didSet { view.window?.title = contentTitle }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeholderLabel.stringValue = NSLocalizedString(
            "Select a device item in the sidebar",
            comment: "Empty device detail placeholder"
        )
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.alignment = .center
        placeholderLabel.font = .systemFont(ofSize: 13)
        view.addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
        showPlaceholder()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = contentTitle
        notifyFileBrowserVisibility()
    }

    func showCrashList(_ deviceID: String?, title: String? = nil) {
        contentTitle = title ?? NSLocalizedString("Crash Log", comment: "")
        embed(crashVC)
        crashVC.reloadData(withDeviceID: deviceID)
        notifyFileBrowserVisibility()
    }

    func showFileList(_ deviceID: String?, appID: String?, title: String? = nil) {
        contentTitle = title ?? NSLocalizedString("File Browser", comment: "")
        embed(fileVC)
        fileVC.reloadData(withDeviceID: deviceID, appID: appID)
        notifyFileBrowserVisibility()
    }

    func showPlaceholder() {
        contentTitle = NSLocalizedString("Devices", comment: "")
        removeCurrentChild()
        placeholderLabel.isHidden = false
        notifyFileBrowserVisibility()
    }

    private func notifyFileBrowserVisibility() {
        onFileBrowserVisibilityChange?(currentChild === fileVC ? fileVC : nil)
    }

    private func embed(_ child: NSViewController) {
        if currentChild === child {
            placeholderLabel.isHidden = true
            return
        }
        removeCurrentChild()
        placeholderLabel.isHidden = true
        addChild(child)
        view.addSubview(child.view)
        child.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        currentChild = child
    }

    private func removeCurrentChild() {
        guard let child = currentChild else { return }
        child.view.removeFromSuperview()
        child.removeFromParent()
        currentChild = nil
    }
}
