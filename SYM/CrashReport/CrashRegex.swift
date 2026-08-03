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

enum CrashRegex {
    static let stackFrame = try! Regex("^\\s*(\\d{1,3})\\s+([^ ]+)\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)", options: .anchorsMatchLines)
    static let image = try! Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+([^\\s]+)\\s*(\\w+)\\s*<(.*)> (.*)")
    static let thread = try! Regex("Thread (\\d{1,3})(?:[: ])(?:(?:(Crashed):)|(?:name:\\s+(.*)))*$")
    static let process = try! Regex("^Process:\\s*([^\\s]+)\\s*\\[*", options: .anchorsMatchLines)
    static let identifier = try! Regex("^Identifier:\\s*([^\\s]+)", options: .anchorsMatchLines)
    static let hardware = try! Regex("Hardware Model:\\s*([^\\s]+)", options: .caseInsensitive)
    static let uuid = try! Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", options: [.anchorsMatchLines, .caseInsensitive])
    static let threadCrashed = try! Regex("(?:^Thread \\d+.*\n)*^Thread \\d+ Crashed:\\s*\n(?:^\\s*\\d{1,3}.*\n)+", options: .anchorsMatchLines)
    static let osVersion = try! Regex("^OS Version:\\s*(.*)", options: .anchorsMatchLines)
    static let version = try! Regex("^Version:\\s*(.*)", options: .anchorsMatchLines)

    static let powerstats = try! Regex("^Powerstats for:\\s*([^\\s]+)\\s*\\[*", options: .anchorsMatchLines)
    static let architecture = try! Regex("^Architecture:\\s*([^\\s]+)\\s*", options: .anchorsMatchLines)
    static let appVersion = try! Regex("^App version:\\s*(.*)", options: .anchorsMatchLines)
    static let buildVersion = try! Regex("^Build version:\\s*(.*)", options: .anchorsMatchLines)
    static let path = try! Regex("^Path:\\s*([^\\s]+)\\s*", options: .anchorsMatchLines)
    static let cpuUsageImage = try! Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+[^\\s]+\\s+([^\\s]+).*\\s*<(.*)> (.*)")
    static let cpuUsageStackFrame = try! Regex("^.*[\\( ](.*) \\+ \\d+\\) \\[(0[xX][A-Fa-f0-9]+)\\].*", options: .anchorsMatchLines)

    static let hashDevice = try! Regex("^# Device:\\s*(.+)", options: .anchorsMatchLines)
    static let hashAppVersion = try! Regex("^# Version:\\s*(.+)", options: .anchorsMatchLines)
    static let hashPlatform = try! Regex("^# Platform:\\s*(.+)", options: .anchorsMatchLines)
    static let hashOSVersion = try! Regex("^# OS Version:\\s*([^\\(]+)", options: .anchorsMatchLines)
    static let hashBundleID = try! Regex("^# Bundle Identifier:\\s*(.*)", options: .anchorsMatchLines)

    static let binaryImage = try! Regex("Binary Image:\\s*([^\\s]+)")
    static let dsymUUID = try! Regex("dSYM UUID:\\s*([^\\s]+)")
    static let slideAddress = try! Regex("Slide Address:\\s*([^\\s]+)")
    static let cpuType = try! Regex("CPU Type:\\s*([^\\s]+)")

    static func frame(for binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        try? Regex("^\\s*(\\d{1,3})\\s+(\(binary))\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)", options: options)
    }

    static func image(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        try? Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+(\(binary))\\s*(\\w+)\\s*<(.*)>", options: options)
    }

    static func image(withPath path: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        try? Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-.*<(.*)>\\s+\(path)", options: options)
    }

    static func cpuUsageFrame(for binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        try? Regex("^\\s*\\d+.*(\(binary)).*\\[(0[xX][A-Fa-f0-9]+)\\].*", options: options)
    }
}

extension Regex {
    func crashValue(in string: String) -> String? {
        firstMatch(in: string)?.captures?[1]
    }
}

extension Array where Element == String {
    func crashCapture(_ index: Int) -> String? {
        guard index >= 0, index < count else {
            return nil
        }
        return self[index]
    }
}

enum CrashHighlightParser {
    static func applyRanges(to report: inout CrashReport, frameRegex: (String) -> Regex?) {
        let content = report.formattedContent

        if let match = CrashRegex.threadCrashed.firstMatch(in: content) {
            report.crashedThreadRange = match.range
        }

        report.appBacktraceRanges = []
        for binary in report.embeddedBinaries {
            guard let regex = frameRegex(binary.name) else {
                continue
            }
            regex.matches(in: content)?.forEach { match in
                report.appBacktraceRanges.append(match.range)
            }
        }
    }
}

enum TextCrashParser {
    typealias KeyPath = WritableKeyPath<CrashReport, String?>

    static func parseBaseInfo(_ content: String, report: inout CrashReport, map: [KeyPath: Regex]) {
        for (keyPath, regex) in map {
            if let value = regex.crashValue(in: content) {
                report[keyPath: keyPath] = value
            }
        }
    }

    static func parseBinaries(
        _ content: String,
        report: inout CrashReport,
        regex: Regex,
        convert: ([String]) -> BinaryImage
    ) {
        guard let images = regex.matches(in: content) else {
            return
        }

        for match in images {
            guard let captures = match.captures else {
                continue
            }
            var binary = convert(captures)
            binary.isExecutable = binary.name == report.appName
            report.binaryImages.append(binary)
        }
    }

    static func parseMainBinaryUUID(_ content: String, report: inout CrashReport) {
        guard let appName = report.appName,
              let imageRegex = CrashRegex.image(appName, options: []),
              let captures = imageRegex.firstMatch(in: content)?.captures,
              let uuid = captures.crashCapture(4),
              let arch = captures.crashCapture(3)
        else {
            return
        }

        report.uuid = uuid.crashUUIDFormat()
        report.arch = arch
    }

    static func parseThreads(_ content: String, report: inout CrashReport) {
        var threads: [CrashThread] = []
        var currentThread: CrashThread?
        var currentFrames: [StackFrame] = []

        for line in content.components(separatedBy: "\n") {
            if let match = CrashRegex.thread.firstMatch(in: line), let captures = match.captures,
               let indexString = captures.crashCapture(1)
            {
                if var thread = currentThread {
                    thread.frames = currentFrames
                    threads.append(thread)
                }

                let index = Int(indexString) ?? threads.count
                let crashed = captures.crashCapture(2) == "Crashed"
                let name = captures.crashCapture(3)
                currentThread = CrashThread(index: index, name: name, queue: nil, crashed: crashed, frames: [])
                currentFrames = []
                if crashed {
                    report.crashedThreadIndex = index
                }
                continue
            }

            if let match = CrashRegex.stackFrame.firstMatch(in: line), let captures = match.captures,
               let indexString = captures.crashCapture(1),
               let imageName = captures.crashCapture(2),
               let addressString = captures.crashCapture(3),
               let address = addressString.crashHexAddress
            {
                let frame = StackFrame(
                    index: Int(indexString) ?? currentFrames.count,
                    imageName: imageName,
                    address: address,
                    symbol: captures.crashCapture(4)
                )
                currentFrames.append(frame)
            }
        }

        if var thread = currentThread {
            thread.frames = currentFrames
            threads.append(thread)
        }

        report.threads = threads
    }
}
