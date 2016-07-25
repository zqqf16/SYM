// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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

protocol Parser {
    func parse(crash: Crash)
}

protocol BatchParser {
    func parse(raw: String) -> [Crash]?
}

class FrameParser: Parser {

    func parse(crash: Crash) {
        for (index, line) in crash.lines.enumerate() {
            if line.type != .Plain {
                continue
            }
            if let bt = Frame(input: line.value) {
                bt.lineNumber = index
                crash.backtrace[index] = bt
            }
        }
        for index in crash.backtrace.keys {
            crash.lines[index].type = .Backtrace
        }
    }
}

func metaValue(content: String) -> String? {
    let list = content.componentsSeparatedByString(":")
    if list.count < 2 {
        return nil
    }
    
    let value = list[1].strip()
    if value.characters.count == 0 {
        return nil
    }
    return value
}

class UmentMetaParser: Parser {

    func parse(crash: Crash) {
        var metas = [Int: LineType]()
        for (index, line) in crash.lines.enumerate() {
            if line.type == .Backtrace {
                continue
            }
            let content = line.value.strip()
            if content.hasPrefix("Application received") {
                metas[index] = .Reason
                crash.reason = content.componentsSeparatedByString(" ").last
            } else if content.hasPrefix("dSYM UUID") {
                if let value = metaValue(content) {
                    metas[index] = .UUID
                    crash.uuid = value
                }
            } else if content.hasPrefix("CPU Type") {
                if let value = metaValue(content) {
                    metas[index] = .Arch
                    crash.arch = value
                }
            } else if content.hasPrefix("Binary Image") {
                if let value = metaValue(content) {
                    metas[index] = .Binary
                    crash.binary = value
                }
            } else if content.hasPrefix("Slide Address") {
                if let value = metaValue(content) {
                    metas[index] = .LoadAddress
                    crash.loadAddress = value
                }
            }
        }
        
        for (index, type) in metas {
            crash.lines[index].type = type
        }
    }
}

class AppleParser: Parser {
    
    var binaryImagesSectionStarted = false
    
    lazy var matcher: RegexHelper? = {
        let binaryPattern = "\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+([^\\s]+)\\s*(\\w+)\\s*<(.*)>"
        let matcher: RegexHelper?
        do {
            matcher = try RegexHelper(binaryPattern)
        } catch _ {
            return nil
        }
        
        return matcher
    }()
    
    func parse(crash: Crash) {
        self.binaryImagesSectionStarted = false

        var metas = [Int: LineType]()
        for (index, line) in crash.lines.enumerate() {
            if line.type == .Backtrace {
                continue
            }
            let content = line.value.strip()
            if content.hasPrefix("Exception Type: ") {
                if let value = metaValue(content) {
                    metas[index] = .Reason
                    crash.reason = value
                }
            } else if content.hasPrefix("*** ") {
                metas[index] = .Info
                crash.crashInfo = content
            } else if content.hasPrefix("Process") {
                if let value = self.binary(content) {
                    metas[index] = .Binary
                    crash.binary = value
                }
            } else if content.hasPrefix("Binary Images:") {
                self.binaryImagesSectionStarted = true
            } else {
                if !self.binaryImagesSectionStarted {
                    continue
                }
                if let result = self.parseBinaryLine(content, binaryName: crash.binary) {
                    crash.loadAddress = result.loadAddress
                    crash.uuid = result.uuid
                    crash.arch = result.arch
                    metas[index] = .Binary
                    self.binaryImagesSectionStarted = false
                }
            }
        }
        
        for (index, type) in metas {
            crash.lines[index].type = type
        }
    }
    
    func binary(line: String) -> String? {
        // Process:         Simple-Example [24203]
        if let process = metaValue(line) {
            return process.componentsSeparatedByString(" ")[0]
        }
        return nil
    }
    
    func parseBinaryLine(input: String, binaryName: String?) -> (loadAddress: String, arch: String, uuid: String)? {
        
        if self.matcher == nil {
            return nil
        }
        
        let groups = self.matcher!.match(input)
        if groups.count != 5 {
            return nil
        }
        
        if groups[2] != binaryName {
            return nil
        }
        
        return (groups[1], groups[3], groups[4].uuidFormat())
    }
}

class CSVParser: BatchParser {
    func parse(raw: String) -> [Crash]? {
        let csv = CSwiftV(string: raw)
        if csv.headers.count != 24 {
            return nil
        }
        
        var result = [Crash]()
        
        for row in csv.rows {
            guard let str: String? = row[6] else {
                continue
            }
            
            let version = row[1] ?? ""
            let errors = row[2] ?? "0"

            let crash = Crash(content: trimCSVCrashInfo(str!))
            crash.appVersion = version
            crash.numberOfErrors = Int(errors)
            result.append(crash)
        }
        
        if result.count > 0 {
            return result
        }
        
        return nil
    }
    
    private func trimCSVCrashInfo(origin: String) -> String {
        return origin.stringByReplacingOccurrencesOfString("\"\"", withString: "").stringByReplacingOccurrencesOfString(",", withString: "\n").stringByReplacingOccurrencesOfString("\\t", withString: "\t").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "[]"))
    }
}