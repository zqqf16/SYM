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

struct LineRE {
    // 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
    static let frame = try! RE("^\\s*(\\d{1,3})\\s+([^ ]+)\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)")
    
    // 0x19a8d8000 - 0x19a8f4fff libsystem_m.dylib arm64  <ee3277089d2b310c81263e5fbcbb3138> /usr/lib/system/libsystem_m.dylib
    static let image = try! RE("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+([^\\s]+)\\s*(\\w+)\\s*<(.*)>")
    
    // Thread 0:
    // Thread 0 Crashed:
    // Thread 0 name xxxxxx
    static let thread = try! RE("Thread (\\d{1,3})(?:[: ])(?:(?:(Crashed):)|(?:name:\\s+(.*)))*$")
    
    // Process demo [1111]
    static let process = try! RE("^Process:\\s*([^\\s]+)\\s*\\[*", optoins: .anchorsMatchLines)
    
    // Binary Image: demo
    static let binaryImage = try! RE("Binary Image:\\s*([^\\s]+)")
    
    // Frame with specified binary
    static func frame(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> RE? {
        return try? RE("^\\s*(\\d{1,3})\\s+(\(binary))\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)", optoins: options)
    }
    
    // Image with specified binary
    static func image(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> RE? {
        return try? RE("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+(\(binary))\\s*(\\w+)\\s*<(.*)>", optoins: options)
    }
    
    // UUID: E5B0A378-6816-3D90-86FD-2AEF15894A85
    static let uuid = try! RE("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{8}", optoins: [.anchorsMatchLines, .caseInsensitive])
}

class Crash {
    struct Frame {
        var index: String
        var image: String
        var address: String
        var symbol: String?
        
        var description: String {
            let index = self.index.extendToLength(2)
            let image = self.image.extendToLength(26)
            let address = self.address.extendToLength(18)
            let symbol = self.symbol ?? ""
            return "\(index) \(image) \(address) \(symbol)"
        }
        
        static func parse(fromLine line: String) -> Frame? {
            if let group = LineRE.frame.match(line) {
                // 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
                return Frame(index: group[0], image: group[1], address: group[2], symbol: group[3])
            }
            
            return nil
        }
    }
    
    struct Image {
        var name: String
        var uuid: String?
        var arch: String? = "arm64"
        var loadAddress: String?
        var frames: [Frame]?
    }
    
    var content: String
    var appName: String?
    
    init(content: String) {
        self.content = content
        self.appName = LineRE.process.findFirst(self.content)?[0]
    }
    
    func toStandard() -> String? {
        return self.content
    }
    
    func binaryImage() -> Image? {
        guard let appName = LineRE.process.findFirst(self.content)?[0],
            let keyFrameRe = LineRE.frame(appName),
            let imageRE = LineRE.image(appName, options: []),
            let imageMatch = imageRE.findFirst(self.content)
            else {
                return nil
        }
        
        var image = Image(name: imageMatch[1],
                          uuid: imageMatch[3].uuidFormat(),
                          arch: imageMatch[2],
                          loadAddress: imageMatch[0],
                          frames: nil)
        if let frames = keyFrameRe.findAll(self.content) {
            image.frames = frames.flatMap { Frame(index: $0[0], image: $0[1], address: $0[2], symbol: $0[3]) }
        }
        
        return image
    }
    
    func backfill(symbols: [String: String]) -> String {
        let lines = self.content.components(separatedBy: "\n")
        var newLines: [String] = []
        
        for line in lines {
            if var frame = Frame.parse(fromLine: line) {
                if let symbol = symbols[frame.address] {
                    frame.symbol = symbol
                    newLines.append(frame.description)
                    continue
                }
            }
            
            newLines.append(line)
        }
        
        return newLines.joined(separator: "\n")
    }
}

class Umeng: Crash {
    enum LineType {
        case frame(Frame)
        case appName(String)
        case uuid(String)
        case loadAddress(String)
        case arch(String)
        case other
    }
    
    override init(content: String) {
        super.init(content: content)
        self.appName = LineRE.binaryImage.findFirst(self.content)?[0]
    }
    
    override func toStandard() -> String? {
        return nil
    }
    
    func parse(line: String) -> LineType {
        let k2v: [String: ((String)->LineType)] = [
            "CPU Type": { .arch($0) },
            "Binary Image": { .appName($0) },
            "Slide Address": { .loadAddress($0) },
            "dSYM UUID": { .uuid($0) },
            ]
        
        if let (k, v) = line.separate(by: ":") {
            if let wrapper = k2v[k] {
                return wrapper(v)
            }
        }
        
        if let group = LineRE.frame.match(line) {
            // 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
            return .frame(Frame(index: group[0], image: group[1], address: group[2], symbol: group[3]))
        }
        
        return .other
    }
    
    override func binaryImage() -> Image? {
        var arch: String?
        var appName: String?
        var loadAddress: String?
        var uuid: String?
        var frames: [Frame] = []
        
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let t = self.parse(line: line)
            switch t {
            case .appName(let name):
                appName = name
            case .arch(let value):
                arch = value
            case .frame(let frame):
                frames.append(frame)
            case .loadAddress(let value):
                loadAddress = value
            case .uuid(let value):
                uuid = value
            default:
                break
            }
        }
        
        if appName == nil {
            return nil
        }
        
        var image = Image(name: appName!, uuid: uuid, arch: arch, loadAddress: loadAddress, frames: nil)
        image.frames = frames.filter { $0.image == appName }
        
        return image
    }
}

// MARK: - Crash Detection
extension Crash {
    static func parse(fromContent content: String) -> Crash? {
        if content.contains("dSYM UUID") && content.contains("Slide Address") {
            return Umeng(content: content)
        } else if content.contains("Incident Identifier") {
            return Crash(content: content)
        }
        
        return nil
    }
}
