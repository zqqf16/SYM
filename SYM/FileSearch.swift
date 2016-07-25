// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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
    case Crash
    case CSV
    case Dsym
    case Binary
    case Archive
    case Zip
}

func typeOfFile(path: String) -> FileType? {
    do {
        let type = try NSWorkspace.sharedWorkspace().typeOfFile(path)
        switch type {
        case "com.apple.crashreport", "public.plain-text", "public.text":
            return .Crash
        case "com.pkware.zip-archive":
            return .Zip
        case "com.apple.xcode.archive":
            return .Archive
        case "com.apple.xcode.dsym":
            return .Dsym
        case "public.comma-separated-values-text":
            return .CSV
        case "public.data":
            return .Binary
        default:
            break
        }
    } catch _ {
        return nil
    }

    // file type by extension
    let ext = (path as NSString).pathExtension.lowercaseString
    switch ext {
    case "txt", "sym", "log", "crash":
        return .Crash
    default:
        return nil
    }
}


typealias FileSearchHandler = ([NSMetadataItem]?)->()

class FileSearch {
    
    var metadataSearch: NSMetadataQuery = NSMetadataQuery()
    var observer: AnyObject?
    
    func search(condition: String, completion: FileSearchHandler) {
        let predicate = NSPredicate(fromMetadataQueryString: condition)
        self.metadataSearch.predicate = predicate
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        
        weak var weakSelf = self
        self.observer = notificationCenter.addObserverForName(NSMetadataQueryDidFinishGatheringNotification, object: metadataSearch, queue: nil) { (notification) in
            
            weakSelf!.metadataSearch.stopQuery()
            if (weakSelf!.observer != nil) {
                NSNotificationCenter.defaultCenter().removeObserver(weakSelf!.observer!)
            }
            
            let results = weakSelf?.metadataSearch.results as! [NSMetadataItem]
            completion(results)
        }

        metadataSearch.startQuery()
    }
    
    deinit {
        if (self.observer != nil) {
            NSNotificationCenter.defaultCenter().removeObserver(self.observer!)
        }
    }
}


// MARK: - dSYM

typealias DsymSearchHandler = ([Dsym]?)->()

extension FileSearch {
    func search(uuid: String?, completion: DsymSearchHandler) {
        var condition = "com_apple_xcode_dsym_uuids = "
        if uuid != nil {
            condition += uuid!
        } else {
            condition += "*"
        }
        
        self.search(condition) { results in
            if results == nil {
                completion(nil)
                return
            }
            
            var dsyms = [Dsym]()
            for item in results! {
                let name = item.valueForKey(NSMetadataItemFSNameKey) as! String
                
                // mdls xxx
                let path = item.valueForKey(NSMetadataItemPathKey) as! String
                let dsym = item.valueForKey("com_apple_xcode_dsym_paths") as! [String]
                let uuids = item.valueForKey("com_apple_xcode_dsym_uuids") as! [String]
                let dsymPath = path.stringByAppendingString("/\(dsym[0])")
                dsyms.append(Dsym(uuids:uuids, name:name, path:dsymPath))
            }
            
            completion(dsyms)
        }
    }
}