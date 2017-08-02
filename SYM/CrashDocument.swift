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

import Cocoa

struct CrashFileType {
    static let crash = "Crash"
    static let plist = "com.apple.property-list"
}

class CrashDocument: NSDocument {
    var content: String?
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Main Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }
    
    var mainWindowController: MainWindowController {
        return self.windowControllers[0] as! MainWindowController
    }
    
    override func windowControllerDidLoadNib(_ aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let content = self.content else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }

        return content.data(using: String.Encoding.utf8)!
    }

    override func read(from data: Data, ofType typeName: String) throws {
        if typeName == CrashFileType.crash {
            try self.readCrash(from: data)
        } else if typeName == CrashFileType.plist {
            try self.readPlist(from: data)
        }
        DispatchQueue.main.async {
            self.mainWindowController.open(crash: self.content ?? "")
        }
    }
    
    private func readCrash(from data: Data) throws {
        self.content = String(data: data, encoding: String.Encoding.utf8)
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
