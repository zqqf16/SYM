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
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

struct AppleIPSDecoder: CrashDecoder {
    static func match(_ content: String) -> Bool {
        if let components = split(content), components.payload != nil {
            return matchesPayload(components.payload!)
        }
        return matchesSingleJSON(content)
    }

    func decode(_ content: String) -> CrashReport {
        let components = Self.split(content) ?? (header: nil, payload: Self.parseJSONObject(content))
        guard let payload = components.payload else {
            return AppleTextDecoder().decode(content)
        }

        let usedImages = payload["usedImages"] as? [[String: Any]] ?? []
        let binaryImages = usedImages.map { parseBinaryImage($0, appName: payload["procName"] as? String) }
        let faultingThread = payload["faultingThread"] as? Int
        let legacyQueue = ((payload["legacyInfo"] as? [String: Any])?["threadTriggered"] as? [String: Any])?["queue"] as? String
        let threads = parseThreads(
            payload["threads"] as? [[String: Any]] ?? [],
            usedImages: usedImages,
            faultingThread: faultingThread,
            legacyQueue: legacyQueue
        )
        let lastExceptionBacktrace = parseFrames(
            payload["lastExceptionBacktrace"] as? [[String: Any]],
            usedImages: usedImages
        )

        let bundleInfo = payload["bundleInfo"] as? [String: Any]
        let header = components.header
        let appName = payload["procName"] as? String ?? header?["app_name"] as? String
        let mainBinary = binaryImages.first { $0.isExecutable }
            ?? binaryImages.first { $0.name == appName?.crashStrip() }
        // Prefer the real bundle id; coalitionName can differ for extensions / system helpers.
        let bundleID = (bundleInfo?["CFBundleIdentifier"] as? String)
            ?? (header?["bundleID"] as? String)
            ?? (payload["coalitionName"] as? String)

        var report = CrashReport(
            rawContent: content,
            appName: appName?.crashStrip(),
            device: payload["modelCode"] as? String,
            bundleID: bundleID,
            arch: CrashArch.normalize(payload["cpuType"] as? String) ?? mainBinary?.arch,
            uuid: mainBinary?.uuid,
            osVersion: header?["os_version"] as? String ?? formatOSVersion(payload["osVersion"] as? [String: Any]),
            appVersion: formatAppVersion(header: header, bundleInfo: bundleInfo),
            binaryImages: binaryImages,
            threads: threads,
            lastExceptionBacktrace: lastExceptionBacktrace,
            crashedThreadIndex: faultingThread ?? threads.first(where: \.crashed)?.index,
            exceptionType: formatExceptionType(payload["exception"] as? [String: Any]),
            exceptionCodes: (payload["exception"] as? [String: Any])?["codes"] as? String
        )

        report.formattedContent = CrashFormatter.formatAppleIPS(
            report: report,
            header: header,
            payload: payload
        )
        CrashHighlightParser.applyRanges(to: &report, frameRegex: { CrashRegex.frames(forBinaries: $0) })
        return report
    }

    private static func split(_ content: String) -> (header: [String: Any]?, payload: [String: Any]?)? {
        var lines = content.components(separatedBy: "\n")
        guard let firstLine = lines.first,
              let headerData = firstLine.data(using: .utf8),
              let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        else {
            return nil
        }

        lines.removeFirst()
        let body = lines.joined(separator: "\n")
        guard let bodyData = body.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        else {
            return (header, nil)
        }

        return (header, payload)
    }

    private static func matchesSingleJSON(_ content: String) -> Bool {
        guard let payload = parseJSONObject(content) else {
            return false
        }
        return payload["usedImages"] != nil && payload["threads"] != nil
    }

    private static func matchesPayload(_ payload: [String: Any]) -> Bool {
        if payload["usedImages"] != nil {
            return true
        }
        let hasIdentity = payload["coalitionName"] != nil || payload["crashReporterKey"] != nil
        return hasIdentity && payload["threads"] != nil
    }

    private static func parseJSONObject(_ content: String) -> [String: Any]? {
        guard let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return object
    }

    private func parseBinaryImage(_ image: [String: Any], appName: String?) -> BinaryImage {
        let base = (image["base"] as? NSNumber)?.uint64Value
        let size = (image["size"] as? NSNumber)?.uint64Value
        let path = image["path"] as? String
        let name = image["name"] as? String ?? ""
        return BinaryImage(
            name: name,
            uuid: CrashUUID.normalize(image["uuid"] as? String),
            arch: CrashArch.normalize(image["arch"] as? String),
            loadAddress: base,
            size: size,
            path: path,
            isExecutable: name == appName?.crashStrip(),
            inApp: BinaryImage.isInApp(path: path)
        )
    }

    private func parseThreads(
        _ threads: [[String: Any]],
        usedImages: [[String: Any]],
        faultingThread: Int?,
        legacyQueue: String?
    ) -> [CrashThread] {
        threads.enumerated().map { index, thread in
            let frames = parseFrames(thread["frames"] as? [[String: Any]], usedImages: usedImages) ?? []
            let crashed = thread["triggered"] as? Bool == true || index == faultingThread
            var queue = thread["queue"] as? String
            if crashed, (queue == nil || queue?.isEmpty == true) {
                queue = legacyQueue
            }
            return CrashThread(
                index: index,
                name: thread["name"] as? String,
                queue: queue,
                crashed: crashed,
                frames: frames
            )
        }
    }

    private func parseFrames(_ frames: [[String: Any]]?, usedImages: [[String: Any]]) -> [StackFrame]? {
        guard let frames else {
            return nil
        }

        return frames.enumerated().map { index, frame in
            let imageIndex = frame["imageIndex"] as? Int ?? 0
            let image = imageIndex < usedImages.count ? usedImages[imageIndex] : [:]
            let base = (image["base"] as? NSNumber)?.uint64Value ?? 0
            let offset = (frame["imageOffset"] as? NSNumber)?.uint64Value ?? 0
            let address = base &+ offset

            return StackFrame(
                index: index,
                imageName: image["name"] as? String ?? "",
                address: address,
                imageOffset: offset,
                loadAddress: base,
                imageUUID: CrashUUID.normalize(image["uuid"] as? String),
                symbol: frame["symbol"] as? String,
                symbolLocation: frame["symbolLocation"] as? Int,
                sourceFile: frame["sourceFile"] as? String,
                sourceLine: frame["sourceLine"] as? Int
            )
        }
    }

    private func formatOSVersion(_ osVersion: [String: Any]?) -> String? {
        guard let osVersion else {
            return nil
        }
        let train = osVersion["train"] as? String ?? ""
        let build = osVersion["build"] as? String ?? ""
        if train.isEmpty {
            return nil
        }
        return build.isEmpty ? train : "\(train) (\(build))"
    }

    private func formatAppVersion(header: [String: Any]?, bundleInfo: [String: Any]?) -> String? {
        let short = header?["app_version"] as? String ?? bundleInfo?["CFBundleShortVersionString"] as? String
        let build = header?["build_version"] as? String ?? bundleInfo?["CFBundleVersion"] as? String
        if let short, let build {
            return "\(short) (\(build))"
        }
        return short ?? build
    }

    private func formatExceptionType(_ exception: [String: Any]?) -> String? {
        guard let exception else {
            return nil
        }
        let type = exception["type"] as? String ?? ""
        let signal = exception["signal"] as? String ?? ""
        if type.isEmpty {
            return nil
        }
        return signal.isEmpty ? type : "\(type) (\(signal))"
    }
}
