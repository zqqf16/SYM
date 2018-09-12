// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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

import Foundation
import Cocoa

extension Notification.Name {
    static let dsymListUpdated = Notification.Name("sym.DsymListUpdated")
}

class DsymFile: Hashable {
    let name: String
    let path: String
    let uuids: [String]
    let binaryPath: String

    var hashValue: Int {
        return self.path.hashValue
    }
    
    init(name: String, path: String, binaryPath: String, uuids: [String]) {
        self.name = name
        self.path = path
        self.binaryPath = binaryPath
        self.uuids = uuids
    }
    
    static func == (lhs: DsymFile, rhs: DsymFile) -> Bool {
        return lhs.path == rhs.path
    }
}

protocol DsymFileMonitorDelegate: class {
    func dsymFileMonitor(_ monitor: DsymFileMonitor, didFindDsymFile dsymFile:DsymFile) -> Void
}

class DsymFileMonitor {
    private let operationQueue = DispatchQueue(label: "dsym.finder")
    private let query = NSMetadataQuery()
    
    var uuid: String?
    var bundleID: String?
    
    weak var delegate: DsymFileMonitorDelegate?
    
    init() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleResult(_:)), name: .NSMetadataQueryDidFinishGathering, object: nil)
        nc.addObserver(self, selector: #selector(handleResult(_:)), name: .NSMetadataQueryDidUpdate, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func update(uuid: String?, bundleID: String?) {
        let restart = self.uuid != uuid || self.bundleID != bundleID
        self.uuid = uuid
        self.bundleID = bundleID
        if (restart) {
            self.stop()
            self.start()
        }
    }
    
    func start() {
        var condition: String = ""
        if let uuid = self.uuid {
            condition = "com_apple_xcode_dsym_uuids = \(uuid)"
        }
        
        if let bundleID = self.bundleID {
            if condition.count > 0 {
                condition += " || "
            }
            condition += "kMDItemCFBundleIdentifier = \(bundleID)"
        }
        
        if condition.count == 0 {
            return
        }
        
        self.query.predicate = NSPredicate(fromMetadataQueryString: condition)
        self.query.start()
    }
    
    func stop() {
        self.query.stop()
    }
    
    // MARK: Result
    @objc func handleResult(_ notification: NSNotification) {
        // query
        guard let query = notification.object as? NSMetadataQuery,
            query == self.query,
            let results = self.query.results as? [NSMetadataItem]
        else {
            return
        }
        
        var appItems = [NSMetadataItem]()
        
        for item in results {
            let type = item.value(forKey: NSMetadataItemContentTypeKey) as! String
            if type == "com.apple.xcode.dsym" {
                // dsym
                if let dsym = self.parseDsymFile(item) {
                    self.delegate?.dsymFileMonitor(self, didFindDsymFile: dsym)
                    return
                }
            } else if type == "com.apple.xcode.archive" {
                // xcarchive
                if let dsym = self.parseXcarchiveFile(item) {
                    self.delegate?.dsymFileMonitor(self, didFindDsymFile: dsym)
                    return
                }
            } else if type == "com.apple.application-bundle" {
                // app
                appItems.append(item)
            }
        }
        
        self.operationQueue.async {
            for app in appItems {
                if let dsym = self.parseAppBundle(app) {
                    self.delegate?.dsymFileMonitor(self, didFindDsymFile: dsym)
                    return
                }
            }
        }
    }
    
    func parseDsymFile(_ item: NSMetadataItem) -> DsymFile? {
        guard let name = item.value(forKey: NSMetadataItemFSNameKey) as? String,
            let path = item.value(forKey: NSMetadataItemPathKey) as? String,
            let dsymPaths = item.value(forKey: "com_apple_xcode_dsym_paths") as? [String],
            let dsymUUIDs = item.value(forKey: "com_apple_xcode_dsym_uuids") as? [String]
            else {
                return nil
        }
        
        let realPath = "\(path)/\(dsymPaths[0])"
        return DsymFile(name: name, path: path, binaryPath: realPath, uuids: dsymUUIDs)
    }
    
    func parseXcarchiveFile(_ item: NSMetadataItem) -> DsymFile? {
        guard let name = item.value(forKey: NSMetadataItemFSNameKey) as? String,
            let path = item.value(forKey: NSMetadataItemPathKey) as? String,
            let dsymPaths = item.value(forKey: "com_apple_xcode_dsym_paths") as? [String],
            let dsymUUIDs = item.value(forKey: "com_apple_xcode_dsym_uuids") as? [String],
            let uuid = self.uuid,
            let index = dsymUUIDs.index(of: uuid)
        else {
                return nil
        }
        
        // dSYMs/xxx.app.dSYM/Contents/Resources/DWARF/xxx
        let dsymPath = dsymPaths[index]
        var displayPath = path
        let realPath = "\(path)/\(dsymPath)"
        let pathComponents = dsymPath.components(separatedBy: "/")
        if pathComponents.count > 2 {
            displayPath += "/\(pathComponents[0])/\(pathComponents[1])"
        } else {
            displayPath = realPath
        }
        
        return DsymFile(name: name, path: displayPath, binaryPath: realPath, uuids: [uuid])
    }
    
    func parseAppBundle(_ item: NSMetadataItem) -> DsymFile? {
        guard let uuid = self.uuid,
            let path = item.value(forKey: NSMetadataItemPathKey) as? String,
            let bundle = Bundle(path: path),
            let exePath = bundle.executablePath,
            let uuids = SubProcess.dwarfdump([exePath])
        else {
            return nil
        }
        let name = item.value(forKey: NSMetadataItemFSNameKey) as? String ?? exePath
        for u in uuids {
            if u.0 == uuid {
                return DsymFile(name: name, path: exePath, binaryPath: exePath, uuids: [uuid])
            }
        }
        
        return nil
    }
}
