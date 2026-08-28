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
import Combine

class DeviceSidebarNode: SidebarNode {
    var title: String
    var children: [SidebarNode]?
    var image: NSImage?
    var isGroup: Bool = true
    var isSelectable: Bool = true
    var toolTip: String? = ""

    init(title: String, imageName: String = "") {
        self.title = title
        if !imageName.isEmpty {
            image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)
        }
    }
}

class DeviceSidebarFileNode: DeviceSidebarNode {
    var deviceID: String
    var appID: String

    init(deviceID: String, appID: String, title: String) {
        self.deviceID = deviceID
        self.appID = appID
        super.init(title: title, imageName: "app.fill")
        isGroup = false
        isSelectable = true
        toolTip = appID
    }
}

class DeviceSidebarCrashNode: DeviceSidebarNode {
    var deviceID: String

    init(deviceID: String) {
        self.deviceID = deviceID
        super.init(title: NSLocalizedString("Crash Log", comment: "Crash Log"), imageName: "ladybug.fill")
        isGroup = false
        isSelectable = true
    }
}

extension DeviceSidebarNode {
    static func deviceHeaderNode(_ title: String?, children: [DeviceSidebarNode]) -> DeviceSidebarNode {
        let node = DeviceSidebarNode(title: title ?? NSLocalizedString("Unnamed device", comment: ""))
        node.children = children
        node.isGroup = true
        node.isSelectable = false
        return node
    }
}

class DeviceDataSource {
    @Published
    var nodes: [DeviceSidebarNode] = []

    private var storage = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .MDDeviceMonitor)
            .sink { [weak self] _ in
                self?.prepareDevices()
            }.store(in: &storage)
        prepareDevices()
    }

    func prepareDevices() {
        DispatchQueue.global().async {
            let udids = MDDeviceMonitor.shared().connectedDevices
            let nodes = udids.map { udid -> DeviceSidebarNode in
                let lockdown = MDLockdown(udid: udid)
                let instproxy = MDInstProxy(lockdown: lockdown)
                let sbServices = MDSBServices(lockdown: lockdown)
                let appInfoList = instproxy.listApps().filter { $0.isDeveloping }

                let appNodes = appInfoList.map { info -> DeviceSidebarFileNode in
                    let app = DeviceSidebarFileNode(deviceID: udid, appID: info.identifier, title: info.name)
                    if let icon = sbServices.requestIconImage(info.identifier) {
                        app.image = icon
                    }
                    return app
                }

                // Flat, Finder-like: Crash Log + apps under the device (no duplicate tabs).
                var children: [DeviceSidebarNode] = [
                    DeviceSidebarCrashNode(deviceID: udid),
                ]
                if !appNodes.isEmpty {
                    children.append(contentsOf: appNodes)
                }
                return DeviceSidebarNode.deviceHeaderNode(lockdown.deviceName, children: children)
            }

            DispatchQueue.main.async {
                self.nodes = nodes
            }
        }
    }
}

class DeviceHomeViewController: NSSplitViewController {
    private let sidebarVC = DeviceSidebarViewController()
    private let contentVC = DeviceContentViewController()

    let dataSource = DeviceDataSource()
    var storage = Set<AnyCancellable>()
    var onFileBrowserVisibilityChange: ((FileBrowserViewController?) -> Void)?

    var nodes: [DeviceSidebarNode] = [] {
        didSet { reloadData() }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        splitView.autosaveName = "DeviceHomeSplitView"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 280
        sidebarItem.canCollapse = true
        addSplitViewItem(sidebarItem)

        let detailItem = NSSplitViewItem(viewController: contentVC)
        detailItem.minimumThickness = 420
        addSplitViewItem(detailItem)

        sidebarVC.delegate = self
        contentVC.onFileBrowserVisibilityChange = { [weak self] browser in
            self?.onFileBrowserVisibilityChange?(browser)
        }
        // keyPath `assign(to:on:)` would retain this controller inside its own
        // subscription — use a weak sink so the view controller can deinit.
        dataSource.$nodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nodes in
                self?.nodes = nodes
            }
            .store(in: &storage)
    }

    private func reloadData() {
        sidebarVC.nodes = nodes
        if nodes.isEmpty {
            contentVC.showPlaceholder()
        }
    }
}

extension DeviceHomeViewController: DeviceSidebarViewControllerDelegate {
    func sidebar(_: DeviceSidebarViewController, didSelectNode node: SidebarNode) {
        if let fileNode = node as? DeviceSidebarFileNode {
            contentVC.showFileList(fileNode.deviceID, appID: fileNode.appID, title: fileNode.title)
        } else if let crashNode = node as? DeviceSidebarCrashNode {
            contentVC.showCrashList(crashNode.deviceID, title: crashNode.title)
        }
    }
}
