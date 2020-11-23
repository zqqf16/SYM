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

struct DeviceSidebarHeaderNode: SidebarNode {
    var title: String
    var lockdown: MDLockdown

    var children: [SidebarNode]? = []
    var image: NSImage?
    var isGroup: Bool = true
    var isSelectable: Bool = true
    
    init(lockdown: MDLockdown, children: [SidebarNode]) {
        self.lockdown = lockdown
        self.title = lockdown.deviceName ?? "Unnamed device"
        self.children = children
    }
}

struct DeviceSidebarFileHeaderNode: SidebarNode {
    var title: String = "File Browser"
    var children: [SidebarNode]?
    var image: NSImage? = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
    var isGroup: Bool = false
    var isSelectable: Bool = false

    init(children: [DeviceSidebarFileNode]) {
        self.children = children
    }
}

struct DeviceSidebarFileNode: SidebarNode {
    var title: String
    var children: [SidebarNode]? = nil
    var image: NSImage? = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
    var isGroup: Bool = false
    var isSelectable: Bool = true
    
    var deviceID: String
    var appID: String

    init(deviceID: String, appID: String, title: String) {
        self.deviceID = deviceID
        self.appID = appID
        self.title = title
    }
}

struct DeviceSidebarCrashNode: SidebarNode {
    var title: String = "Crash"
    var children: [SidebarNode]? = []
    var image: NSImage? = NSImage(systemSymbolName: "ladybug", accessibilityDescription: nil)
    var isGroup: Bool = false
    var isSelectable: Bool = true
    
    var deviceID: String

    init(deviceID: String) {
        self.deviceID = deviceID
    }
}

class DeviceDataSource {
    @Published
    var nodes: [SidebarNode] = []
    
    private var cancellable: AnyCancellable!
    private var storage = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .MDDeviceMonitor)
            .sink { [weak self] (notification) in
                self?.prepareDevices()
            }.store(in: &storage)
        self.prepareDevices()
    }
    
    func prepareDevices() {
        DispatchQueue.global().async {
            let udids = MDDeviceMonitor.shared().connectedDevices
            let nodes = udids.map { (udid) -> SidebarNode in
                let lockdown = MDLockdown(udid: udid)
                let instproxy = MDInstProxy(lockdown: lockdown)
                let appInfoList = instproxy.listApps().filter { $0.isDeveloping }
                
                let appNodes = appInfoList.map { info in
                    return DeviceSidebarFileNode(deviceID: udid, appID: info.identifier , title: info.name)
                }
                let fileNode = DeviceSidebarFileHeaderNode(children: appNodes)
                let crashNode = DeviceSidebarCrashNode(deviceID: udid)
                return DeviceSidebarHeaderNode(lockdown: lockdown, children: [fileNode, crashNode])
            }
            
            DispatchQueue.main.async {
                self.nodes = nodes
            }
        }
    }
}


class DeviceHomeViewController: NSSplitViewController {

    fileprivate var sidebar: DeviceSidebarViewController! {
        return self.splitViewItems.first?.viewController as? DeviceSidebarViewController
    }
    
    fileprivate var content: DeviceContentViewController! {
        return self.splitViewItems.last?.viewController as? DeviceContentViewController
    }
    
    let dataSource = DeviceDataSource()
    var storage = Set<AnyCancellable>()
    
    var nodes: [SidebarNode] = [] {
        didSet {
            self.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupSidebar()
        
        self.dataSource.$nodes.assign(to: \.nodes, on: self).store(in: &storage)
    }
    
    private func setupSidebar() {
        self.sidebar.delegate = self
    }
    
    private func reloadData() {
        self.sidebar.nodes = self.nodes
    }
}

extension DeviceHomeViewController: DeviceSidebarViewControllerDelegate {
    func sidebar(_ sidebar: DeviceSidebarViewController, didSelectNode node: SidebarNode) {
        if node is DeviceSidebarFileNode {
            let fileNode = node as! DeviceSidebarFileNode
            self.content.showFileList(fileNode.deviceID, appID: fileNode.appID)
        } else if node is DeviceSidebarCrashNode {
            let crashNode = node as! DeviceSidebarCrashNode
            self.content.showCrashList(crashNode.deviceID)
        }
    }
}
