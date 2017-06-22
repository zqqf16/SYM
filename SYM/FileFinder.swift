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

enum FileType {
    case crash
    case csv
    case dsym
    case binary
    case archive
    case zip
}

func typeOfFile(_ path: String) -> FileType? {
    do {
        let type = try NSWorkspace.shared.type(ofFile: path)
        switch type {
        case "com.apple.crashreport", "public.plain-text", "public.text":
            return .crash
        case "com.pkware.zip-archive":
            return .zip
        case "com.apple.xcode.archive":
            return .archive
        case "com.apple.xcode.dsym":
            return .dsym
        case "public.comma-separated-values-text":
            return .csv
        case "public.unix-executable", "public.data":
            return .binary
        default:
            break
        }
    } catch _ {
        return nil
    }

    // file type by extension
    let ext = (path as NSString).pathExtension.lowercased()
    switch ext {
    case "txt", "sym", "log", "crash":
        return .crash
    default:
        return nil
    }
}

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
    func search(uuid: String = "*", completion: @escaping ([DsymFile]?)->Void) {
        let condition = "com_apple_xcode_dsym_uuids = \(uuid)"
        self.search(condition) { (results) in
            if results == nil {
                completion(nil)
                return
            }
            
            var dsymFiles: [DsymFile] = []
            for item in results! {
                let name = item.value(forKey: NSMetadataItemFSNameKey) as! String
                let path = item.value(forKey: NSMetadataItemPathKey) as! String
                
                let dsyms = item.value(forKey: "com_apple_xcode_dsym_paths") as! [String]
                let uuids = item.value(forKey: "com_apple_xcode_dsym_uuids") as! [String]
                
                for (index, uuid) in uuids.enumerated() {
                    let dsym = DsymFile(uuid: uuid, path: "\(path)/\(dsyms[index])", name: name, displayedPath: path)
                    dsymFiles.append(dsym)
                }
            }
            
            completion(dsymFiles)
        }
    }
}
