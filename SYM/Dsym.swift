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


@objc class Dsym: NSObject, NSCoding {
    var uuids: [String]
    var path: String
    var name: String

    @objc init(uuids: [String], name: String, path: String) {
        self.uuids = uuids
        self.path = path
        self.name = name
    }

    convenience required init?(coder aDecoder: NSCoder) {
        let uuids = aDecoder.decodeObject(forKey: "uuids") as! [String]
        let path = aDecoder.decodeObject(forKey: "path") as! String
        let name = aDecoder.decodeObject(forKey: "name") as! String
        self.init(uuids: uuids, name: name, path: path)
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(uuids, forKey: "uuids")
        aCoder.encode(path, forKey: "path")
        aCoder.encode(name, forKey: "name")
    }
}


class DsymManager {
    static let sharedInstance = DsymManager()
    
    var dsyms: [Dsym]? {
        var all = userImportDsyms ?? [Dsym]()
        if autoLoadedDsyms != nil {
            all += autoLoadedDsyms!
        }
        return all
    }

    var autoLoadedDsyms: [Dsym]?
    var userImportDsyms: [Dsym]?

    var fileSearch = FileSearch()

    var filePath: String {
        let fileName = "dSYM.list"
        let fm = FileManager.default
        guard let dir = fm.appSupportDirectory() else {
            return fileName
        }
        
        return (dir as NSString).appendingPathComponent(fileName)
    }
    
    func findAllDsyms() {
        self.fileSearch.search(nil) { (dsyms) in
            self.autoLoadedDsyms = dsyms
        }
        // User imported dSYMs
        self.loadUserImportDsyms()
    }
    
    func loadUserImportDsyms() {
        let list = NSKeyedUnarchiver.unarchiveObject(withFile: self.filePath) as? [Dsym]
        self.userImportDsyms = list?.filter(){ (dsym: Dsym) -> Bool in
            return FileManager.default.fileExists(atPath: dsym.path)
        }
        
        if self.userImportDsyms?.count != list?.count {
            self.saveUserImportDsyms()
        }
    }

    func saveUserImportDsyms() {
        if self.userImportDsyms != nil {
            NSKeyedArchiver.archiveRootObject(self.userImportDsyms!, toFile: self.filePath)
        }
    }
    
    func dsym(withUUID uuid: String) -> Dsym? {
        if self.dsyms == nil {
            return nil
        }
        for dsym in self.dsyms! {
            if dsym.uuids.index(of: uuid) != nil {
                return dsym
            }
        }
        
        return nil
    }
    
    func addDsym(_ new: Dsym) -> Bool {
        if self.dsym(withUUID: new.uuids[0]) != nil {
            return false
        }
        
        if self.userImportDsyms == nil {
            self.userImportDsyms = [Dsym]()
        }
        self.userImportDsyms!.append(new)
        self.saveUserImportDsyms()
        
        return true
    }
    
    func uuidOfFile(_ path: String, completion: @escaping (([String]?) -> Void)) {
        let operation = SubProcess(dsymPath: path)
        operation.completionBlock = {
            DispatchQueue.main.async(execute: {
                let result = operation.dwarfResult()
                completion(result)
            })
        }
        
        globalTaskQueue.addOperation(operation)
    }
    
    func importDsym(fromURL url: URL, completion: @escaping (([String]?, Bool)->Void)) {
        guard let type = typeOfFile(url.path) else {
            completion(nil, false)
            return
        }
        
        switch type {
        case .archive, .binary, .dsym:
            break
        default:
            completion(nil, false)
            return
        }
        
        self.uuidOfFile(url.path) { (result) in
            guard let uuids = result else {
                completion(nil, false)
                return
            }

            let result = self.addDsym(Dsym(uuids: uuids, name: url.lastPathComponent, path: url.path))
            completion(uuids, result)
        }
    }
}
