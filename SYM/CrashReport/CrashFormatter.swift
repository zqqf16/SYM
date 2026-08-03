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
        if updated.formattedContent == updated.rawContent, !report.threads.isEmpty {
            updated.formattedContent = formatStructured(report)
        }
        CrashHighlightParser.applyRanges(to: &updated, frameRegex: { CrashRegex.frame(for: $0) })
        return updated
    }

    static func formatAppleIPS(
        report: CrashReport,
        header: [String: Any]?,
        payload: [String: Any]
    ) -> String {
        var content = ""
        appendLine("Incident Identifier: \(string(header?["incident_id"]))", to: &content)
        appendLine("CrashReporter Key:   \(string(payload["crashReporterKey"]))", to: &content)
        appendLine("Hardware Model:      \(string(payload["modelCode"]))", to: &content)
        appendLine("Process:             \(string(payload["procName"])) [\(string(payload["pid"]))]", to: &content)
        appendLine("Path:                \(string(payload["procPath"]))", to: &content)
        appendLine("Identifier:          \(string(payload["coalitionName"]))", to: &content)
        appendLine(
            "Version:             \(string(header?["app_version"])) (\(string(header?["build_version"])))",
            to: &content
        )
        appendLine("Code Type:           \(string(payload["cpuType"]))", to: &content)
        appendLine("Role:                \(string(payload["procRole"]))", to: &content)
        appendLine(
            "Parent Process:      \(string(payload["parentProc"])) [\(string(payload["parentPid"]))]",
            to: &content
        )
        appendLine(
            "Coalition:           \(string(payload["coalitionName"])) [\(string(payload["coalitionID"]))]",
            to: &content
        )
        appendLine("", to: &content)
        appendLine("Date/Time:           \(string(payload["captureTime"]))", to: &content)
        appendLine("Launch Time:         \(string(payload["procLaunch"]))", to: &content)
        appendLine("OS Version:          \(string(header?["os_version"]))", to: &content)
        appendLine(
            "Release Type:        \(string((payload["osVersion"] as? [String: Any])?["releaseType"]))",
            to: &content
        )
        appendLine("Baseband Version:    \(string(payload["basebandVersion"]))", to: &content)
        appendLine("Report Version:      104", to: &content)
        appendLine("", to: &content)

        if let exception = payload["exception"] as? [String: Any] {
            appendLine(
                "Exception Type:  \(string(exception["type"])) (\(string(exception["signal"])))",
                to: &content
            )
            appendLine("Exception Codes: \(string(exception["codes"]))", to: &content)
        }

        if payload["isCorpse"] as? Bool == true {
            appendLine("Exception Note:  EXC_CORPSE_NOTIFY", to: &content)
        }

        if let termination = payload["termination"] as? [String: Any] {
            appendLine(
                "Termination Reason: \(string(termination["namespace"])) \(string(termination["code"]))",
                to: &content
            )
            if let details = termination["details"] as? [String], let first = details.first {
                appendLine(first, to: &content)
            }
        }

        appendLine("Triggered by Thread:  \(string(payload["faultingThread"]))", to: &content)

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
            appendLine("Kernel Triage: \n\(ktriageinfo)", to: &content)
        }

        appendLine("", to: &content)

        if let backtrace = report.lastExceptionBacktrace, !backtrace.isEmpty {
            appendLine("", to: &content)
            appendLine("Last Exception Backtrace:", to: &content)
            for frame in backtrace {
                appendLine(frame.formattedLine, to: &content)
            }
            appendLine("", to: &content)
        }

        for thread in report.threads {
            content.append(threadSection(thread))
        }

        appendLine("", to: &content)
        content.append(formatRegisters(payload))
        appendLine("", to: &content)

        if let vmSummary = payload["vmSummary"] as? String {
            appendLine("", to: &content)
            appendLine("VM Region Info: \n\(vmSummary)", to: &content)
        }

        appendLine("", to: &content)
        appendLine("Binary Images:", to: &content)
        for image in report.binaryImages {
            appendLine(formatBinaryImage(image), to: &content)
        }
        appendLine("", to: &content)
        appendLine("EOF", to: &content)
        appendLine("", to: &content)
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
        appendLine("", to: &content)
        appendLine("EOF", to: &content)
        appendLine("", to: &content)
        return content
    }

    private static func formatStructured(_ report: CrashReport) -> String {
        var content = ""
        if let appName = report.appName {
            appendLine("Process:             \(appName)", to: &content)
        }
        if let device = report.device {
            appendLine("Hardware Model:      \(device)", to: &content)
        }
        if let bundleID = report.bundleID {
            appendLine("Identifier:          \(bundleID)", to: &content)
        }
        if let appVersion = report.appVersion {
            appendLine("Version:             \(appVersion)", to: &content)
        }
        if let osVersion = report.osVersion {
            appendLine("OS Version:          \(osVersion)", to: &content)
        }
        appendLine("", to: &content)

        if let exceptionType = report.exceptionType {
            appendLine("Exception Type:  \(exceptionType)", to: &content)
        }
        if let exceptionCodes = report.exceptionCodes {
            appendLine("Exception Codes: \(exceptionCodes)", to: &content)
        }
        if let index = report.crashedThreadIndex {
            appendLine("Triggered by Thread:  \(index)", to: &content)
        }
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

        if !report.binaryImages.isEmpty {
            appendLine("", to: &content)
            appendLine("Binary Images:", to: &content)
            for image in report.binaryImages {
                appendLine(formatBinaryImage(image), to: &content)
            }
        }
        appendLine("", to: &content)
        appendLine("EOF", to: &content)
        appendLine("", to: &content)
        return content
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
        let end = base + (image.size ?? 0) - (image.size == nil ? 0 : 1)
        let uuid = (image.uuid ?? "").replacingOccurrences(of: "-", with: "")
        return String(format: "0x%llx - 0x%llx ", base, end)
            + String(format: "%@ %@ ", image.name, image.arch ?? "arm64")
            + String(format: "<%@> %@", uuid, image.path ?? "")
    }

    private static func formatRegisters(_ payload: [String: Any]) -> String {
        let threads = payload["threads"] as? [[String: Any]] ?? []
        guard let triggeredThread = threads.first(where: { $0["triggered"] as? Bool == true }) else {
            return ""
        }

        let triggeredIndex = payload["faultingThread"] as? Int ?? 0
        let cpu = payload["cpuType"] as? String ?? ""
        var content = "Thread \(triggeredIndex) crashed with ARM Thread State (\(cpu)):\n"

        let threadState = triggeredThread["threadState"] as? [String: Any] ?? [:]
        let x = threadState["x"] as? [[String: Any]] ?? []
        for (index, reg) in x.enumerated() {
            let id = "x\(index)".crashPadding(length: 6, atLeft: true)
            let value = (reg["value"] as? NSNumber)?.uint64Value ?? 0
            content.append("\(id): \(String(format: "0x%016X", value))")
            if index % 4 == 3 {
                content.append("\n")
            }
        }

        var registerIndex = x.count % 4
        for name in ["fp", "lr", "sp", "pc", "cpsr", "far", "esr"] {
            let reg = threadState[name] as? [String: Any] ?? [:]
            let value = (reg["value"] as? NSNumber)?.uint64Value ?? 0
            let desc = reg["description"] as? String ?? ""
            let id = name.crashPadding(length: 6, atLeft: true)
            content.append("\(id): \(String(format: "0x%016X", value))")
            if !desc.isEmpty {
                content.append(" \(desc)")
            }
            if registerIndex % 3 == 2 {
                content.append("\n")
            }
            registerIndex += 1
        }
        content.append("\n")
        return content
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
}
