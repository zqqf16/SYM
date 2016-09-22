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


protocol DocumentContentDelegate: class {
    func contentToSave() -> String?
}


class Document: NSDocument {

    var content: String?
    weak var delegate: DocumentContentDelegate?

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Main Window Controller") as! NSWindowController
        self.addWindowController(windowController)
    }

    override func windowControllerDidLoadNib(_ aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
    }

    override func data(ofType typeName: String) throws -> Data {
        if let newContent = self.delegate?.contentToSave() {
            self.content = newContent
        }

        if self.content == nil {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }

        return self.content!.data(using: String.Encoding.utf8)!
    }

    override func read(from data: Data, ofType typeName: String) throws {
        self.content = String(data: data, encoding: String.Encoding.utf8)
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }
    
    override class func autosavesDrafts() -> Bool {
        return false
    }
}
