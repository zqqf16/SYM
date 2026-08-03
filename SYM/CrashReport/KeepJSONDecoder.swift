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

struct KeepJSONDecoder: CrashDecoder {
    static func match(_ content: String) -> Bool {
        guard let payload = parseJSONObject(content) else {
            return false
        }
        return payload["trace"] != nil
            && payload["app_package_name"] != nil
            && (payload["trace"] as? [String: Any])?["threads"] != nil
    }

    func decode(_ content: String) -> CrashReport {
        guard let payload = Self.parseJSONObject(content) else {
            return AppleTextDecoder().decode(content)
        }

        let trace = payload["trace"] as? [String: Any] ?? [:]
        let system = trace["systemMsg"] as? [String: Any] ?? [:]
        let errorMsg = trace["errorMsg"] as? [String: Any] ?? [:]
        let mach = errorMsg["mach"] as? [String: Any] ?? [:]
        let signal = errorMsg["signal"] as? [String: Any] ?? [:]

        let appName = system["CFBundleExecutable"] as? String
        let binaryImages = parseImages(from: payload, appName: appName, arch: parseArch(from: payload))
        let threads = parseThreads(trace["threads"] as? [[String: Any]] ?? [])
        let lastExceptionBacktrace = parseKeyStack(payload["key_stack"] as? [[String: Any]] ?? [])
        let crashedThreadIndex = parseCrashedThreadIndex(from: payload)

        var report = CrashReport(
            rawContent: content,
            appName: appName,
            device: system["machine"] as? String,
            bundleID: system["CFBundleIdentifier"] as? String,
            arch: system["cpu_arch"] as? String,
            uuid: binaryImages.first(where: \.isExecutable)?.uuid,
            osVersion: formatOSVersion(system),
            appVersion: formatAppVersion(system),
            binaryImages: binaryImages,
            threads: threads,
            lastExceptionBacktrace: lastExceptionBacktrace,
            crashedThreadIndex: crashedThreadIndex,
            exceptionType: formatExceptionType(mach: mach, signal: signal),
            exceptionCodes: formatExceptionCodes(mach: mach)
        )

        report.formattedContent = CrashFormatter.formatKeepJSON(report: report, payload: payload)
        CrashHighlightParser.applyRanges(to: &report, frameRegex: { CrashRegex.frame(for: $0) })
        return report
    }

    private static func parseJSONObject(_ content: String) -> [String: Any]? {
        guard let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return object
    }

    private func parseCrashedThreadIndex(from payload: [String: Any]) -> Int? {
        let threads = (payload["trace"] as? [String: Any])?["threads"] as? [[String: Any]] ?? []
        for thread in threads where thread["thread_type"] as? String == "Crashed" {
            if let index = thread["index"] as? Int {
                return index
            }
            if let indexString = thread["index"] as? String {
                return Int(indexString)
            }
        }
        return nil
    }

    private func parseImages(from payload: [String: Any], appName: String?, arch: String) -> [BinaryImage] {
        let threads = (payload["trace"] as? [String: Any])?["threads"] as? [[String: Any]] ?? []
        var map: [String: [String: Any]] = [:]
        for thread in threads {
            for frame in thread["thread_stack"] as? [[String: Any]] ?? [] {
                if let name = frame["image_name"] as? String {
                    map[name] = frame
                }
            }
        }

        return map.values.map { frame in
            let name = frame["image_name"] as? String ?? ""
            let isKey = frame["is_key"] as? Bool ?? false
            let path = isKey ? "/var/containers/Bundle/Application/\(name)" : "/"
            return BinaryImage(
                name: name,
                uuid: CrashUUID.normalize(frame["uuid"] as? String),
                arch: arch,
                loadAddress: (frame["address"] as? NSNumber)?.uint64Value,
                path: path,
                isExecutable: name == appName,
                inApp: BinaryImage.isInApp(path: path)
            )
        }
    }

    private func parseThreads(_ threads: [[String: Any]]) -> [CrashThread] {
        threads.map { thread in
            let index = thread["index"] as? Int ?? Int(thread["index"] as? String ?? "0") ?? 0
            let frames = parseThreadStack(thread["thread_stack"] as? [[String: Any]] ?? [])
            return CrashThread(
                index: index,
                name: thread["thread_name"] as? String ?? thread["name"] as? String,
                queue: thread["dispatch_queue"] as? String,
                crashed: thread["thread_type"] as? String == "Crashed",
                frames: frames
            )
        }
    }

    private func parseKeyStack(_ frames: [[String: Any]]) -> [StackFrame] {
        parseThreadStack(frames)
    }

    private func parseThreadStack(_ frames: [[String: Any]]) -> [StackFrame] {
        frames.enumerated().map { index, frame in
            let loadAddress = (frame["load_address"] as? NSNumber)?.uint64Value ?? 0
            let offset = (frame["address"] as? NSNumber)?.uint64Value ?? 0
            return StackFrame(
                index: index,
                imageName: frame["image_name"] as? String ?? "",
                address: loadAddress,
                imageOffset: offset,
                loadAddress: (frame["address"] as? NSNumber)?.uint64Value,
                symbol: parseSymbol(frame),
                sourceFile: frame["file_name"] as? String,
                sourceLine: frame["line_num"] as? Int
            )
        }
    }

    private func parseSymbol(_ frame: [String: Any]) -> String? {
        if let lineShowStr = frame["line_show_str"] as? String {
            let re = try! Regex("\\d+ \\d+ \\+ \\d+")
            if re.matches(in: lineShowStr) == nil {
                return lineShowStr
            }
        }

        if let symbol = frame["log_symbol_name"] as? String,
           !symbol.isEmpty,
           symbol != "<redacted>"
        {
            var value = symbol
            if let file = frame["file_name"] as? String, !file.isEmpty {
                value += " \(file): \(frame["line_num"] as? Int ?? 0)"
            }
            return value
        }

        let loadAddress = (frame["address"] as? NSNumber)?.uint64Value ?? 0
        let offset = frame["address"] as? Int ?? 0
        return "\(loadAddress.crashHexString) + \(offset)"
    }

    private func parseArch(from payload: [String: Any]) -> String {
        let arch = ((payload["trace"] as? [String: Any])?["systemMsg"] as? [String: Any])?["cpu_arch"] as? String ?? "arm64"
        return arch.contains("armv7") ? arch : "arm64"
    }

    private func formatOSVersion(_ system: [String: Any]) -> String? {
        let version = system["system_version"] as? String ?? ""
        let build = system["os_version"] as? String ?? ""
        if version.isEmpty {
            return nil
        }
        return "iPhone OS \(version) (\(build))"
    }

    private func formatAppVersion(_ system: [String: Any]) -> String? {
        let short = system["CFBundleShortVersionString"] as? String
        let build = system["CFBundleVersion"] as? String
        if let short, let build {
            return "\(short) (\(build))"
        }
        return short ?? build
    }

    private func formatExceptionType(mach: [String: Any], signal: [String: Any]) -> String? {
        let exception = mach["exception_name"] as? String ?? ""
        let signalName = signal["name"] as? String ?? ""
        if exception.isEmpty {
            return nil
        }
        return signalName.isEmpty ? exception : "\(exception) (\(signalName))"
    }

    private func formatExceptionCodes(mach: [String: Any]) -> String? {
        let code = mach["code"]
        let subcode = mach["subcode"]
        if code == nil, subcode == nil {
            return nil
        }
        return "\(code ?? "") \(subcode ?? "")"
    }
}
