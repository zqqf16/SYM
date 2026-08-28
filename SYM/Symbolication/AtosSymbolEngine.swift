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

struct AtosSymbolEngine: SymbolEngine {
    private struct FrameKey: Hashable {
        let uuid: String
        let address: UInt64
    }

    func symbolicate(_ report: CrashReport, dsymPaths: [String: String]) async -> CrashReport {
        // `SubProcess.atos` blocks on `waitUntilExit` — keep it off the Swift
        // cooperative pool (several documents symbolicating at once would
        // otherwise starve pool threads for the duration of each atos run).
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.performSymbolication(report, dsymPaths: dsymPaths))
            }
        }
    }

    /// Blocking implementation; one atos process per image, images in parallel.
    static func performSymbolication(_ report: CrashReport, dsymPaths: [String: String]) -> CrashReport {
        var updated = report
        let imagesByUUID = CrashUUID.imagesByUUID(report.binaryImages)

        var framesByUUID = [String: [StackFrame]]()
        for frame in updated.allFrames where !frame.isSymbolicated {
            if let uuid = CrashUUID.normalize(frame.imageUUID) {
                framesByUUID[uuid, default: []].append(frame)
            }
        }

        guard !framesByUUID.isEmpty else {
            return updated
        }

        let lock = NSLock()
        var resolvedByKey = [FrameKey: StackFrame]()
        let group = DispatchGroup()
        let atosQueue = DispatchQueue(
            label: "im.zorro.SYM.atos",
            qos: .userInitiated,
            attributes: .concurrent
        )

        for (uuid, frames) in framesByUUID {
            guard let image = imagesByUUID[uuid],
                  let loadAddress = image.loadAddress,
                  let dsymPath = dsymPaths[uuid],
                  let dwarfPath = DsymLocator.resolveDwarfBinaryPath(from: dsymPath)
            else {
                continue
            }

            let arch = CrashArch.normalize(image.arch) ?? CrashArch.normalize(report.arch) ?? "arm64"
            let addresses = frames.map { $0.address.crashHexString }
            group.enter()
            atosQueue.async {
                defer { group.leave() }
                guard let results = SubProcess.atos(
                    loadAddress: loadAddress.crashHexString,
                    addresses: addresses,
                    dsym: dwarfPath,
                    arch: arch
                ) else {
                    return
                }

                var parsed = [FrameKey: StackFrame]()
                // Map by index (not zip) so a short/empty atos result can't shift
                // later frames onto the wrong addresses.
                for (index, frame) in frames.enumerated() {
                    guard index < results.count else { break }
                    let resolved = parseAtosOutput(results[index], frame: frame)
                    parsed[FrameKey(uuid: uuid, address: frame.address)] = resolved
                }
                lock.lock()
                for (key, value) in parsed {
                    resolvedByKey[key] = value
                }
                lock.unlock()
            }
        }
        group.wait()

        guard !resolvedByKey.isEmpty else {
            return updated
        }

        updated.updateFrames { frame in
            if frame.isSymbolicated {
                return frame
            }
            guard let uuid = CrashUUID.normalize(frame.imageUUID) else {
                return frame
            }
            return resolvedByKey[FrameKey(uuid: uuid, address: frame.address)] ?? frame
        }

        return updated
    }

    static func parseAtosOutput(_ output: String, frame: StackFrame) -> StackFrame {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return frame
        }

        // atos echoes the bare load-adjusted address when it cannot resolve a
        // symbol — keep the frame unresolved instead of storing hex garbage
        // that would count as "symbolicated".
        if AtosPatterns.unresolvedAddress.firstMatch(
            in: trimmed,
            range: NSRange(trimmed.startIndex..., in: trimmed)
        ) != nil {
            return frame
        }

        if let match = AtosPatterns.sourceLine.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let symbolRange = Range(match.range(at: 1), in: trimmed),
           let fileRange = Range(match.range(at: 2), in: trimmed),
           let lineRange = Range(match.range(at: 3), in: trimmed)
        {
            var resolved = frame
            resolved.symbol = String(trimmed[symbolRange])
            resolved.sourceFile = String(trimmed[fileRange])
            resolved.sourceLine = Int(trimmed[lineRange])
            return resolved
        }

        if let match = AtosPatterns.plusOffset.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let symbolRange = Range(match.range(at: 1), in: trimmed),
           let offsetRange = Range(match.range(at: 2), in: trimmed)
        {
            var resolved = frame
            resolved.symbol = String(trimmed[symbolRange])
            resolved.symbolLocation = Int(trimmed[offsetRange])
            return resolved
        }

        if let match = AtosPatterns.inImage.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let symbolRange = Range(match.range(at: 1), in: trimmed)
        {
            var resolved = frame
            resolved.symbol = String(trimmed[symbolRange])
            return resolved
        }

        var resolved = frame
        resolved.symbol = trimmed
        return resolved
    }
}

private enum AtosPatterns {
    static let sourceLine = try! NSRegularExpression(
        pattern: #"^(.+?) \(in .+\) \((.+):(\d+)\)$"#
    )
    static let plusOffset = try! NSRegularExpression(
        pattern: #"^(.+?) \+ (\d+)$"#
    )
    static let inImage = try! NSRegularExpression(
        pattern: #"^(.+?) \(in .+\)$"#
    )
    /// atos unresolved output: the address it was asked to resolve, e.g. `0x1023c4a20`.
    static let unresolvedAddress = try! NSRegularExpression(
        pattern: #"^0[xX][0-9A-Fa-f]+$"#
    )
}
