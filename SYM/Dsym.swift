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


class Dsym {
    let name: String
    let path: String
    let uuids: [String]
    var arches: [String]?
    let displayPath: String
    
    init(name: String, path: String, displayPath: String, uuids: [String]) {
        self.name = name
        self.path = path
        self.uuids = uuids
        self.displayPath = displayPath
    }
}

class XCArchive: Dsym {
    let dsyms: [Dsym]
    
    init(name: String, path: String, dsyms: [Dsym]) {
        self.dsyms = dsyms
        
        var uuids: [String] = []
        for dsym in dsyms {
            uuids += dsym.uuids
        }
        super.init(name: name, path: path, displayPath: path, uuids: uuids)
    }
    
    func dsym(withUUID uuid: String) -> Dsym? {
        for dsym in self.dsyms {
            if dsym.uuids.contains(uuid) {
                return dsym
            }
        }
        
        return nil
    }
}


extension Dsym: Hashable {
    var hashValue: Int {
        return self.path.hashValue
    }
    
    static func == (lhs: Dsym, rhs: Dsym) -> Bool {
        return lhs.path == rhs.path
    }
}


extension Notification.Name {
    static let dsymListUpdated = Notification.Name("sym.DsymListUpdated")
}


class DsymManager {
    static let shared = DsymManager()
    
    private var queue = DispatchQueue(label: "dSYM serial", attributes: .concurrent)
    private var cache: [Dsym] = []
    private var finder = FileFinder()
    
    var dsymList: [Dsym] {
        var result: [Dsym] = []
        self.queue.sync {
            result = self.cache
        }
        return result
    }
    
    func updateDsymList(_ completion: (([Dsym]?)->Void)?) {
        if self.finder.isRunning {
            if let handler = completion {
                handler(self.dsymList)
            }
            return
        }
        
        self.finder.search { [weak self] (result) in
            self?.parse(searchResult: result)
            if let handler = completion {
                handler(self?.dsymList)
            }
            NotificationCenter.default.post(name: .dsymListUpdated, object: nil)
        }
    }
    
    func parse(searchResult: [Dsym]?) {
        guard let providers = searchResult else {
            return
        }
        
        self.queue.async(flags: .barrier) {
            self.cache = providers
        }
    }
    
    func dsym(withUUID uuid: String) -> Dsym? {
        for dsym in self.dsymList {
            if dsym.uuids.contains(uuid) {
                return dsym
            }
        }
        return nil
    }
}
