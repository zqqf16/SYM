// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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
import Cocoa

extension Notification.Name {
    static let dsymDownloadStatusChanged = Notification.Name("sym.dsymDownloadStatusChanged")
}

class DsymDownloadTask {
    var crashInfo: CrashInfo
    
    var isRunning: Bool = false
    var statusCode: Int = 0
    var message: String?
    
    private var process: SubProcess!
    private var fileURL: URL?
    private var scriptURL: URL
    
    init(crashInfo: CrashInfo, scriptURL: URL, fileURL: URL?) {
        self.crashInfo = crashInfo
        self.fileURL = fileURL;
        self.scriptURL = scriptURL;
    }
    
    func run() {
        defer {
            self.isRunning = false
            self.process = nil
        }

        if self.process != nil {
            self.process?.terminate()
            self.process = nil
        }
        
        let crashPath = self.fileURL?.path ?? FileManager.default.temporaryPath()
        do {
            try self.crashInfo.raw.write(toFile: crashPath, atomically: true, encoding: .utf8)
        } catch {
            self.statusCode = -1001
            return
        }
        
        let dir = Config.dsymDownloadDirectory()
        let env = self.crashInfoToEnv(crashInfo)
        self.process = SubProcess(cmd: self.scriptURL.path, args: [crashPath, dir], env: env)
        self.isRunning = true
        self.process.run()
        
        self.statusCode = self.process.exitCode
        self.message = self.process.output
    }

    func cancel() {
        self.process.terminate()
        self.isRunning = false
    }
    
    private func crashInfoToEnv(_ crashInfo: CrashInfo) -> [String: String] {
        var env: [String: String] = [:]
        env["APP_NAME"] = crashInfo.appName ?? ""
        env["UUID"] = crashInfo.uuid ?? ""
        env["BUNDLE_ID"] = crashInfo.bundleID ?? ""
        env["APP_VERSION"] = crashInfo.appVersion ?? ""
        return env
    }
}

class DsymDownloader {
    static let shared = DsymDownloader()

    var tasks:[String: DsymDownloadTask] = [:]
    
    private let scriptURL = Config.downloadScriptURL()
    
    func canDownload() -> Bool {
        let script = try? String(contentsOf: self.scriptURL, encoding: .utf8)
        if script == nil || script!.count == 0 {
            return false
        }
        
        do {
            try FileManager.default.setAttributes([.posixPermissions : 0o777], ofItemAtPath: self.scriptURL.path)
        } catch {
            return false
        }
        
        return true
    }
    
    @discardableResult
    func download(crashInfo: CrashInfo, fileURL: URL?) -> DsymDownloadTask? {
        if !self.canDownload() {
            return nil
        }
        
        if let uuid = crashInfo.uuid {
            if let task = self.tasks[uuid] {
                return task
            }
        }
        
        let task = DsymDownloadTask(crashInfo: crashInfo, scriptURL: self.scriptURL, fileURL: fileURL)
        let uuid = NSUUID().uuidString
        self.tasks[uuid] = task
        DispatchQueue.global().async {
            task.run()
            NotificationCenter.default.post(name: .dsymDownloadStatusChanged, object: task)
        }
        NotificationCenter.default.post(name: .dsymDownloadStatusChanged, object: task)
        return task
    }
}
