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

import Cocoa

struct CrashFileType {
    static let crash = "Crash"
    static let plist = "com.apple.property-list"
}

extension Notification.Name {
    static let crashInfoUpdated = Notification.Name("sym.crashInfoUpdated")
    static let crashSymbolicated = Notification.Name("sym.crashSymbolicated")
    static let crashDidOpen = Notification.Name("sym.crashDidOpen")
}

class CrashDocument: NSDocument {
    let notificationCenter = NotificationCenter()
    
    let textStorage =  NSTextStorage()
    var crashInfo: CrashInfo? {
        didSet {
            self.notificationCenter.post(name: .crashInfoUpdated, object: crashInfo)
        }
    }
    
    override init() {
        super.init()
        self.textStorage.delegate = self
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Main Window Controller") as! NSWindowController
        self.addWindowController(windowController)
    }

    override func data(ofType typeName: String) throws -> Data {
        return self.textStorage.string.data(using: String.Encoding.utf8)!
    }

    override func read(from data: Data, ofType typeName: String) throws {
        if typeName == CrashFileType.plist {
            try self.readPlist(from: data)
        } else {
            try self.readCrash(from: data)
        }
    }
    
    private func readCrash(from data: Data) throws {
        let content = String(data: data, encoding: .utf8) ?? ""
        self.textStorage.replaceCharacters(in: self.textStorage.string.nsRange, with: content)
        self.notificationCenter.post(name: .crashDidOpen, object: nil)
    }
    
    private func readPlist(from data: Data) throws {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: AnyObject] else {
            return
        }
        
        guard let content = plist?["description"] as? String,
            let data = content.data(using: .utf8)
            else {
                return
        }
        
        try self.readCrash(from: data)
    }
    
    override class var autosavesInPlace: Bool {
        return false
    }
    
    override class var autosavesDrafts: Bool {
        return false
    }
}

extension CrashDocument: NSTextStorageDelegate {
    func parseCrashInfo() {
        self.crashInfo = CrashInfo.parse(self.textStorage.string)
    }
    
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        self.parseCrashInfo()
    }
}

// MARK: Symbolicate
extension CrashDocument {
    func symbolicate(withDsymPath dsym: String?) {
        guard let crash = self.crashInfo else {
            return
        }
        
        DispatchQueue.global().async {
            let content = crash.symbolicate(dsym: dsym)
            DispatchQueue.main.async {
                self.textStorage.replaceCharacters(in: self.textStorage.string.nsRange, with: content)
                self.notificationCenter.post(name: .crashSymbolicated, object: self)
            }
        }
    }
}
