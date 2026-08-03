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
    var crashInfo: CrashReport?

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
        let windowController = MainWindowController()
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

    private func replaceContent(_ content: String) {
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: textStorage.string.nsRange, with: content)
        textStorage.applyStyle()
        textStorage.endEditing()
    }

    private func readCrash(from data: Data) throws {
        let content = String(data: data, encoding: .utf8) ?? ""
        replaceContent(content)
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
        let report = CrashFormatter.format(CrashDecoding.decode(content))
        DispatchQueue.main.async {
            self.crashInfo = report
        }
    }

    func textStorage(_: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range _: NSRange, changeInLength _: Int) {
        if editedMask.contains(.editedCharacters) {
            contentPublisher.send(textStorage.string)
        }
    }
}

extension CrashDocument {
    func symbolicate(withDsymPaths dsyms: [String: String]?) {
        guard let crash = crashInfo else {
            return
        }

        Task {
            await MainActor.run {
                self.isSymbolicating = true
            }

            let engine = CompositeSymbolEngine()
            let symbolicated = await crash.symbolicated(using: engine, dsyms: dsyms ?? [:])

            await MainActor.run {
                self.applySymbolicated(symbolicated)
                self.isSymbolicating = false
            }
        }
    }

    /// Replace editor content / crash model as one undoable "Symbolicate" step.
    private func applySymbolicated(_ report: CrashReport) {
        let previousContent = textStorage.string
        let previousReport = crashInfo
        let newContent = report.formattedContent

        guard previousContent != newContent || previousReport != report else {
            return
        }

        registerSymbolicationUndo(content: previousContent, report: previousReport)
        crashInfo = report
        replaceContent(newContent)
        updateChangeCount(.changeDone)
    }

    private func registerSymbolicationUndo(content: String, report: CrashReport?) {
        guard let undoManager else {
            return
        }

        undoManager.registerUndo(withTarget: self) { document in
            document.restoreAfterSymbolicate(content: content, report: report)
        }
        undoManager.setActionName(NSLocalizedString("Symbolicate", comment: "Undo action name"))
    }

    private func restoreAfterSymbolicate(content: String, report: CrashReport?) {
        let currentContent = textStorage.string
        let currentReport = crashInfo
        registerSymbolicationUndo(content: currentContent, report: currentReport)
        crashInfo = report
        replaceContent(content)
    }
}
