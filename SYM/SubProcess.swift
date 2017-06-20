// The MIT License (MIT)
//
// Copyright (c) 2017 zqqf16
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

struct SubProcess {
    static func execute(cmd: String, args: [String]?) -> String? {
        let pipe = Pipe()
        
        let task = Process()
        task.launchPath = cmd
        task.arguments = args
        task.standardOutput = pipe
        
        task.launch()
        
        let output = pipe.fileHandleForReading
        let data = output.readDataToEndOfFile()
        return String(data: data, encoding: String.Encoding.utf8)
    }
}

extension SubProcess {
    static func dwarfdump(path: String) -> [String]? {
        let cmd = "/usr/bin/dwarfdump"
        let args = ["--uuid", path]
        if let result = self.execute(cmd: cmd, args: args) {
            let lines = result.components(separatedBy: "\n").filter {
                (content) -> Bool in
                if content.characters.count == 0 {
                    return false
                }
                
                return content.hasPrefix("UUID: ")
            }
            
            return lines.map({ (line) -> String in
                return line.components(separatedBy: " ")[1]
            })
        }
        
        return nil
    }
}
