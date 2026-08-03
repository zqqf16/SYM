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

struct CPUUsageDecoder: CrashDecoder {
    static func match(_ content: String) -> Bool {
        (content.contains("Wakeups limit") || content.contains("CPU limit"))
            && content.contains("Limit duration:")
    }

    func decode(_ content: String) -> CrashReport {
        var report = CrashReport(rawContent: content)

        let regexMap: [TextCrashParser.KeyPath: Regex] = [
            \.appName: CrashRegex.powerstats,
            \.device: CrashRegex.hardware,
            \.arch: CrashRegex.architecture,
            \.osVersion: CrashRegex.osVersion,
        ]
        TextCrashParser.parseBaseInfo(content, report: &report, map: regexMap)
        report.appVersion = parseAppVersion(content)

        let appPath = CrashRegex.path.crashValue(in: content)
        if let path = appPath,
           let regex = CrashRegex.image(withPath: path),
           let captures = regex.firstMatch(in: content)?.captures
        {
            report.uuid = captures[2].crashUUIDFormat()
        }

        TextCrashParser.parseBinaries(content, report: &report, regex: CrashRegex.cpuUsageImage) { captures in
            var name = captures[2]
            let binaryPath = captures[4].crashStrip()
            if let path = appPath, path == binaryPath {
                name = path.components(separatedBy: "/").last ?? name
            }
            return BinaryImage(
                name: name,
                uuid: captures[3].crashUUIDFormat(),
                arch: nil,
                loadAddress: captures[1].crashHexAddress,
                path: binaryPath,
                isExecutable: false,
                inApp: BinaryImage.isInApp(path: binaryPath)
            )
        }

        TextCrashParser.parseThreads(content, report: &report)
        CrashHighlightParser.applyRanges(to: &report, frameRegex: { CrashRegex.cpuUsageFrame(for: $0) })

        return report
    }

    private func parseAppVersion(_ content: String) -> String? {
        if let app = CrashRegex.appVersion.crashValue(in: content),
           let build = CrashRegex.buildVersion.crashValue(in: content)
        {
            return "\(app) (\(build))"
        }
        return CrashRegex.version.crashValue(in: content)
    }
}
