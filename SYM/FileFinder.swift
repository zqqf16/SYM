// The MIT License (MIT)
//
// Copyright (c) 2017 zqqf16
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

class FileFinder {
    var observer: AnyObject?
    var query = NSMetadataQuery()
    
    var isRunning: Bool {
        return self.query.isGathering
    }
    
    func search(_ condition: String, completion: @escaping ([NSMetadataItem]?)->Void) {
        query.predicate = NSPredicate(fromMetadataQueryString: condition)
        
        self.observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: nil, queue: nil) { (notification) in
            self.query.stop()
            if let observer = self.observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
            
            let result = self.query.results as! [NSMetadataItem]
            completion(result)
        }
        
        query.start()
    }
}

extension FileFinder {
    func search(uuid: String = "*", completion: @escaping ([Dsym]?)->Void) {
        let condition = "com_apple_xcode_dsym_uuids = \(uuid)"
        self.search(condition) { (results) in
            if results == nil {
                completion(nil)
                return
            }
            
            let dsyms = results!.flatMap { item in
                return self.parse(uuidSearchResult: item)
            }
            completion(dsyms)
        }
    }
    
    func parse(uuidSearchResult result: NSMetadataItem) -> Dsym? {
        // `mdls xxx.xcarchive`
        let name = result.value(forKey: NSMetadataItemFSNameKey) as! String
        let path = result.value(forKey: NSMetadataItemPathKey) as! String
        let type = result.value(forKey: NSMetadataItemContentTypeKey) as! String
        
        let dsymPaths = result.value(forKey: "com_apple_xcode_dsym_paths") as! [String]
        let dsymUUIDs = result.value(forKey: "com_apple_xcode_dsym_uuids") as! [String]
        
        if type == "com.apple.xcode.dsym" {
            let realPath = "\(path)/\(dsymPaths[0])"
            return Dsym(name: name, path: realPath, displayPath: path, uuids: dsymUUIDs)
        }
        
        if dsymPaths.count != dsymUUIDs.count {
            return nil
        }
        
        // xcarchive
        var pathGroup: [String: [String]] = [:]
        for (index, path) in dsymPaths.enumerated() {
            var uuids = pathGroup[path] ?? []
            uuids.append(dsymUUIDs[index])
            pathGroup[path] = uuids
        }
        
        let dsyms = pathGroup.map { (tuple: (path: String, uuids: [String])) -> Dsym in
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
            
            return Dsym(name: name, path: realPath, displayPath: displayPath, uuids: tuple.uuids)
        }
        
        return XCArchive(name: name, path: path, dsyms: dsyms)
    }
}
