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

class CrashInfo {
    let raw: String
    
    var appName: String?
    var device: String?
    var bundleID: String?
    var arch: String = "arm64"
    var uuid: String?
    var osVersion: String?
    var appVersion: String?
    
    struct Frame {
        var raw: String
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
    }
    
    struct BinaryImage {
        var name: String
        var uuid: String?
        var arch: String? = "arm64"
        var loadAddress: String?
        var backtrace: [Frame]?
        
        func isValid() -> Bool {
            return self.uuid != nil && self.loadAddress != nil
                && self.backtrace != nil && self.backtrace!.count > 0
        }
    }
    
    init(_ raw: String) {
        self.raw = raw
        self.parseCrashInfo()
    }
    
    func parseCrashInfo() {
        self.appName = RE.process.findFirst(self.raw)?[0]
        self.device = RE.hardware.findFirst(self.raw)?[0]
        self.bundleID = RE.identifier.findFirst(self.raw)?[0]
        self.osVersion = RE.osVersion.findFirst(self.raw)?[0]
        self.appVersion = RE.version.findFirst(self.raw)?[0]

        if let binary = self.appName,
            let imageRE = RE.image(binary, options:[]),
            let imageMatch = imageRE.findFirst(self.raw) {
            self.uuid = imageMatch[3].uuidFormat()
            self.arch = imageMatch[2]
        }
    }
    
    func executableBinaryBacktraceRanges() -> [NSRange] {
        var backtraceRanges:[NSRange] = []
        if let binary = self.appName,
            let frameRE = RE.frame(binary),
            let frames = frameRE.findAllRanges(self.raw) {
            backtraceRanges = frames
        }

        return backtraceRanges
    }
    
    func symbolicate(dsym: String? = nil) -> String {
        if let content = SubProcess.symbolicatecrash(crash: self.raw), content.count > 0 {
            return content
        }
        
        return self.raw
    }
}

class CPUUsageLog: CrashInfo {
    override func parseCrashInfo() {
        self.appName = RE.powerstats.findFirst(self.raw)?[0]
        self.device = RE.hardware.findFirst(self.raw)?[0]
        self.arch = RE.architecture.findFirst(self.raw)?[0] ?? "arm64"
        self.osVersion = RE.osVersion.findFirst(self.raw)?[0]
        self.appVersion = RE.version.findFirst(self.raw)?[0]
        if let path = RE.path.findFirst(self.raw)?[0],
            let imageRE = RE.image(withPath: path),
            let imageMatch = imageRE.findFirst(self.raw) {
            //self.bundleID = imageMatch[1]
            self.uuid = imageMatch[1].uuidFormat()
        }
    }
    
    override func executableBinaryBacktraceRanges() -> [NSRange] {
        var backtraceRanges:[NSRange] = []
        if let binary = self.appName,
            let frameRE = RE.cpuUsageFrame(binary),
            let frames = frameRE.findAllRanges(self.raw) {
            backtraceRanges = frames
        }
        
        return backtraceRanges
    }
}

class UmengCrash: CrashInfo {
    override func parseCrashInfo() {
        self.appName = RE.binaryImage.findFirst(self.raw)?[0]
        self.uuid = RE.dsymUUID.findFirst(self.raw)?[0]
        self.arch = RE.cpuType.findFirst(self.raw)?[0] ?? "arm64"
    }
    
    func executableBinaryImage() -> BinaryImage? {
        guard let appName = self.appName else {
                return nil
        }

        let loadAddress = RE.slideAddress.findFirst(self.raw)?[0]
        let ranges = self.executableBinaryBacktraceRanges()
        let backtrace = ranges.map { (range) -> Frame in
            let line = self.raw.substring(with: range)!
            let group = RE.frame.match(line)!
            // 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
            return Frame(raw: line,
                         index: group[0],
                         image: group[1],
                         address: group[2],
                         symbol: group[3])
        }

        return BinaryImage(name: appName,
                           uuid: self.uuid,
                           arch: self.arch,
                           loadAddress: loadAddress,
                           backtrace: backtrace)
        
    }
    
    override func symbolicate(dsym: String? = nil) -> String {
        guard let image = self.executableBinaryImage(), image.isValid() else {
            return self.raw
        }
        
        let fixedImage = image.fixed()
        guard let result = SubProcess.atos(fixedImage, dsym: dsym) else {
            return self.raw
        }
        
        var newContent = self.raw
        for frame in fixedImage.backtrace! {
            if let symbol = result[frame.address] {
                var newFrame = frame
                newFrame.symbol = symbol
                newContent = newContent.replacingOccurrences(of: frame.raw, with: newFrame.description)
            }
        }
        
        return newContent
    }
}

extension CrashInfo {
    static func parse(_ content: String) -> CrashInfo {
        if content.contains("dSYM UUID") && content.contains("Slide Address") {
            return UmengCrash(content)
        } else if content.contains("Wakeups limit") && content.contains("Limit duration:") {
            return CPUUsageLog(content)
        }
        return CrashInfo(content)
    }
}
