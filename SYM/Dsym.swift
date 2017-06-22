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

extension Notification.Name {
    static let dsymListUpdated = Notification.Name("sym.DsymListUpdated")
}

class DsymFile {
    var uuid: String
    var path: String
    var name: String
    var arch: String?
    
    var displayPath: String
    
    init(uuid: String, path: String, name: String, displayPath: String) {
        self.uuid = uuid
        self.path = path
        self.name = name
        self.displayPath = displayPath
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
    private var finder = FileFinder()
    
    var dsymList: [String: DsymFile] {
        var result: [String: DsymFile] = [:]
        self.queue.sync {
            result = self.cache
        }
        return result
    }
    
    func updateDsymList() {
        if self.finder.isRunning {
            return
        }
        
        self.finder.search { [weak self] (result) in
            DispatchQueue.global().async {
                self?.parseSearchResult(result)
            }
        }
    }
    
    func parseSearchResult(_ result: [DsymFile]?) {
        guard let files = result else {
            NotificationCenter.default.post(name: .dsymListUpdated, object: nil)
            return
        }
        
        var dsyms: [String: DsymFile] = [:]
        for f in files {
            dsyms[f.uuid] = f
        }
        
        let pathes = Set<DsymFile>(files).map { $0.path }
        if let archResult = SubProcess.dwarfdump(pathes) {
            for arch in archResult {
                if let file = dsyms[arch.0] {
                    file.arch = arch.1
                }
            }
        }
        
        self.queue.async(flags: .barrier) {
            self.cache = dsyms
        }
        
        NotificationCenter.default.post(name: .dsymListUpdated, object: nil)
    }
    
    func findDsymFile(_ uuid: String) -> DsymFile? {
        return self.dsymList[uuid]
    }
}
