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
    
    // dSYM UUID: 45AF800D-B56A-39D8-AB1C-AD0F3208EC50
    static let dsymUUID = try! RE("dSYM UUID:\\s*([^\\s]+)")
    
    // Slide Address: 0x0000000100000000
    static let slideAddress = try! RE("Slide Address:\\s*([^\\s]+)")
    
    // CPU Type: arm64
    static let cpuType = try! RE("CPU Type:\\s*([^\\s]+)")
    
    // Hardware Model:      iPhone5,2
    static let hardware = try! RE("Hardware Model:\\s*([^\\s]+)")
    
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
    
    var appName: String? {
        return LineRE.process.findFirst(self.content)?[0]
    }
    
    var device: String? {
        if let group = LineRE.hardware.findFirst(self.content) {
            return group[0]
        }
        return nil
    }
    
    var uuid: String? {
        if let match = self.imageInfo {
            return match[3].uuidFormat()
        }
        return nil
    }
    
    var keyFrames: [Frame]? {
        guard let appName = self.appName,
            let keyFrameRe = LineRE.frame(appName),
            let frames = keyFrameRe.findAll(self.content) else {
                return nil
        }
        
        return frames.flatMap { Frame(index: $0[0], image: $0[1], address: $0[2], symbol: $0[3]) }
    }
    
    private var imageInfo: [String]? {
        guard let appName = self.appName,
            let imageRE = LineRE.image(appName, options:[]),
            let imageMatch = imageRE.findFirst(self.content) else {
                return nil
        }
        return imageMatch
    }
    
    init(content: String) {
        self.content = content
    }
    
    func toStandard() -> String? {
        return self.content
    }
    
    func binaryImage() -> Image? {
        guard let imageMatch = self.imageInfo else {
            return nil
        }
        
        return Image(name: imageMatch[1],
                     uuid: imageMatch[3].uuidFormat(),
                     arch: imageMatch[2],
                     loadAddress: imageMatch[0],
                     frames: self.keyFrames)
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
    
    override var appName: String? {
        return LineRE.binaryImage.findFirst(self.content)?[0]
    }
    
    override var uuid: String? {
        return LineRE.dsymUUID.findFirst(self.content)?[0]
    }
    
    var slideAddress: String? {
        return LineRE.slideAddress.findFirst(self.content)?[0]
    }
    
    var arch: String? {
        return LineRE.cpuType.findFirst(self.content)?[0]
    }
    
    override init(content: String) {
        super.init(content: content)
    }
    
    override func toStandard() -> String? {
        return nil
    }
    
    override func binaryImage() -> Image? {
        guard let appName = self.appName else {
            return nil
        }
        
        return Image(name: appName,
                     uuid: self.uuid,
                     arch: self.arch,
                     loadAddress: self.slideAddress,
                     frames: self.keyFrames)
    }
}

// MARK: - Crash Detection
extension Crash {
    static func parse(fromContent content: String) -> Crash {
        if content.contains("dSYM UUID") && content.contains("Slide Address") {
            return Umeng(content: content)
        }
        return Crash(content: content)
    }
}
