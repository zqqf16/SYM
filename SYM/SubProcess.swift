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
    
    var outputHandler: ((String)->Void)?
    var errorHandler: ((String)->Void)?

    private var task: Process?
    
    init(cmd: String, args: [String]?, env: [String: String]? = nil) {
        self.cmd = cmd
        self.args = args
        self.env = env
        self.exitCode = 0
    }
    
    @discardableResult
    func run() -> Bool {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        outputPipe.fileHandleForReading.readabilityHandler = {handle in
            guard let string = String(data: handle.availableData, encoding: String.Encoding.utf8) else {
                return
            }
            self.output += string
            if let outputHandler = self.outputHandler {
                outputHandler(string)
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            guard let string = String(data: handle.availableData, encoding: String.Encoding.utf8) else {
                return
            }
            self.error += string
            if let errorHandler = self.errorHandler {
                errorHandler(string)
            }
        }
        
        let task = Process()
        task.launchPath = self.cmd
        task.arguments = self.args
        if let customEnv = self.env {
            var env = task.environment ?? [:]
            customEnv.forEach { (k, v) in env[k] = v }
            task.environment = env
        }
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.terminationHandler = { process in
            
        }
        
        self.task = task
        task.launch()
        task.waitUntilExit()
        
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        
        self.exitCode = Int(task.terminationStatus)
        return (exitCode == 0)
    }
    
    func terminate() {
        self.task?.terminate()
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
        if let matchs = re.matches(in: output) {
            return matchs.map { ($0.captures![0], $0.captures![1]) }
        }
        
        return nil
    }
}
