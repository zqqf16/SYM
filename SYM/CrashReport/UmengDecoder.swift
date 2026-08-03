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

struct UmengDecoder: CrashDecoder {
    static func match(_ content: String) -> Bool {
        content.contains("dSYM UUID") && content.contains("Slide Address")
    }

    func decode(_ content: String) -> CrashReport {
        var report = CrashReport(rawContent: content, needsUmengAddressFix: true)

        let regexMap: [TextCrashParser.KeyPath: Regex] = [
            \.appName: CrashRegex.binaryImage,
            \.uuid: CrashRegex.dsymUUID,
            \.arch: CrashRegex.cpuType,
        ]
        TextCrashParser.parseBaseInfo(content, report: &report, map: regexMap)

        guard let appName = report.appName,
              let frameRegex = CrashRegex.frame(for: appName)
        else {
            return report
        }

        let loadAddress = CrashRegex.slideAddress.crashValue(in: content)?.crashHexAddress
        var frames: [StackFrame] = []

        frameRegex.matches(in: content)?.forEach { match in
            guard let captures = match.captures,
                  let indexString = captures.crashCapture(1),
                  let imageName = captures.crashCapture(2),
                  let addressString = captures.crashCapture(3),
                  let address = addressString.crashHexAddress
            else {
                return
            }

            report.appBacktraceRanges.append(match.range)
            frames.append(
                StackFrame(
                    index: Int(indexString) ?? frames.count,
                    imageName: imageName,
                    address: address,
                    loadAddress: loadAddress,
                    symbol: captures.crashCapture(4)
                )
            )
        }

        let fakePath = "/var/containers/Bundle/Application/\(appName)"
        let binary = BinaryImage(
            name: appName,
            uuid: report.uuid,
            arch: report.arch,
            loadAddress: loadAddress,
            path: fakePath,
            isExecutable: true,
            inApp: true
        )
        report.binaryImages = [binary]
        report.threads = [
            CrashThread(index: 0, name: nil, queue: nil, crashed: true, frames: frames),
        ]
        report.crashedThreadIndex = 0

        return report
    }
}
