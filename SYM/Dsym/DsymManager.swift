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

import Foundation
import Combine

class DsymFile: Hashable {
    let name: String
    let path: String
    let uuids: [String]
    let binaryPath: String
    let isApp: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
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

class DsymManager {
    @Published
    var binaries: [Binary]  = []

    @Published
    var dsymFiles: [String: DsymFile] = [:]
    
    @Published
    var crash: CrashInfo?

    private var uuids: [String] {
        return self.binaries.compactMap { $0.uuid }
    }

    private let operationQueue = DispatchQueue(label: "dsym.manager")
    private lazy var monitor: MdfindWrapper = {
        let mdfind = MdfindWrapper()
        mdfind.delegate = self
        return mdfind
    }()
    
    func update(_ crash: CrashInfo?) {
        self.crash = crash
        self.binaries = crash?.embeddedBinaries ?? []
        if crash != nil {
            self.start(crash!)
        } else {
            self.stop()
        }
    }
    
    func start(_ crash: CrashInfo) {
        if let condition = self.createCondition(bundleID: crash.bundleID, binaries: crash.embeddedBinaries) {
            self.monitor.start(withCondition: condition)
        }
    }
    
    func stop() {
        self.monitor.stop()
    }
    
    func dsymFile(withUuid uuid: String) -> DsymFile? {
        return self.dsymFiles[uuid]
    }
    
    func assign(_ binary: Binary, dsymFileURL: URL) {
        let path = dsymFileURL.path
        let name = dsymFileURL.lastPathComponent
        let uuid = binary.uuid ?? ""
        let dsymFile = DsymFile(name: name, path: path, binaryPath: path, uuids: [uuid])
        
        DispatchQueue.main.async {
            self.dsymFiles[uuid] = dsymFile
        }
    }
    
    private func createCondition(bundleID: String?, binaries:[Binary]?) -> String? {
        var condition = ""
        var hasPrefix = false
        
        binaries?.forEach({ (bin) in
            if let uuid = bin.uuid {
                if hasPrefix {
                    condition += " || "
                }
                condition += "com_apple_xcode_dsym_uuids = \(uuid)"
                hasPrefix = true
            }
        })
        
        if bundleID != nil {
            if hasPrefix {
                condition += " || "
            }
            condition += "kMDItemCFBundleIdentifier = \(bundleID!)"
            hasPrefix = true
        }
        
        if condition.count == 0 {
            return nil
        }
        
        return condition
    }
    
    func dsymFileDidUpdate(_ dsymFiles: [DsymFile] = []) {
        DispatchQueue.main.async {
            var result = [String: DsymFile]()
            dsymFiles.forEach { (dsym) in
                dsym.uuids.forEach { (uuid) in
                    result[uuid] = dsym
                }
            }
            self.dsymFiles = result
        }
    }
}

//MARK: Monitor
extension DsymManager: MdfindWrapperDelegate {
    func mdfindWrapper(_ wrapper: MdfindWrapper, didFindResult result: [NSMetadataItem]?) {
        if result == nil {
            self.dsymFileDidUpdate()
            return
        }
        
        var appItems = [NSMetadataItem]()
        var dsyms = [DsymFile]()

        for item in result! {
            let type = item.value(forKey: NSMetadataItemContentTypeKey) as! String
            if type == "com.apple.xcode.dsym" {
                // dsym
                if let dsym = self.parseDsymFile(item) {
                    dsyms.append(dsym)
                }
            } else if type == "com.apple.xcode.archive" {
                // xcarchive
                if let results = self.parseXcarchiveFile(item) {
                    dsyms.append(contentsOf: results)
                }
            } else if type == "com.apple.application-bundle" {
                // app
                appItems.append(item)
            }
        }
        
        if dsyms.count > 0 || appItems.count == 0 {
            // found dsyms
            self.dsymFileDidUpdate(dsyms)
            return
        }
        
        self.operationQueue.async {
            for app in appItems {
                if let dsyms = self.parseAppBundle(app) {
                    self.dsymFileDidUpdate(dsyms)
                    return
                }
            }
        }
    }
    
    private func parseDsymFile(_ item: NSMetadataItem) -> DsymFile? {
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
    
    private func parseXcarchiveFile(_ item: NSMetadataItem) -> [DsymFile]? {
        guard let name = item.value(forKey: NSMetadataItemFSNameKey) as? String,
            let path = item.value(forKey: NSMetadataItemPathKey) as? String,
            let dsymPaths = item.value(forKey: "com_apple_xcode_dsym_paths") as? [String],
            let dsymUUIDs = item.value(forKey: "com_apple_xcode_dsym_uuids") as? [String],
            dsymPaths.count == dsymUUIDs.count
        else {
            return nil
        }
        
        return zip(dsymUUIDs, dsymPaths).compactMap { (dsymUUID, dsymPath) -> DsymFile? in
            if !self.uuids.contains(dsymUUID) {
                return nil
            }
            
            // dSYMs/xxx.app.dSYM/Contents/Resources/DWARF/xxx
            var displayPath = path
            let realPath = "\(path)/\(dsymPath)"
            let pathComponents = dsymPath.components(separatedBy: "/")
            if pathComponents.count > 2 {
                displayPath += "/\(pathComponents[0])/\(pathComponents[1])"
            } else {
                displayPath = realPath
            }
            
            return DsymFile(name: name, path: displayPath, binaryPath: realPath, uuids: [dsymUUID])
        }
    }
    
    private func parseAppBundle(_ item: NSMetadataItem) -> [DsymFile]? {
        guard  let path = item.value(forKey: NSMetadataItemPathKey) as? String,
            let bundle = Bundle(path: path) else {
            return nil
        }
        let name = item.value(forKey: NSMetadataItemFSNameKey) as? String
        var dsyms: [DsymFile] = [DsymFile]()

        if let exe = self.binaries.filter({ $0.executable }).first, let dsym = self.parseBinary(exe, bundle: bundle, name: name) {
            dsyms.append(dsym)
            for framework in self.binaries.filter({ !$0.executable }) {
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
