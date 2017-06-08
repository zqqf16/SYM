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


import Cocoa


class CrashDocument: NSDocument {
    var crashFile: CrashFile = CrashFile()
    
    override var displayName: String! {
        get {
            let name = super.displayName
            self.crashFile.name = name!
            return name
        }
        set {
            super.displayName = newValue
            self.crashFile.name = displayName
        }
    }

    override var fileURL: URL? {
        didSet {
            self.crashFile.url = fileURL
        }
    }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Main Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }

    override func windowControllerDidLoadNib(_ aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let content = self.crashFile.crash?.content else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }

        return content.data(using: String.Encoding.utf8)!
    }

    override func read(from data: Data, ofType typeName: String) throws {
        if let content = String(data: data, encoding: String.Encoding.utf8) {
            self.crashFile.crashGenerator = {
                return CrashReport(content)
            }
        }
        
        self.openCrash(file: self.crashFile)
    }
    
    override class var autosavesInPlace: Bool {
        return true
    }
    
    override class var autosavesDrafts: Bool {
        return false
    }
    
    func openCrash(file: CrashFile) {
        DispatchQueue.main.async {
            (self.windowControllers[0] as! MainWindowController).openCrash(file: file)
        }
    }
    
    func update(crashFile: CrashFile?, newContent: String, completion:((_ crash: CrashReport)->(Void))?) {
        let file = crashFile ?? self.crashFile
        
        DispatchQueue.global().async {
            if let crash = file.crash {
                crash.update(content: newContent)
            } else {
                file.crash = CrashReport(newContent)
            }
            
            if let callback = completion {
                callback(file.crash!)
            }
        }
    }
}
