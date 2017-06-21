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

struct DsymFile {
    var uuid: String
    var path: String
    var name: String
    
    var displayedPath: String
    
    init(uuid: String, path: String, name: String, displayedPath: String) {
        self.uuid = uuid
        self.path = path
        self.name = name
        self.displayedPath = displayedPath
    }
}

extension DsymFile: Hashable {
    var hashValue: Int {
        return self.path.hashValue
    }
    
    static func == (lhs: DsymFile, rhs: DsymFile) -> Bool {
        return lhs.path == rhs.path
    }
}

class DsymManager {
    static let shared = DsymManager()
    
    private var queue = DispatchQueue(label: "dSYM serial", attributes: .concurrent)
    private var cache: [String: DsymFile] = [:]
    
    var dsymList: [String: DsymFile] {
        get {
            var result: [String: DsymFile] = [:]
            self.queue.sync {
                result = self.cache
            }
            return result
        }
        set {
            self.queue.async(flags: .barrier) {
                self.cache = newValue
            }
        }
    }
    
    func loadAllDsymFiles(_ completion: @escaping (([DsymFile]?)->Void)) {
        FileFinder().search() { (result) in
            if let files = result {
                self.cache(fileList: files)
            }
            completion(result)
        }
    }
    
    func cache(fileList: [DsymFile]) {
        for file in fileList {
            self.dsymList[file.uuid] = file
        }
    }
    
    func findDsymFile(_ uuid: String, completion: @escaping ((DsymFile?)->Void)) {
        if let dsym = self.dsymList[uuid] {
            completion(dsym)
            return
        }
        
        self.loadAllDsymFiles { _ in
            completion(self.dsymList[uuid])
        }
    }
}
