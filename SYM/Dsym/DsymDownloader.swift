// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
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

import Cocoa
import Combine

class DsymDownloadTask {
    var crashInfo: CrashReport

    enum Status {
        case waiting
        case running
        case canceled
        case failed(code: Int, message: String?)
        case success

        func shouldRetry() -> Bool {
            switch self {
            case .waiting, .running:
                return false
            default:
                return true
            }
        }
    }

    struct Progress {
        var percentage: Int = 0
        var totalSize: String = "0"
        var downloadedSize: String = "0"
        var timeLeft: String = "Unknow"
        var speed: String = "0"

        mutating func update(fromConsoleOutput output: String) {
            /*
             curl
             % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
             Dload  Upload   Total   Spent    Left  Speed
             10  286M   10 30.2M    0     0   830k      0  0:05:53  0:00:37  0:05:16 1660k
             */
            let title = "% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current"
            guard let range = output.range(of: title) else {
                return
            }

            let content = output[range.upperBound...]
            let lines = content.components(separatedBy: "\r")
            let count = lines.count
            if count < 3 {
                return
            }

            var items: [String] = []
            for index in (count - 2 ..< count).reversed() {
                let lastLine = lines[index]
                items = lastLine.components(separatedBy: " ").filter { string -> Bool in
                    string != ""
                }
                if items.count >= 12 {
                    break
                }
            }

            if items.count != 12 || !items[10].contains(":") {
                return
            }

            percentage = Int(items[0]) ?? 0
            totalSize = items[1]
            downloadedSize = items[3]
            timeLeft = items[10]
            speed = items[11]
        }
    }

    @Published var status: Status = .waiting
    @Published var progress: Progress = .init()

    var statusCode: Int = 0
    var message: String?
    var dsymFiles: [DsymFile]?

    /// Guards `process` / `isCanceled`: `run()` executes on a global queue while
    /// `cancel()` comes from the main thread.
    private let stateLock = NSLock()
    private var isCanceled = false
    private var process: SubProcess?
    private var fileURL: URL?
    private let scriptURL: URL
    /// curl progress chunks arrive on the subprocess IO queue; accumulate on a
    /// serial queue and publish the parsed value on the main thread.
    private let progressQueue = DispatchQueue(label: "im.zorro.SYM.download.progress", qos: .userInitiated)
    private var progressOutput = ""

    init(crashInfo: CrashReport, scriptURL: URL, fileURL: URL?) {
        self.crashInfo = crashInfo
        self.fileURL = fileURL
        self.scriptURL = scriptURL
    }

    /// `@Published` is not thread-safe: every write hops to the main thread so
    /// `run()` (global queue) and `cancel()` (caller thread) can't race.
    private func publishStatus(_ newStatus: Status) {
        if Thread.isMainThread {
            status = newStatus
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.status = newStatus
            }
        }
    }

    func run() {
        let ownsTemporaryCrashFile = fileURL == nil
        let crashPath = fileURL?.path ?? FileManager.default.temporaryPath()
        defer {
            stateLock.lock()
            process = nil
            stateLock.unlock()
            if ownsTemporaryCrashFile {
                try? FileManager.default.removeItem(atPath: crashPath)
            }
        }

        do {
            try crashInfo.formattedContent.write(toFile: crashPath, atomically: true, encoding: .utf8)
        } catch {
            statusCode = -1001
            publishStatus(.failed(code: statusCode, message: "Failed to save file"))
            return
        }

        let dir = Config.dsymDownloadDirectory
        let env = crashInfoToEnv(crashInfo)
        let task = SubProcess(cmd: scriptURL.path, args: [crashPath, dir], env: env)
        task.errorHandler = { [weak self] chunk in
            self?.consumeProgressChunk(chunk)
        }
        stateLock.lock()
        process = task
        stateLock.unlock()

        publishStatus(.running)
        task.run()

        // A cancel mid-run terminates the script; don't let the completion path
        // overwrite `.canceled` with `.failed` / `.success`.
        stateLock.lock()
        let canceled = isCanceled
        stateLock.unlock()
        if canceled {
            return
        }

        parse(output: task.output)
        statusCode = task.exitCode
        message = task.output

        if statusCode != 0 {
            publishStatus(.failed(code: statusCode, message: message))
        } else {
            publishStatus(.success)
        }
    }

    func cancel() {
        stateLock.lock()
        isCanceled = true
        let task = process
        stateLock.unlock()
        task?.terminate()
        publishStatus(.canceled)
    }

    private func consumeProgressChunk(_ chunk: String) {
        guard !chunk.isEmpty else {
            return
        }
        progressQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.progressOutput += chunk
            var value = Progress()
            value.update(fromConsoleOutput: self.progressOutput)
            DispatchQueue.main.async { [weak self] in
                self?.progress = value
            }
        }
    }

    private func crashInfoToEnv(_ crashInfo: CrashReport) -> [String: String] {
        var env: [String: String] = [:]
        env["APP_NAME"] = crashInfo.appName ?? ""
        env["UUID"] = crashInfo.uuid ?? ""
        env["BUNDLE_ID"] = crashInfo.bundleID ?? ""

        let versionString = crashInfo.appVersion ?? ""
        env["APP_VERSION"] = versionString

        // compatible with older versions
        // convert 1.1.1 (123) to 123 (1.1.1)
        let components = versionString.components(separatedBy: " ")
        if components.count == 2 {
            let part1 = components[0]
            let part2 = components[1].replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            if part1.contains("."), !part2.contains(".") {
                env["APP_VERSION"] = "\(part2) (\(part1))"
            }
        }

        return env
    }

    private func parse(output: String) {
        guard let matches = Regex.dwarfdump.matches(in: output) else {
            return
        }

        var uuids: [String] = []
        if let main = CrashUUID.normalize(crashInfo.uuid) {
            uuids.append(main)
        }
        if !crashInfo.embeddedBinaries.isEmpty {
            uuids = crashInfo.embeddedBinaries.compactMap { CrashUUID.normalize($0.uuid) }
        }
        let needed = Set(uuids)

        var dsymFiles: [DsymFile] = []
        for match in matches {
            guard let captures = match.captures, captures.count >= 3 else {
                continue
            }
            // captures[0] = full match; UUID/path are groups 1/2.
            guard let uuid = CrashUUID.normalize(captures[1]), needed.contains(uuid) else {
                continue
            }
            let path = captures[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                continue
            }
            var name = ""
            for component in path.components(separatedBy: "/") {
                if component.hasSuffix(".dSYM") {
                    name = component
                    break
                }
            }
            let binaryPath = DsymLocator.resolveDwarfBinaryPath(from: path) ?? path
            let file = DsymFile(
                name: name.isEmpty ? (path as NSString).lastPathComponent : name,
                path: path,
                binaryPath: binaryPath,
                uuids: [uuid],
                isApp: uuid == CrashUUID.normalize(crashInfo.uuid)
            )
            dsymFiles.append(file)
        }
        self.dsymFiles = dsymFiles
    }
}

class DsymDownloader {
    static let shared = DsymDownloader()

    @Published var tasks: [String: DsymDownloadTask] = [:]
    let scriptURL = Config.downloadScriptURL

    init() {
        prepareDownloadScript()
    }

    func prepareDownloadScript() {
        let scriptPath = scriptURL.path
        let fileManager = FileManager.default

        // Empty / comment-only files are not a real script — remove them.
        if Config.sanitizeDownloadScriptFile() {
            fileManager.chmod(scriptPath, permissions: 0o700)
            return
        }

        // Optional build-time bundled download.sh (BUILDIN_DOWNLOAD_SCRIPT_PATH).
        if let buildinPath = Bundle.main.path(forResource: "download", ofType: "sh") {
            fileManager.cp(fromPath: buildinPath, toPath: scriptPath)
            if Config.sanitizeDownloadScriptFile() {
                fileManager.chmod(scriptPath, permissions: 0o700)
            }
        }
    }

    func canDownload() -> Bool {
        prepareDownloadScript()
        guard Config.sanitizeDownloadScriptFile() else {
            return false
        }
        return FileManager.default.chmod(scriptURL.path, permissions: 0o700)
    }

    /// Tooltip for toolbar / dSYM Download controls.
    /// Uses sanitize only — do not call `prepareDownloadScript` here, or toolbar
    /// validation would reinstall a bundled download.sh after the user removed it.
    static var downloadActionToolTip: String {
        if Config.isDownloadScriptConfigured() {
            return NSLocalizedString("Download dSYM file", comment: "Download toolbar / button tooltip")
        }
        return NSLocalizedString(
            "Configure download script first…",
            comment: "Download toolbar / button tooltip when no script is configured"
        )
    }

    @discardableResult
    func download(crashInfo: CrashReport, fileURL: URL?) -> DsymDownloadTask? {
        guard let uuid = CrashUUID.normalize(crashInfo.uuid), canDownload() else {
            return nil
        }

        // Terminal tasks only ever get replaced on the next download — drop them
        // so they stop retaining crash reports and subprocess output forever.
        tasks = tasks.filter { !$0.value.status.shouldRetry() }

        if let task = tasks[uuid], !task.status.shouldRetry() {
            return task
        }

        let task = DsymDownloadTask(crashInfo: crashInfo, scriptURL: scriptURL, fileURL: fileURL)
        tasks[uuid] = task
        DispatchQueue.global().async {
            task.run()
        }

        return task
    }
}
