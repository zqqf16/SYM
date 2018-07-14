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

class XCArchiveFile: DsymFile {
    let dsyms: [DsymFile]
    
    init(name: String, path: String, dsyms: [DsymFile]) {
        self.dsyms = dsyms
        let uuids: [String] = dsyms.flatMap { return $0.uuids }
        super.init(name: name, path: name, binaryPath: "", uuids: uuids)
    }
    
    func dsymFile(_ uuid: String) -> DsymFile? {
        for dsym in self.dsyms {
            if dsym.uuids.contains(uuid) {
                return dsym
            }
        }
        
        return nil
    }
}

class DsymFileManager {
    static let shared = DsymFileManager()

    private var finder = FileFinder()
    var dsymFiles: [DsymFile] = [] {
        didSet {
            NotificationCenter.default.post(name: .dsymListUpdated, object: nil)
        }
    }
    
    func dsymFile(withUUID uuid: String) -> DsymFile? {
        for dsym in self.dsymFiles {
            if dsym.uuids.contains(uuid) {
                if let archive = dsym as? XCArchiveFile {
                    return archive.dsymFile(uuid)
                }
                return dsym
            }
        }
        return nil
    }
    
    func reload() {
        if self.finder.isRunning {
            return
        }
        
        let condition = "com_apple_xcode_dsym_uuids = *"
        self.finder.search(condition) { [weak self] (results) in
            guard results != nil else {
                self?.dsymFiles = []
                return
            }
            var files = [DsymFile]()
            for item in results! {
                if let dsym = self?.parse(uuidSearchResult: item) {
                    if let archive = dsym as? XCArchiveFile {
                        files.append(contentsOf: archive.dsyms)
                    } else {
                        files.append(dsym)
                    }
                }
            }
            self?.dsymFiles = files
        }
    }
    
    private func parse(uuidSearchResult result: NSMetadataItem) -> DsymFile? {
        // `mdls xxx.xcarchive`
        let name = result.value(forKey: NSMetadataItemFSNameKey) as! String
        let path = result.value(forKey: NSMetadataItemPathKey) as! String
        let type = result.value(forKey: NSMetadataItemContentTypeKey) as! String
        
        let dsymPaths = result.value(forKey: "com_apple_xcode_dsym_paths") as! [String]
        let dsymUUIDs = result.value(forKey: "com_apple_xcode_dsym_uuids") as! [String]
        
        if type == "com.apple.xcode.dsym" {
            let realPath = "\(path)/\(dsymPaths[0])"
            return DsymFile(name: name, path: path, binaryPath: realPath, uuids: dsymUUIDs)
        }
        
        if dsymPaths.count != dsymUUIDs.count {
            return nil
        }
        
        // xcarchive
        var pathGroup: [String: [String]] = [:]
        for (index, subPath) in dsymPaths.enumerated() {
            var uuids = pathGroup[subPath] ?? []
            uuids.append(dsymUUIDs[index])
            pathGroup[subPath] = uuids
        }
        
        let dsyms = pathGroup.map { (tuple: (path: String, uuids: [String])) -> DsymFile in
            // dSYMs/xxx.app.dSYM/Contents/Resources/DWARF/xxx
            var name = tuple.path
            var displayPath = path
            let realPath = "\(path)/\(tuple.path)"
            let pathComponents = tuple.path.components(separatedBy: "/")
            if pathComponents.count > 2 {
                name = pathComponents[1]
                displayPath += "/\(pathComponents[0])/\(pathComponents[1])"
            } else {
                displayPath = realPath
            }
            
            return DsymFile(name: name, path: displayPath, binaryPath: realPath, uuids: tuple.uuids)
        }
        
        return XCArchiveFile(name: name, path: path, dsyms: dsyms)
    }
}
