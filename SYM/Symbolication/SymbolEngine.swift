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

protocol SymbolEngine {
    func symbolicate(_ report: CrashReport, dsymPaths: [String: String]) async -> CrashReport
}

struct CompositeSymbolEngine: SymbolEngine {
    private let primary: SymbolEngine
    private let fallback: SymbolEngine

    init(
        primary: SymbolEngine = MachOSymbolEngine(),
        fallback: SymbolEngine = AtosSymbolEngine()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func symbolicate(_ report: CrashReport, dsymPaths: [String: String]) async -> CrashReport {
        let machOResult = await primary.symbolicate(report, dsymPaths: dsymPaths)
        guard hasUnresolvedFrames(in: machOResult) else {
            return machOResult
        }
        return await fallback.symbolicate(machOResult, dsymPaths: dsymPaths)
    }

    private func hasUnresolvedFrames(in report: CrashReport) -> Bool {
        report.allFrames.contains { !$0.isSymbolicated }
    }
}

extension CrashReport {
    func symbolicated(using engine: SymbolEngine, dsyms: [String: String]) async -> CrashReport {
        let before = self
        let originalContent = formattedContent
        var report = await engine.symbolicate(self, dsymPaths: dsyms)
        report.formattedContent = CrashFormatter.patchResolvedFrames(
            in: originalContent,
            before: before,
            after: report
        )
        report = CrashFormatter.format(report)
        return report
    }

    var allFrames: [StackFrame] {
        var frames = threads.flatMap(\.frames)
        if let lastExceptionBacktrace {
            frames.append(contentsOf: lastExceptionBacktrace)
        }
        return frames
    }

    mutating func updateFrames(_ transform: (StackFrame) -> StackFrame) {
        threads = threads.map { thread in
            var updated = thread
            updated.frames = thread.frames.map(transform)
            return updated
        }
        if var backtrace = lastExceptionBacktrace {
            backtrace = backtrace.map(transform)
            lastExceptionBacktrace = backtrace
        }
    }
}
