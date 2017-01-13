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


struct LineRE {
    
    // 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
    static let frame =  RE.compile("^\\s*(\\d{1,3})\\s+([^ ]+)\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)")!
    
    // 0x19a8d8000 - 0x19a8f4fff libsystem_m.dylib arm64  <ee3277089d2b310c81263e5fbcbb3138> /usr/lib/system/libsystem_m.dylib
    static let image = RE.compile("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+([^\\s]+)\\s*(\\w+)\\s*<(.*)>")!
    
    static let thread = RE.compile("Thread (\\d{1,3})(?:[: ])(?:(?:(Crashed):)|(?:name:\\s+(.*)))*$")!
}


extension CrashReport.Frame {
    convenience init?(content: String, lineNumber: Int) {
        guard let match = LineRE.frame.match(content) else {
            return nil
        }
        
        self.init(index: match[0], image: match[1], address: match[2], line: lineNumber)
        self.symbol = match[3]
    }
    
    fileprivate func fixAddress(_ loadAddress: String) {
        guard self.address.hexaToDecimal == loadAddress.hexaToDecimal,
            self.symbol != nil,
            self.symbol!.hasPrefix("+")
            else {
                return
        }
        
        let list = self.symbol!.components(separatedBy: " ")
        if list.count < 2 {
            return
        }
        
        guard let offset = Int(list[1]) else {
            return
        }
        let newAddress = String(self.address.hexaToDecimal + offset, radix: 16)
        self.address = "0x" + newAddress.leftPadding(toLength: 16, withPad: "0")
        self.symbol = "+ 0"
    }
}

extension CrashReport.Image {
    fileprivate func update(uuid: String?, loadAddress: String?) {
        self.uuid = uuid
        self.loadAddress = loadAddress
    }
    
    fileprivate convenience init(match: [String]) {
        self.init(name: match[1])
        self.loadAddress = match[0]
        self.uuid = match[3].uuidFormat()
    }
    
    fileprivate convenience init?(content: String) {
        guard let match = LineRE.image.match(content) else {
            return nil
        }
        
        self.init(name: match[1])
        
        self.loadAddress = match[0]
        self.uuid = match[3].uuidFormat()
    }
}

extension CrashReport {
    convenience init(_ content: String) {
        self.init()
        self.content = content
        self.parse()
    }
    
    func update(content: String) {
        self.content = content
        self.cleanParseResult()
        self.parse()
    }
    
    func cleanParseResult() {
        self.threads = []
        self.images = [:]
        self.reason = nil
        self.appName = nil
    }
    
    private func detectBrand() -> CrashReport.Brand {
        var brand: CrashReport.Brand = .unknow
        
        if let content = self.content {
            if content.contains("dSYM UUID") && content.contains("Slide Address") {
                brand = .umeng
            } else if content.contains("Incident Identifier") {
                brand = .apple
            } else if content.contains("App base addr:") && content.contains("System Binary infos:") {
                brand = .bugly
            }
        }
        
        return brand
    }
    
    private func parse() {
        self.brand = self.detectBrand()

        switch self.brand {
        case .umeng:
            self.parseUmeng()
        case .apple:
            return self.parseApple()
        default:
            break
        }
    }
    
    private func correct() {
        for thread in self.threads {
            for frame in thread.backtrace {
                if self.appName == frame.image {
                    frame.isKey = true
                }
                if let image = self.images[frame.image] {
                    image.backtrace.append(frame)
                    if let load = image.loadAddress {
                        frame.fixAddress(load)
                    }
                } else {
                    let newImage = CrashReport.Image(name: frame.image)
                    self.images[frame.image] = newImage
                }
            }
        }
    }
    
    private func parseUmeng() {
        var loadAddress: String?
        var uuid: String?
        let thread = CrashReport.Thread()
        thread.crashed = true
        self.threads.append(thread)
        
        let lines = self.content!.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let value = line.strip()
            if let (k, v) = value.parseKeyValue(separatedBy: ":") {
                if k == "Application received" {
                    self.reason = v
                } else if k == "CPU Type" {
                    self.arch = v
                } else if k == "Binary Image" {
                    self.appName = v
                } else if k == "Slide Address" {
                    loadAddress = v
                } else if k == "dSYM UUID" {
                    uuid = v
                }
                
                continue
            }
            
            if let frame = CrashReport.Frame(content: value, lineNumber: index) {
                if self.images[frame.image] == nil {
                    self.images[frame.image] = CrashReport.Image(name: frame.image)
                }
                
                thread.backtrace.append(frame)
            }
        }
        
        if self.appName != nil, let image = self.images[self.appName!] {
            image.update(uuid: uuid, loadAddress: loadAddress)
        }
        
        self.correct()
    }
    
    private func getBinary(_ line: String) -> String? {
        // Process:         Simple-Example [24203]
        if let (_, v) = line.parseKeyValue(separatedBy: ":") {
            return v.components(separatedBy: " ")[0]
        }
        return nil
    }
    
    private func parseApple() {
        let lines = self.content!.components(separatedBy: "\n")
        
        var thread: CrashReport.Thread?
        var imageSectionStarted = false
        
        for (index, line) in lines.enumerated() {
            let value = line.strip()
            
            if imageSectionStarted {
                if let image = CrashReport.Image(content: value) {
                    self.images[image.name] = image
                }
                
                continue
            }
            
            if value.hasPrefix("Last Exception Backtrace") {
                thread = CrashReport.Thread()
                thread?.name = "Last Exception Backtrace"
                self.threads.append(thread!)
            } else if value.hasPrefix("Exception Type: ") {
                self.reason = value.separatedValue()
            } else if value.hasPrefix("Process:") {
                self.appName = self.getBinary(line)
            } else if value.hasPrefix("Binary Images:") {
                imageSectionStarted = true
            } else if let g = LineRE.thread.match(value) {
                // Thread 0 name:  Dispatch queue: com.apple.main-thread
                // Thread 0 Crashed:
                let num = Int(g[0])
                if thread?.number != num {
                    thread = CrashReport.Thread()
                    thread!.number = num
                    self.threads.append(thread!)
                }
                
                if g.count > 1 {
                    if g[1].lowercased() == "crashed" {
                        thread!.crashed = true
                    } else {
                        thread!.name = g[1]
                    }
                }
            } else if let frame = CrashReport.Frame(content: value, lineNumber: index) {
                thread?.backtrace.append(frame)
            }
        }
        
        self.correct()
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
