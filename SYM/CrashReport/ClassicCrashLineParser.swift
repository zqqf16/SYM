// The MIT License (MIT)
//
// Copyright (c) 2022 zqqf16
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

/// Line-oriented parser for classic Apple crash text sections.
/// Detection / header field extraction and JSON decoders stay elsewhere.
enum ClassicCrashLineParser {
    // MARK: - Public entry points

    static func parseThreads(_ content: String, report: inout CrashReport) {
        var threads: [CrashThread] = []
        var currentThread: CrashThread?
        var currentFrames: [StackFrame] = []
        var section: ThreadScanSection = .seeking

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Binary Images:") {
                break
            }
            if trimmed.hasPrefix("Thread ") && trimmed.contains(" crashed with ") {
                // Registers block — leave the thread section.
                section = .done
                continue
            }
            if section == .done {
                continue
            }

            // Modern Console / iOS text: "Triggered by Thread: 0, Dispatch Queue: …"
            if section == .seeking, trimmed.hasPrefix("Triggered by Thread:") {
                applyTriggeredByThread(trimmed, report: &report)
                continue
            }

            if let header = parseThreadHeader(trimmed) {
                section = .inThread
                applyThreadHeader(
                    header,
                    currentThread: &currentThread,
                    currentFrames: &currentFrames,
                    threads: &threads,
                    report: &report
                )
                continue
            }

            guard section == .inThread, currentThread != nil else {
                continue
            }

            if let frame = parseStackFrameLine(line) {
                currentFrames.append(frame)
            }
        }

        if var thread = currentThread {
            thread.frames = currentFrames
            threads.append(thread)
        }

        report.threads = threads
        TextCrashParser.linkFramesToBinaryImages(&report)
    }

    static func parseBinaryImages(_ content: String, report: inout CrashReport) {
        var inSection = false

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Binary Images:") {
                inSection = true
                continue
            }
            guard inSection else {
                continue
            }
            if trimmed.isEmpty {
                if !report.binaryImages.isEmpty {
                    break
                }
                continue
            }
            if let image = parseBinaryImageLine(line) {
                var binary = image
                binary.isExecutable = binary.name == report.appName
                report.binaryImages.append(binary)
            } else if !report.binaryImages.isEmpty {
                // Left the binary-image list (EOF trailer / unrelated block).
                break
            }
        }
    }

    /// Fill report.uuid / report.arch from the executable binary image when present.
    static func applyMainBinaryMetadata(to report: inout CrashReport) {
        let main = report.binaryImages.first(where: \.isExecutable)
            ?? report.binaryImages.first(where: { $0.name == report.appName })
        if let uuid = main?.uuid, report.uuid == nil {
            report.uuid = uuid
        }
        if let arch = main?.arch, report.arch == nil {
            report.arch = arch
        }
    }

    // MARK: - Thread headers

    struct ThreadHeader {
        var index: Int
        var crashed: Bool
        var name: String?
        var queue: String?
    }

    private enum ThreadScanSection {
        case seeking
        case inThread
        case done
    }

    static func parseThreadHeader(_ line: String) -> ThreadHeader? {
        guard line.hasPrefix("Thread ") else {
            return nil
        }
        var rest = Substring(line.dropFirst("Thread ".count))

        var indexText = ""
        while let ch = rest.first, ch.isNumber {
            indexText.append(ch)
            rest.removeFirst()
        }
        guard let index = Int(indexText), !rest.isEmpty else {
            return nil
        }

        // Reject register dumps: "Thread 0 crashed with ARM Thread State…"
        if rest.hasPrefix(" crashed with ") || rest.hasPrefix(" Crashed with ") {
            return nil
        }

        // Modern Console / macOS translated:
        //   Thread 0 Crashed::
        //   Thread 0 Crashed::  Dispatch queue: com.apple.main-thread
        // Classic iOS:
        //   Thread 0 Crashed:
        if rest.hasPrefix(" Crashed") {
            rest = rest.dropFirst(" Crashed".count)
            consumeThreadHeaderSeparators(&rest)
            let (name, queue) = parseThreadNameFields(String(rest).trimmingCharacters(in: .whitespacesAndNewlines))
            return ThreadHeader(index: index, crashed: true, name: name, queue: queue)
        }

        if rest.hasPrefix(" name:") {
            let raw = rest.dropFirst(" name:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            let (name, queue) = parseThreadNameFields(raw)
            return ThreadHeader(index: index, crashed: false, name: name, queue: queue)
        }

        // Modern: "Thread N::  Dispatch queue: …"
        // Classic: "Thread N:" / "Thread N: …"
        if rest.hasPrefix("::") {
            rest = rest.dropFirst(2)
            let (name, queue) = parseThreadNameFields(String(rest).trimmingCharacters(in: .whitespacesAndNewlines))
            return ThreadHeader(index: index, crashed: false, name: name, queue: queue)
        }

        if rest.hasPrefix(":") {
            rest = rest.dropFirst()
            let after = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            if after.isEmpty {
                return ThreadHeader(index: index, crashed: false, name: nil, queue: nil)
            }
            if after == "Crashed" || after.hasPrefix("Crashed:") || after.hasPrefix("Crashed::") {
                var crashedRest = Substring(after.dropFirst("Crashed".count))
                consumeThreadHeaderSeparators(&crashedRest)
                let (name, queue) = parseThreadNameFields(String(crashedRest).trimmingCharacters(in: .whitespacesAndNewlines))
                return ThreadHeader(index: index, crashed: true, name: name, queue: queue)
            }
            let (name, queue) = parseThreadNameFields(after)
            return ThreadHeader(index: index, crashed: false, name: name, queue: queue)
        }

        return nil
    }

    /// Skip `:` / `::` separators used by classic and Console-translated headers.
    private static func consumeThreadHeaderSeparators(_ rest: inout Substring) {
        if rest.hasPrefix("::") {
            rest = rest.dropFirst(2)
        } else if rest.hasPrefix(":") {
            rest = rest.dropFirst()
        }
    }

    private static func applyTriggeredByThread(_ line: String, report: inout CrashReport) {
        let raw = line.dropFirst("Triggered by Thread:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // "0" or "0, Dispatch Queue: com.apple.main-thread"
        let numberText = raw.prefix(while: { $0.isNumber })
        guard let index = Int(numberText) else {
            return
        }
        if report.crashedThreadIndex == nil {
            report.crashedThreadIndex = index
        }
    }

    private static func applyThreadHeader(
        _ header: ThreadHeader,
        currentThread: inout CrashThread?,
        currentFrames: inout [StackFrame],
        threads: inout [CrashThread],
        report: inout CrashReport
    ) {
        // Classic Apple logs often emit two headers for one thread:
        //   Thread 0 name:  Dispatch queue: …
        //   Thread 0 Crashed:
        if let existing = currentThread,
           existing.index == header.index,
           currentFrames.isEmpty
        {
            currentThread = CrashThread(
                index: header.index,
                name: header.name ?? existing.name,
                queue: header.queue ?? existing.queue,
                crashed: header.crashed || existing.crashed,
                frames: []
            )
            if header.crashed {
                report.crashedThreadIndex = header.index
            }
            return
        }

        if var thread = currentThread {
            thread.frames = currentFrames
            threads.append(thread)
        }

        currentThread = CrashThread(
            index: header.index,
            name: header.name,
            queue: header.queue,
            crashed: header.crashed,
            frames: []
        )
        currentFrames = []
        if header.crashed {
            report.crashedThreadIndex = header.index
        }
    }

    static func parseThreadNameFields(_ raw: String) -> (name: String?, queue: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (nil, nil)
        }

        // Accept both classic "Dispatch queue:" and newer "Dispatch Queue:".
        for marker in ["Dispatch queue:", "Dispatch Queue:"] {
            if let range = trimmed.range(of: marker) {
                let before = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let after = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return (
                    before.isEmpty ? nil : String(before),
                    after.isEmpty ? nil : String(after)
                )
            }
        }
        return (trimmed, nil)
    }

    // MARK: - Stack frames

    /// Parse a classic frame line: `0   demo   \t0x… symbol`
    static func parseStackFrameLine(_ line: String) -> StackFrame? {
        var s = Substring(line)
        skipWhitespace(&s)
        guard let first = s.first, first.isNumber else {
            return nil
        }

        var indexText = ""
        while let ch = s.first, ch.isNumber {
            indexText.append(ch)
            s.removeFirst()
        }
        // Frame indexes in Apple logs are typically 0…999; reject longer runs
        // so register lines / addresses are not mistaken for frames.
        guard indexText.count <= 3, let index = Int(indexText) else {
            return nil
        }
        guard s.first?.isWhitespace == true else {
            return nil
        }
        skipWhitespace(&s)

        let imageName = takeNonWhitespace(&s)
        guard !imageName.isEmpty else {
            return nil
        }
        guard s.first?.isWhitespace == true else {
            return nil
        }
        skipWhitespace(&s)

        guard let address = takeHexAddress(&s) else {
            return nil
        }
        skipWhitespace(&s)
        let symbolText = s.isEmpty ? nil : String(s)
        return StackFrame(
            index: index,
            imageName: imageName,
            address: address,
            symbol: (symbolText?.isEmpty == false) ? symbolText : nil
        )
    }

    // MARK: - Binary images

    /// Binary Images line variants:
    /// - iOS: `0x1000 - 0x2000 name arch <uuid> /path`
    /// - macOS: `0x1000 - 0x2000 +name (1.0 - 1) <uuid> /path`
    /// - macOS (no version): `0x1000 - 0x2000 name (*) <uuid> /path`
    static func parseBinaryImageLine(_ line: String) -> BinaryImage? {
        var s = Substring(line)
        skipWhitespace(&s)

        guard let start = takeHexAddress(&s) else {
            return nil
        }
        skipWhitespace(&s)
        guard s.hasPrefix("-") else {
            return nil
        }
        s.removeFirst()
        skipWhitespace(&s)
        guard let end = takeHexAddress(&s) else {
            return nil
        }
        skipWhitespace(&s)

        let rawName = takeNonWhitespace(&s)
        guard !rawName.isEmpty else {
            return nil
        }
        // Apple marks non-OS binaries with a leading '+' (e.g. "+Demo", "+com.example.app").
        // Strip it so the name matches Process: / stack frames / appName.
        let name = rawName.hasPrefix("+") ? String(rawName.dropFirst()) : rawName
        guard !name.isEmpty else {
            return nil
        }
        skipWhitespace(&s)

        // Optional macOS version: `(1.0 - 1)`, `(*)`, `(???)`
        if s.first == "(" {
            guard skipParenthetical(&s) else {
                return nil
            }
            skipWhitespace(&s)
        }

        // Optional architecture (iOS / some macOS lines).
        var arch: String?
        if s.first != "<" {
            let token = takeNonWhitespace(&s)
            guard !token.isEmpty, CrashArch.looksLikeArch(token) else {
                return nil
            }
            arch = CrashArch.normalize(token)
            skipWhitespace(&s)
        }

        guard s.first == "<" else {
            return nil
        }
        s.removeFirst()
        var uuid = ""
        while let ch = s.first, ch != ">" {
            uuid.append(ch)
            s.removeFirst()
        }
        guard s.first == ">", !uuid.isEmpty else {
            return nil
        }
        s.removeFirst()
        skipWhitespace(&s)
        let path = String(s)

        let size: UInt64? = end >= start ? (end - start + 1) : nil
        return BinaryImage(
            name: name,
            uuid: uuid.crashUUIDFormat(),
            arch: arch,
            loadAddress: start,
            size: size,
            path: path,
            isExecutable: false,
            inApp: BinaryImage.isInApp(path: path)
        )
    }

    // MARK: - Lexical helpers

    private static func skipWhitespace(_ s: inout Substring) {
        while let ch = s.first, ch.isWhitespace {
            s.removeFirst()
        }
    }

    /// Consume a balanced `(…)` group (macOS Binary Images version field).
    @discardableResult
    private static func skipParenthetical(_ s: inout Substring) -> Bool {
        guard s.first == "(" else {
            return false
        }
        s.removeFirst()
        var depth = 1
        while let ch = s.first {
            s.removeFirst()
            if ch == "(" {
                depth += 1
            } else if ch == ")" {
                depth -= 1
                if depth == 0 {
                    return true
                }
            }
        }
        return false
    }

    private static func takeNonWhitespace(_ s: inout Substring) -> String {
        var value = ""
        while let ch = s.first, !ch.isWhitespace {
            value.append(ch)
            s.removeFirst()
        }
        return value
    }

    private static func takeHexAddress(_ s: inout Substring) -> UInt64? {
        guard s.hasPrefix("0x") || s.hasPrefix("0X") else {
            return nil
        }
        s.removeFirst(2)
        var hex = ""
        while let ch = s.first, ch.isHexDigit {
            hex.append(ch)
            s.removeFirst()
        }
        guard !hex.isEmpty else {
            return nil
        }
        return UInt64(hex, radix: 16)
    }
}
