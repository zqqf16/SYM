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
    let isApp: Bool

    var hashValue: Int {
        return self.path.hashValue
    }
    
    init(name: String, path: String, binaryPath: String, uuids: [String], isApp: Bool = false) {
        self.name = name
        self.path = path
        self.binaryPath = binaryPath
        self.uuids = uuids
        self.isApp = isApp
    }
    
    static func == (lhs: DsymFile, rhs: DsymFile) -> Bool {
        return lhs.path == rhs.path
    }
}

protocol DsymFileMonitorDelegate: class {
    func dsymFileMonitor(_ monitor: DsymFileMonitor, didFindDsymFiles dsymFiles:[DsymFile]?) -> Void
}

class DsymFileMonitor {
    private let operationQueue = DispatchQueue(label: "dsym.finder")
    private let query = NSMetadataQuery()
    
    var uuids: [String]?
    var binaries: [Binary]?
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
    
    func update(bundleID: String?, binaries:[Binary]?) {
        self.binaries = binaries
        self.bundleID = bundleID
        self.uuids = binaries?.compactMap({ (binary) -> String? in
            return binary.uuid
        })
        self.stop()
        self.start()
    }
    
    func start() {
        var condition: String = ""
        var isFirst = true
        self.uuids?.forEach({ (uuid) in
            if !isFirst {
                condition += " || "
            }
            condition += "com_apple_xcode_dsym_uuids = \(uuid)"
            isFirst = false
        })
        
        if let bundleID = self.bundleID {
            if !isFirst {
                condition += " || "
            }
            condition += "kMDItemCFBundleIdentifier = \(bundleID)"
            isFirst = false
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
            self.delegate?.dsymFileMonitor(self, didFindDsymFiles: nil)
            return
        }
        
        var appItems = [NSMetadataItem]()
        var dsyms = [DsymFile]()

        for item in results {
            let type = item.value(forKey: NSMetadataItemContentTypeKey) as! String
            if type == "com.apple.xcode.dsym" {
                // dsym
                if let dsym = self.parseDsymFile(item) {
                    dsyms.append(dsym)
                }
            } else if type == "com.apple.xcode.archive" {
                // xcarchive
                if let dsym = self.parseXcarchiveFile(item) {
                    dsyms.append(dsym)
                }
            } else if type == "com.apple.application-bundle" {
                // app
                appItems.append(item)
            }
        }
        
        if dsyms.count > 0 {
            // found dsyms
            self.delegate?.dsymFileMonitor(self, didFindDsymFiles: dsyms)
            return
        }
        
        self.operationQueue.async {
            for app in appItems {
                if let dsyms = self.parseAppBundle(app) {
                    self.delegate?.dsymFileMonitor(self, didFindDsymFiles: dsyms)
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
            let uuids = self.uuids
        else {
            return nil
        }
        
        var index: Int = -1
        for (i, u) in dsymUUIDs.enumerated() {
            if uuids.contains(u) {
                index = i
                break
            }
        }
        if index < 0 {
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
        
        return DsymFile(name: name, path: displayPath, binaryPath: realPath, uuids: dsymUUIDs)
    }
    
    func parseAppBundle(_ item: NSMetadataItem) -> [DsymFile]? {
        guard let binaries = self.binaries,
            let path = item.value(forKey: NSMetadataItemPathKey) as? String,
            let bundle = Bundle(path: path) else {
            return nil
        }
        let name = item.value(forKey: NSMetadataItemFSNameKey) as? String
        var dsyms: [DsymFile] = [DsymFile]()

        if let exe = binaries.filter({ $0.executable }).first, let dsym = self.parseBinary(exe, bundle: bundle, name: name) {
            dsyms.append(dsym)
            for framework in binaries.filter({ !$0.executable }) {
                if let d = self.parseBinary(framework, bundle: bundle, name: name) {
                    dsyms.append(d)
                }
            }
            
            return dsyms
        }

        return nil
    }
    
    func parseBinary(_ binary: Binary, bundle: Bundle, name: String?) -> DsymFile? {
        guard let path = binary.relativePath,
            let absPath = bundle.path(forResource: path, ofType: nil),
            let uuidMap = SubProcess.dwarfdump([absPath]) else {
            return nil
        }
        let dsymName = name ?? path
        let uuids = uuidMap.map { $0.0 }
        for u in uuids {
            if u == binary.uuid {
                return DsymFile(name: dsymName, path: absPath, binaryPath: absPath, uuids: uuids, isApp: true)
            }
        }
        
        return nil;
    }
}
