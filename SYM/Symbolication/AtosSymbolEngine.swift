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
    func symbolicate(_ report: CrashReport, dsymPaths: [String: String]) async -> CrashReport {
        var updated = report
        let imagesByUUID = CrashUUID.imagesByUUID(report.binaryImages)

        var framesByUUID = [String: [StackFrame]]()
        for frame in updated.allFrames where !frame.isSymbolicated {
            if let uuid = CrashUUID.normalize(frame.imageUUID) {
                framesByUUID[uuid, default: []].append(frame)
            }
        }

        var resolvedByAddress = [UInt64: StackFrame]()

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
            guard let results = SubProcess.atos(
                loadAddress: loadAddress.crashHexString,
                addresses: addresses,
                dsym: dwarfPath,
                arch: arch
            ) else {
                continue
            }

            for (frame, output) in zip(frames, results) {
                var resolved = parseAtosOutput(output, frame: frame)
                if updated.needsUmengAddressFix, let load = image.loadAddress {
                    resolved = applyUmengAddressFix(resolved, loadAddress: load)
                }
                resolvedByAddress[frame.address] = resolved
            }
        }

        guard !resolvedByAddress.isEmpty else {
            return updated
        }

        updated.updateFrames { frame in
            if frame.isSymbolicated {
                return frame
            }
            return resolvedByAddress[frame.address] ?? frame
        }

        return updated
    }

    private func parseAtosOutput(_ output: String, frame: StackFrame) -> StackFrame {
        var resolved = frame
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return frame
        }

        if let match = AtosPatterns.sourceLine.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let symbolRange = Range(match.range(at: 1), in: trimmed),
           let fileRange = Range(match.range(at: 2), in: trimmed),
           let lineRange = Range(match.range(at: 3), in: trimmed)
        {
            resolved.symbol = String(trimmed[symbolRange])
            resolved.sourceFile = String(trimmed[fileRange])
            resolved.sourceLine = Int(trimmed[lineRange])
            return resolved
        }

        if let match = AtosPatterns.plusOffset.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let symbolRange = Range(match.range(at: 1), in: trimmed),
           let offsetRange = Range(match.range(at: 2), in: trimmed)
        {
            resolved.symbol = String(trimmed[symbolRange])
            resolved.symbolLocation = Int(trimmed[offsetRange])
            return resolved
        }

        if let match = AtosPatterns.inImage.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let symbolRange = Range(match.range(at: 1), in: trimmed)
        {
            resolved.symbol = String(trimmed[symbolRange])
            return resolved
        }

        resolved.symbol = trimmed
        return resolved
    }

    private func applyUmengAddressFix(_ frame: StackFrame, loadAddress: UInt64) -> StackFrame {
        guard frame.address == loadAddress,
              let symbol = frame.symbol,
              symbol.hasPrefix("+")
        else {
            return frame
        }

        let parts = symbol.split(separator: " ")
        guard parts.count >= 2, let offset = Int(parts[1]) else {
            return frame
        }

        var fixed = frame
        fixed.address = loadAddress &+ UInt64(offset)
        fixed.symbol = "+ 0"
        fixed.symbolLocation = 0
        return fixed
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
}
