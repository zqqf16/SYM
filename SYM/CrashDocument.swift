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

enum CrashDocumentError: LocalizedError, Equatable {
    case invalidEncoding
    case invalidPlist
    case missingCrashDescription

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return NSLocalizedString(
                "The crash report is not valid UTF-8 text.",
                comment: "CrashDocument read error"
            )
        case .invalidPlist:
            return NSLocalizedString(
                "The property list is not a valid crash report container.",
                comment: "CrashDocument read error"
            )
        case .missingCrashDescription:
            return NSLocalizedString(
                "The property list does not contain crash report text.",
                comment: "CrashDocument read error"
            )
        }
    }
}

class CrashDocument: NSDocument {
    let textStorage = NSTextStorage()

    @Published
    var crashInfo: CrashReport?

    @Published
    var isSymbolicating: Bool = false

    /// Set after a symbolicate pass; the editor shows it transiently (e.g. "Symbolicated 12 of 20 frames").
    @Published
    private(set) var symbolicationSummary: String?

    var isReplaceable: Bool {
        return fileURL == nil && textStorage.string.count == 0
    }

    /// Monotonic token so stale background parse/symbolicate results are dropped.
    private(set) var contentRevision: UInt64 = 0

    private var contentPublisher = PassthroughSubject<(content: String, revision: UInt64), Never>()
    private var cancellable: AnyCancellable?
    /// Suppress parse while swapping raw JSON for synthesized classic text.
    private var isApplyingPresentation = false
    private var symbolicationTask: Task<Void, Never>?
    private var symbolicationGeneration: UInt64 = 0

    override init() {
        super.init()
        textStorage.delegate = self
        cancellable = contentPublisher
            .debounce(for: 0.5, scheduler: DispatchQueue.global())
            .sink { [weak self] payload in
                self?.parseCrashInfo(payload.content, revision: payload.revision)
            }
    }

    deinit {
        symbolicationTask?.cancel()
        cancellable?.cancel()
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
        guard let content = String(data: data, encoding: .utf8) else {
            throw CrashDocumentError.invalidEncoding
        }
        // Decode synchronously so JSON IPS / Keep open already translated,
        // matching Console.app’s “Translated Report” presentation.
        let report = CrashFormatter.format(CrashDecoding.decode(content))
        contentRevision &+= 1
        isApplyingPresentation = true
        replaceContent(report.formattedContent)
        isApplyingPresentation = false
        crashInfo = report
    }

    private func readPlist(from data: Data) throws {
        let plist: Any
        do {
            plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw CrashDocumentError.invalidPlist
        }
        guard let dictionary = plist as? [String: AnyObject] else {
            throw CrashDocumentError.invalidPlist
        }
        guard let content = dictionary["description"] as? String,
              let contentData = content.data(using: .utf8)
        else {
            throw CrashDocumentError.missingCrashDescription
        }
        try readCrash(from: contentData)
    }

    override class var autosavesInPlace: Bool {
        return false
    }

    override class var autosavesDrafts: Bool {
        return false
    }
}

extension CrashDocument: NSTextStorageDelegate {
    func parseCrashInfo(_ content: String, revision: UInt64) {
        let report = CrashFormatter.format(CrashDecoding.decode(content))
        DispatchQueue.main.async { [weak self] in
            self?.applyParsedReport(report, parsedFrom: content, revision: revision)
        }
    }

    /// Publish model; when content is JSON IPS/Keep, swap editor to classic text.
    private func applyParsedReport(_ report: CrashReport, parsedFrom content: String, revision: UInt64) {
        // Drop stale work: user edited (or another parse finished) after this job started.
        guard revision == contentRevision else {
            return
        }
        // Editor must still show the text we parsed (or its auto-translated form later).
        guard textStorage.string == content else {
            return
        }

        crashInfo = report

        guard report.formattedContent != content else {
            return
        }

        isApplyingPresentation = true
        undoManager?.disableUndoRegistration()
        replaceContent(report.formattedContent)
        undoManager?.enableUndoRegistration()
        isApplyingPresentation = false
    }

    func textStorage(_: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range _: NSRange, changeInLength _: Int) {
        guard !isApplyingPresentation, editedMask.contains(.editedCharacters) else {
            return
        }
        contentRevision &+= 1
        contentPublisher.send((textStorage.string, contentRevision))
    }
}

extension CrashDocument {
    func symbolicate(withDsymPaths dsyms: [String: String]?) {
        guard let crash = crashInfo else {
            return
        }

        symbolicationTask?.cancel()
        symbolicationGeneration &+= 1
        let generation = symbolicationGeneration
        let revision = contentRevision
        let expectedContent = textStorage.string

        isSymbolicating = true
        symbolicationTask = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    guard let self, generation == self.symbolicationGeneration else { return }
                    self.isSymbolicating = false
                    self.symbolicationTask = nil
                }
            }

            let engine = CompositeSymbolEngine()
            let symbolicated = await crash.symbolicated(using: engine, dsyms: dsyms ?? [:])

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard generation == self.symbolicationGeneration,
                      !Task.isCancelled,
                      revision == self.contentRevision,
                      self.textStorage.string == expectedContent
                else {
                    return
                }
                self.applySymbolicated(symbolicated)
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
        // Presentation replace must not schedule a parse of the just-written content
        // as a "user edit" that races the model we are applying.
        contentRevision &+= 1
        isApplyingPresentation = true
        crashInfo = report
        replaceContent(newContent)
        isApplyingPresentation = false
        updateChangeCount(.changeDone)
        symbolicationSummary = Self.makeSymbolicationSummary(after: report)
    }

    private static func makeSymbolicationSummary(after report: CrashReport) -> String {
        let frames = report.allFrames
        let resolved = frames.filter(\.isSymbolicated).count
        return String(
            format: NSLocalizedString("Symbolicated %lld of %lld frames", comment: "Symbolication result summary"),
            Int64(resolved),
            Int64(frames.count)
        )
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
        contentRevision &+= 1
        isApplyingPresentation = true
        crashInfo = report
        replaceContent(content)
        isApplyingPresentation = false
        symbolicationSummary = nil
    }
}
