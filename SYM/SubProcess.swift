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

import Foundation

class SubProcess {
    var output: String = ""
    var error: String = ""

    var cmd: String
    var args: [String]?
    var env: [String: String]?

    var exitCode: Int

    var outputHandler: ((String) -> Void)?
    var errorHandler: ((String) -> Void)?

    private var task: Process?

    init(cmd: String, args: [String]?, env: [String: String]? = nil) {
        self.cmd = cmd
        self.args = args
        self.env = env
        exitCode = 0
    }

    @discardableResult
    func run() -> Bool {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            guard let string = String(data: handle.availableData, encoding: .utf8) else {
                return
            }
            self.output += string
            self.outputHandler?(string)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            guard let string = String(data: handle.availableData, encoding: .utf8) else {
                return
            }
            self.error += string
            self.errorHandler?(string)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: cmd)
        task.arguments = args
        if let customEnv = env {
            var environment = task.environment ?? [:]
            customEnv.forEach { key, value in
                environment[key] = value
            }
            task.environment = environment
        }

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        self.task = task
        do {
            try task.run()
        } catch {
            exitCode = -1
            return false
        }
        task.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        exitCode = Int(task.terminationStatus)
        return exitCode == 0
    }

    func terminate() {
        task?.terminate()
    }
}

extension SubProcess {
    static func dwarfdump(_ paths: [String]) -> [(String, String)]? {
        let cmd = "/usr/bin/dwarfdump"
        let args = ["--uuid"] + paths
        let re = try! Regex("UUID: ([0-9a-z\\-]{36}) \\((.*)\\) ", options: [.anchorsMatchLines, .caseInsensitive])

        let process = SubProcess(cmd: cmd, args: args)
        process.run()
        let output = process.output
        if let matches = re.matches(in: output) {
            // captures[0] is the full match; UUID/arch are groups 1 and 2.
            return matches.compactMap { match -> (String, String)? in
                guard let captures = match.captures,
                      captures.count >= 3,
                      let uuid = CrashUUID.normalize(captures[1])
                else {
                    return nil
                }
                return (uuid, captures[2])
            }
        }

        return nil
    }

    static func atos(
        loadAddress: String,
        addresses: [String],
        dsym: String,
        arch: String = "arm64"
    ) -> [String]? {
        let cmd = "/usr/bin/atos"
        let args = ["-arch", arch, "-o", dsym, "-l", loadAddress] + addresses
        let process = SubProcess(cmd: cmd, args: args)
        process.run()
        let result = process.output
        if !result.isEmpty {
            return result
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
        }
        return nil
    }
}
