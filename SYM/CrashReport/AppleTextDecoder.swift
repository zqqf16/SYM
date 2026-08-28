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

struct AppleTextDecoder: CrashDecoder {
    static func match(_: String) -> Bool {
        true
    }

    func decode(_ content: String) -> CrashReport {
        var report = CrashReport(rawContent: content)

        let regexMap: [TextCrashParser.KeyPath: Regex] = [
            \.appName: CrashRegex.process,
            \.device: CrashRegex.hardware,
            \.bundleID: CrashRegex.identifier,
            \.osVersion: CrashRegex.osVersion,
            \.appVersion: CrashRegex.version,
        ]
        TextCrashParser.parseBaseInfo(content, report: &report, map: regexMap)

        ClassicCrashLineParser.parseBinaryImages(content, report: &report)
        ClassicCrashLineParser.applyMainBinaryMetadata(to: &report)
        ClassicCrashLineParser.parseThreads(content, report: &report)
        CrashHighlightParser.applyRanges(to: &report, frameRegex: { CrashRegex.frames(forBinaries: $0) })

        return report
    }
}
