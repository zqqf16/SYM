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

enum CrashFormatter {
    static func format(_ report: CrashReport) -> CrashReport {
        var updated = report
        // Never rebuild classic / already-rendered text from the frame model —
        // that drops headers, Binary Images, registers, and rich symbol text.
        // JSON decoders already synthesize formattedContent at decode time.
        CrashHighlightParser.applyRanges(to: &updated, frameRegex: { CrashRegex.frame(for: $0) })
        return updated
    }

    /// Replace stack-frame lines in-place when symbolication produced new symbols.
    /// Only rewrites the translated section — Full Report JSON is left untouched.
    static func patchResolvedFrames(
        in content: String,
        before: CrashReport,
        after: CrashReport
    ) -> String {
        let beforeFrames = before.allFrames
        let afterFrames = after.allFrames
        guard beforeFrames.count == afterFrames.count else {
            return content
        }

        var resolvedByAddress = [UInt64: StackFrame]()
        for (old, new) in zip(beforeFrames, afterFrames) {
            let changed = old.symbol != new.symbol
                || old.symbolLocation != new.symbolLocation
                || old.sourceFile != new.sourceFile
                || old.sourceLine != new.sourceLine
                || old.address != new.address
            guard changed, new.isSymbolicated else {
                continue
            }
            resolvedByAddress[old.address] = new
            resolvedByAddress[new.address] = new
        }

        guard !resolvedByAddress.isEmpty else {
            return content
        }

        let parts = content.crashSplitTranslatedAndFullReport()
        var lines = parts.translated.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            guard let match = CrashRegex.stackFrame.firstMatch(in: line),
                  let captures = match.captures,
                  let addressString = captures.crashCapture(3),
                  let address = addressString.crashHexAddress,
                  let frame = resolvedByAddress[address],
                  let symbolText = frame.symbolDescription,
                  let addressRange = match.range(at: 3)
            else {
                continue
            }
            // Keep the original index / image / address columns (spaces or tabs).
            // Replacing the whole line with `formattedLine` retargets the address
            // column under NSTextView’s tab stops and visibly shifts it left.
            let prefix = (line as NSString).substring(to: NSMaxRange(addressRange))
            lines[index] = prefix + " " + symbolText
        }
        var result = lines.joined(separator: "\n")
        if let appendix = parts.appendix {
            result += appendix
        }
        return result
    }

    /// Console.app-style “Translated Report” for modern JSON IPS.
    static func formatAppleIPS(
        report: CrashReport,
        header: [String: Any]?,
        payload: [String: Any]
    ) -> String {
        let bundleInfo = payload["bundleInfo"] as? [String: Any]
        let storeInfo = payload["storeInfo"] as? [String: Any]
        let osVersion = payload["osVersion"] as? [String: Any]
        let crashedThread = report.threads.first(where: \.crashed)
            ?? report.threads.first(where: { $0.index == report.crashedThreadIndex })

        var content = ""
        appendLine("-------------------------------------", to: &content)
        appendLine("Translated Report (Full Report Below)", to: &content)
        appendLine("-------------------------------------", to: &content)

        appendLine(
            "Process:             \(string(payload["procName"])) [\(string(payload["pid"]))]",
            to: &content
        )
        appendLine("Path:                \(string(payload["procPath"]))", to: &content)
        appendLine(
            "Identifier:          \(string(report.bundleID ?? payload["coalitionName"]))",
            to: &content
        )
        let shortVersion = nonEmpty(
            string(header?["app_version"]),
            string(bundleInfo?["CFBundleShortVersionString"])
        )
        let buildVersion = nonEmpty(
            string(header?["build_version"]),
            string(bundleInfo?["CFBundleVersion"])
        )
        appendLine("Version:             \(shortVersion) (\(buildVersion))", to: &content)
        if let tools = bundleInfo?["DTAppStoreToolsBuild"] as? String, !tools.isEmpty {
            appendLine("AppStoreTools:       \(tools)", to: &content)
        }
        if let variant = storeInfo?["applicationVariant"] as? String, !variant.isEmpty {
            appendLine("AppVariant:          \(variant)", to: &content)
        }
        let isBeta = (header?["is_beta"] as? NSNumber)?.boolValue == true
            || payload["isBeta"] as? Bool == true
            || storeInfo?["entitledBeta"] as? Bool == true
        if isBeta {
            appendLine("Beta:                YES", to: &content)
        }
        let codeType = nonEmpty(string(payload["cpuType"]), string(report.arch))
        appendLine(
            "Code Type:           \(codeType.isEmpty ? "ARM-64" : codeType) (Native)",
            to: &content
        )
        appendLine("Role:                \(string(payload["procRole"]))", to: &content)
        appendLine(
            "Parent Process:      \(string(payload["parentProc"])) [\(string(payload["parentPid"]))]",
            to: &content
        )
        appendLine(
            "Coalition:           \(string(payload["coalitionName"])) [\(string(payload["coalitionID"]))]",
            to: &content
        )
        if payload["userID"] != nil {
            appendLine("User ID:             \(string(payload["userID"]))", to: &content)
        }
        appendLine("", to: &content)

        appendLine("Date/Time:           \(string(payload["captureTime"]))", to: &content)
        appendLine("Launch Time:         \(string(payload["procLaunch"]))", to: &content)
        appendLine("Hardware Model:      \(string(payload["modelCode"]))", to: &content)
        let train = string(osVersion?["train"])
        let build = string(osVersion?["build"])
        let osFromPayload = build.isEmpty ? train : "\(train) (\(build))"
        let osText = nonEmpty(string(header?["os_version"]), osFromPayload)
        appendLine("OS Version:          \(osText)", to: &content)
        if let releaseType = osVersion?["releaseType"] as? String, !releaseType.isEmpty {
            appendLine("Release Type:        \(releaseType)", to: &content)
        }
        if let baseband = payload["basebandVersion"] as? String, !baseband.isEmpty {
            appendLine("Baseband Version:    \(baseband)", to: &content)
        }
        appendLine("", to: &content)

        if let betaID = storeInfo?["deviceIdentifierForVendor"] as? String, !betaID.isEmpty {
            appendLine("Beta Identifier:     \(betaID)", to: &content)
        }
        appendLine(
            "Incident Identifier: \(nonEmpty(string(header?["incident_id"]), string(payload["incident"])))",
            to: &content
        )
        appendLine("", to: &content)

        if let uptime = payload["uptime"] as? NSNumber {
            appendLine("Time Awake Since Boot: \(uptime.stringValue) seconds", to: &content)
            appendLine("", to: &content)
        }

        var triggered = "Triggered by Thread: \(string(payload["faultingThread"]))"
        if let queue = crashedThread?.queue, !queue.isEmpty {
            triggered += ", Dispatch Queue: \(queue)"
        }
        appendLine(triggered, to: &content)
        appendLine("", to: &content)

        if let exception = payload["exception"] as? [String: Any] {
            appendLine(
                "Exception Type:    \(string(exception["type"])) (\(string(exception["signal"])))",
                to: &content
            )
            appendLine(
                "Exception Codes:   \(formatExceptionCodes(exception))",
                to: &content
            )
        }

        if payload["isCorpse"] as? Bool == true {
            appendLine("Exception Note:  EXC_CORPSE_NOTIFY", to: &content)
        }

        if let termination = payload["termination"] as? [String: Any] {
            appendLine(
                "Termination Reason:  Namespace \(string(termination["namespace"])), Code \(string(termination["code"])), \(string(termination["indicator"]))",
                to: &content
            )
            if let byProc = termination["byProc"] as? String, !byProc.isEmpty {
                appendLine(
                    "Terminating Process: \(byProc) [\(string(termination["byPid"]))]",
                    to: &content
                )
            }
            if let details = termination["details"] as? [String], let first = details.first {
                appendLine(first, to: &content)
            }
        }

        if let asi = payload["asi"] as? [String: Any] {
            appendLine("", to: &content)
            appendLine("Application Specific Information:", to: &content)
            for (_, value) in asi {
                for item in value as? [String] ?? [] {
                    appendLine(item, to: &content)
                }
            }
        }

        if let ktriageinfo = payload["ktriageinfo"] as? String {
            appendLine("", to: &content)
            appendLine("Kernel Triage:", to: &content)
            appendLine(ktriageinfo, to: &content)
        }

        appendLine("", to: &content)
        appendLine("", to: &content)

        if let backtrace = report.lastExceptionBacktrace, !backtrace.isEmpty {
            appendLine("Last Exception Backtrace:", to: &content)
            for frame in backtrace {
                appendLine(frame.formattedLine, to: &content)
            }
            appendLine("", to: &content)
        }

        for thread in report.threads {
            content.append(threadSection(thread))
        }

        content.append(formatRegisters(payload))
        appendLine("", to: &content)

        appendLine("Binary Images:", to: &content)
        for image in report.binaryImages {
            appendLine(formatBinaryImage(image), to: &content)
        }

        if let vmSummary = payload["vmSummary"] as? String, !vmSummary.isEmpty {
            appendLine("", to: &content)
            appendLine("VM Region Info:", to: &content)
            appendLine(vmSummary, to: &content)
        }

        appendFullReport(raw: report.rawContent, to: &content)
        return content
    }

    static func formatKeepJSON(report: CrashReport, payload: [String: Any]) -> String {
        let trace = payload["trace"] as? [String: Any] ?? [:]
        let system = trace["systemMsg"] as? [String: Any] ?? [:]
        let errorMsg = trace["errorMsg"] as? [String: Any] ?? [:]
        let mach = errorMsg["mach"] as? [String: Any] ?? [:]
        let signal = errorMsg["signal"] as? [String: Any] ?? [:]
        let appStats = system["application_stats"] as? [String: Any] ?? [:]

        var content = ""
        appendLine("Incident Identifier: \(string(trace["uuid"]))", to: &content)
        appendLine("Hardware Model:      \(string(system["machine"]))", to: &content)
        appendLine("Process:             \(string(system["CFBundleExecutable"]))", to: &content)
        appendLine("Identifier:          \(string(system["CFBundleIdentifier"]))", to: &content)
        appendLine(
            "Version:             \(string(system["CFBundleShortVersionString"])) (\(string(system["CFBundleVersion"])))",
            to: &content
        )
        appendLine("Code Type:           \(string(system["cpu_arch"]))", to: &content)
        appendLine(
            appStats["application_in_foreground"] as? Bool == true
                ? "Role:                Foreground"
                : "Role:                Background",
            to: &content
        )
        appendLine("Coalition:           \(string(system["CFBundleIdentifier"]))", to: &content)
        appendLine("", to: &content)
        appendLine("Date/Time:           \(string(system["app_start_time"]))", to: &content)
        appendLine("Launch Time:         \(string(system["boot_time"]))", to: &content)
        appendLine(
            "OS Version:          iPhone OS \(string(system["system_version"])) (\(string(system["os_version"])))",
            to: &content
        )
        appendLine("Release Type:        User", to: &content)
        appendLine("Baseband Version:    2.23.02", to: &content)
        appendLine("Report Version:      104", to: &content)
        appendLine("", to: &content)
        appendLine(
            "Exception Type:  \(string(mach["exception_name"])) (\(string(signal["name"])))",
            to: &content
        )
        appendLine(
            "Exception Codes: \(string(mach["code"])) \(string(mach["subcode"]))",
            to: &content
        )
        appendLine("Termination Reason: \(string(trace["crash_info_message"]))", to: &content)
        appendLine(string(trace["diagnosis"]), to: &content)
        appendLine("", to: &content)
        if let index = report.crashedThreadIndex {
            appendLine("Triggered by Thread:  \(index)", to: &content)
        }
        appendLine("", to: &content)

        appendLine("Last Exception Backtrace", to: &content)
        for frame in report.lastExceptionBacktrace ?? [] {
            appendLine(frame.formattedLine, to: &content)
        }

        appendLine("", to: &content)
        for thread in report.threads {
            content.append(keepThreadSection(thread))
        }

        appendLine("Binary Images:", to: &content)
        for image in report.binaryImages {
            appendLine(formatBinaryImage(image), to: &content)
        }
        appendFullReport(raw: report.rawContent, to: &content)
        return content
    }

    /// Console.app-style original payload appendix (excluded from parse / symbolicate patching).
    private static func appendFullReport(raw: String, to content: inout String) {
        guard !raw.isEmpty else {
            return
        }
        if !content.hasSuffix("\n") {
            content.append("\n")
        }
        appendLine("-----------", to: &content)
        appendLine("Full Report", to: &content)
        appendLine("-----------", to: &content)
        appendLine("", to: &content)
        content.append(raw)
        if !raw.hasSuffix("\n") {
            content.append("\n")
        }
    }

    private static func appendLine(_ line: String, to content: inout String) {
        content.append(line)
        content.append("\n")
    }

    private static func threadSection(_ thread: CrashThread) -> String {
        var lines: [String] = []

        if let name = thread.name {
            if let queue = thread.queue {
                lines.append("Thread \(thread.index) name:  \(name) Dispatch queue: \(queue)")
            } else {
                lines.append("Thread \(thread.index) name:  \(name)")
            }
        } else if let queue = thread.queue {
            lines.append("Thread \(thread.index) name:   Dispatch queue: \(queue)")
        }

        if thread.crashed {
            lines.append("Thread \(thread.index) Crashed:")
        } else {
            lines.append("Thread \(thread.index):")
        }

        for frame in thread.frames {
            lines.append(frame.formattedLine)
        }

        return lines.joined(separator: "\n") + "\n\n"
    }

    private static func keepThreadSection(_ thread: CrashThread) -> String {
        var lines: [String] = []

        if let name = thread.name {
            lines.append("Thread \(thread.index) name:  \(name)")
        } else if let queue = thread.queue {
            lines.append("Thread \(thread.index) name:   Dispatch queue: \(queue)")
        }

        let suffix = thread.crashed ? "Crashed:" : ":"
        lines.append("Thread \(thread.index) \(suffix)")
        for frame in thread.frames {
            lines.append(frame.formattedLine)
        }

        return lines.joined(separator: "\n") + "\n\n"
    }

    private static func formatBinaryImage(_ image: BinaryImage) -> String {
        let base = image.loadAddress ?? 0
        let size = image.size ?? 0
        // Avoid UInt64 overflow when size is 0 or base+size exceeds .max
        let end: UInt64 = size == 0 ? base : base &+ (size &- 1)
        let uuid = (image.uuid ?? "").replacingOccurrences(of: "-", with: "").lowercased()
        // Console.app padding: leading spaces + wide end-address column.
        return String(
            format: "       0x%llx -        0x%llx %@ %@  <%@> %@",
            base,
            end,
            image.name,
            image.arch ?? "arm64",
            uuid,
            image.path ?? ""
        )
    }

    private static func formatRegisters(_ payload: [String: Any]) -> String {
        let threads = payload["threads"] as? [[String: Any]] ?? []
        guard let triggeredThread = threads.first(where: { $0["triggered"] as? Bool == true }) else {
            return ""
        }

        let triggeredIndex = payload["faultingThread"] as? Int ?? 0
        var content = "Thread \(triggeredIndex) crashed with ARM Thread State (64-bit):\n"

        let threadState = triggeredThread["threadState"] as? [String: Any] ?? [:]
        let x = threadState["x"] as? [[String: Any]] ?? []
        for (index, reg) in x.enumerated() {
            let id = "x\(index)".crashPadding(length: 5, atLeft: true)
            let value = (reg["value"] as? NSNumber)?.uint64Value ?? 0
            content.append(" \(id): \(String(format: "0x%016llx", value))")
            if index % 4 == 3 {
                content.append("\n")
            }
        }

        let named: [(String, String)] = [
            ("fp", "fp"), ("lr", "lr"), ("sp", "sp"), ("pc", "pc"),
            ("cpsr", "cpsr"), ("far", "far"), ("esr", "esr"),
        ]
        var column = x.count % 4
        for (key, label) in named {
            let reg = threadState[key] as? [String: Any] ?? [:]
            let value = (reg["value"] as? NSNumber)?.uint64Value ?? 0
            let desc = reg["description"] as? String ?? ""
            let id = label.crashPadding(length: 5, atLeft: true)
            content.append(" \(id): \(String(format: "0x%016llx", value))")
            if !desc.isEmpty {
                content.append(" \(desc)")
            }
            column += 1
            if key == "lr" || key == "cpsr" || key == "esr" || column % 4 == 0 {
                content.append("\n")
                column = 0
            }
        }
        if !content.hasSuffix("\n") {
            content.append("\n")
        }
        return content
    }

    private static func formatExceptionCodes(_ exception: [String: Any]) -> String {
        if let rawCodes = exception["rawCodes"] as? [Any], rawCodes.count >= 2 {
            let values = rawCodes.prefix(2).map { value -> String in
                let number = (value as? NSNumber)?.uint64Value
                    ?? UInt64("\(value)")
                    ?? 0
                return String(format: "0x%016llx", number)
            }
            return values.joined(separator: ", ")
        }
        return string(exception["codes"])
    }

    private static func string(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let int as Int:
            return String(int)
        case let int64 as Int64:
            return String(int64)
        default:
            return ""
        }
    }

    private static func nonEmpty(_ primary: String, _ fallback: @autoclosure () -> String) -> String {
        primary.isEmpty ? fallback() : primary
    }
}
