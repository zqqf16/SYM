// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
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
import Combine

struct CrashFileType {
    static let crash = "Crash"
    static let plist = "com.apple.property-list"
}

class CrashDocument: NSDocument {
    let textStorage = NSTextStorage()

    @Published
    var crashInfo: Crash?

    @Published
    var isSymbolicating: Bool = false

    var isReplaceable: Bool {
        return fileURL == nil && textStorage.string.count == 0
    }

    private var contentPublisher = PassthroughSubject<String, Never>()
    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        textStorage.delegate = self
        cancellable = contentPublisher
            .debounce(for: 0.5, scheduler: DispatchQueue.global())
            .sink { [weak self] content in
                self?.parseCrashInfo(content)
            }
    }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Main Window Controller") as! NSWindowController
        addWindowController(windowController)
    }

    override func data(ofType _: String) throws -> Data {
        return textStorage.string.data(using: String.Encoding.utf8)!
    }

    override func read(from data: Data, ofType typeName: String) throws {
        if typeName == CrashFileType.plist {
            try readPlist(from: data)
        } else {
            try readCrash(from: data)
        }
    }

    private func update(content: String) {
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: textStorage.string.nsRange, with: content)
        textStorage.applyStyle()
        textStorage.endEditing()
    }

    private func readCrash(from data: Data) throws {
        var content = String(data: data, encoding: .utf8) ?? ""
        if let convertor = convertor(for: content) {
            content = convertor.convert(content)
        }
        update(content: content)
        // self.parseCrashInfo(content)
    }

    private func readPlist(from data: Data) throws {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: AnyObject] else {
            return
        }

        guard let content = plist["description"] as? String,
              let data = content.data(using: .utf8)
        else {
            return
        }

        try readCrash(from: data)
    }

    override class var autosavesInPlace: Bool {
        return false
    }

    override class var autosavesDrafts: Bool {
        return false
    }
}

extension CrashDocument: NSTextStorageDelegate {
    func parseCrashInfo(_ content: String) {
        let crashInfo = Crash.parse(content)
        DispatchQueue.main.async {
            self.crashInfo = crashInfo
        }
    }

    func textStorage(_: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range _: NSRange, changeInLength _: Int) {
        if editedMask.contains(.editedCharacters) {
            contentPublisher.send(textStorage.string)
        }
    }
}

// MARK: Symbolicate

extension CrashDocument {
    func symbolicate(withDsymPaths dsyms: [String]?) {
        guard let crash = crashInfo else {
            return
        }

        DispatchQueue.global().async {
            self.isSymbolicating = true
            let content = crash.symbolicate(dsymPaths: dsyms)
            DispatchQueue.main.async {
                self.update(content: content)
                self.undoManager?.removeAllActions()
                self.updateChangeCount(.changeDone)
                self.isSymbolicating = false
            }
        }
    }
}
