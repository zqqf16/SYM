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


extension String {
    var separatedValue: String? {
        let list = self.components(separatedBy: ":")
        if list.count < 2 {
            return nil
        }
        
        let value = list[1].strip()
        if value.characters.count == 0 {
            return nil
        }
        
        return value
    }
}


extension Image {
    func addFrame(_ frame: Frame) {
        if self.backtrace == nil{
            self.backtrace = [Frame]()
        }
        
        self.backtrace?.append(frame)
    }
    
    // 0x19a8d8000 - 0x19a8f4fff libsystem_m.dylib arm64  <ee3277089d2b310c81263e5fbcbb3138> /usr/lib/system/libsystem_m.dylib

    static let re = RE.compile("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+([^\\s]+)\\s*(\\w+)\\s*<(.*)>")!

    convenience init?(line: String) {
        guard let g = Image.re.match(line) else {
            return nil
        }
        
        self.init()
        
        self.loadAddress = g[0]
        self.name = g[1]
        self.uuid = g[3].uuidFormat()
    }
}

extension Crash {
    func addFrame(_ frame: Frame) {
        if self.images == nil {
            self.images = [String: Image]()
        }
        
        let image = self.images![frame.image] ?? Image()
        image.addFrame(frame)
        image.name = frame.image
        self.images![frame.image] = image
    }
}


class Parser {

    static func parse(_ raw: String) -> Crash? {
        var crash = Crash(content: raw)
        guard let type = CrashType.fromContent(raw) else {
            return nil
        }
        
        switch type {
        case .umeng:
            self.parseUmengCrash(&crash)
        case .apple:
            self.parseAppleCrash(&crash)
        default:
            break
        }
        
        return crash
    }
    
    static func parseUmengCrash(_ crash: inout Crash) {
        let lines = crash.content.components(separatedBy: "\n")
        
        var loadAddress: String?
        var uuid: String?
        
        for (index, line) in lines.enumerated() {
            let value = line.strip()
            if value.hasPrefix("Application received") {
                crash.reason = value.components(separatedBy: " ").last
            } else if value.hasPrefix("dSYM UUID") {
                uuid = value.separatedValue
            } else if value.hasPrefix("CPU Type") {
                crash.arch = value.separatedValue ?? "arm64"
            } else if value.hasPrefix("Binary Image") {
                crash.appName = value.separatedValue
            } else if value.hasPrefix("Slide Address") {
                loadAddress = value.separatedValue
            } else if let frame = Frame(line: line) {
                frame.lineNumber = index
                crash.addFrame(frame)
            }
        }
        
        if crash.images == nil || crash.appName == nil {
            return
        }
        
        if let image = crash.images![crash.appName!] {
            image.uuid = uuid
            image.loadAddress = loadAddress
        }
    }
    
    static func getBinary(_ line: String) -> String? {
        // Process:         Simple-Example [24203]
        if let process = line.separatedValue {
            return process.components(separatedBy: " ")[0]
        }
        return nil
    }
    
    static func parseAppleCrash(_ crash: inout Crash) {
        let lines = crash.content.components(separatedBy: "\n")
        var binaryImagesSectionStarted = false

        for (index, line) in lines.enumerated() {
            let value = line.strip()
            if value.hasPrefix("Exception Type: ") {
                crash.reason = value.separatedValue
            } else if value.hasPrefix("Process") {
                crash.appName = self.getBinary(line)
            } else if value.hasPrefix("Binary Images:") {
                binaryImagesSectionStarted = true
            } else if let frame = Frame(line: line) {
                frame.lineNumber = index
                crash.addFrame(frame)
            } else {
                if !binaryImagesSectionStarted || crash.images == nil {
                    continue
                } else if let new = Image(line: line) {
                    if let old = crash.images![new.name!] {
                        old.loadAddress = new.loadAddress
                        old.uuid = new.uuid
                    }
                }
            }
        }
    }
}


/*

class CSVParser: BatchParser {
    func parse(raw: String) -> [Crash]? {
        let csv = CSwiftV(string: raw)
        if csv.headers.count < 7 {
            return nil
        }
        
        var result = [Crash]()
        
        for row in csv.rows {
            guard let str: String? = row[6] else {
                continue
            }

            let crash = Crash(content: trimCSVCrashInfo(str!))
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

 */
