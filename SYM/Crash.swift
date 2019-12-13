// The MIT License (MIT)
//
// Copyright (c) 2017 - 2019 zqqf16
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

class Binary {
    var name: String
    var uuid: String?
    var arch: String? = "arm64"
    var loadAddress: String?
    var path: String?
    var executable: Bool = false
    var backtrace: [Frame]? = nil
    
    var relativePath: String? {
        guard let path = self.path else {
            return nil
        }

        var components: [String] = []
        for dir in path.components(separatedBy: "/").reversed() {
            if dir.hasSuffix(".app") {
                break
            }
            components.append(dir)
        }
        return components.reversed().joined(separator: "/")
    }
    
    var inApp: Bool {
        guard let path = self.path else {
            return false
        }
        
        return path.contains("/var/containers/Bundle/Application")
            || path.hasPrefix("/var/mobile/Containers/Bundle/Application") // iOS8
    }
    
    var isValid: Bool {
        return self.uuid != nil && self.loadAddress != nil
    }
    
    init(name: String, uuid: String?, arch: String?, loadAddress: String?, path: String?) {
        self.name = name
        self.uuid = uuid
        self.arch = arch ?? "arm64"
        self.loadAddress = loadAddress
        self.path = path
    }
}


class CrashInfo {
    let raw: String
    
    var appName: String?
    var device: String?
    var bundleID: String?
    var arch: String = "arm64"
    var uuid: String?
    var osVersion: String?
    var appVersion: String?
    var embededBinaries: [Binary]?
    
    init(_ raw: String) {
        self.raw = raw
        self.parseCrashInfo()
        self.parseEmbededBinaries()
    }
    
    func parseOneLineInfo(_ re: RE) -> String? {
        return re.findFirst(self.raw)?[0]
    }
    
    func parseCrashInfo() {
        self.appName = self.parseOneLineInfo(.process)
        self.device = self.parseOneLineInfo(.hardware)
        self.bundleID = self.parseOneLineInfo(.identifier)
        self.osVersion = self.parseOneLineInfo(.osVersion)
        self.appVersion = self.parseOneLineInfo(.version)
        
        if let binary = self.appName,
            let imageRE = RE.image(binary, options:[]),
            let imageMatch = imageRE.findFirst(self.raw) {
            self.uuid = imageMatch[3].uuidFormat()
            self.arch = imageMatch[2]
        }
    }
    
    func parseEmbededBinaries() {
        if let groups = RE.image.findAll(self.raw) {
            var embededBinaries: [Binary] = []
            for group in groups {
                let binary = Binary(name: group[1],
                                    uuid: group[3].uuidFormat(),
                                    arch: group[2],
                                    loadAddress: group[0],
                                    path: group[4])
                if !binary.inApp {
                    continue
                }
                
                binary.executable = binary.name == self.appName
                embededBinaries.append(binary)
            }
            self.embededBinaries = embededBinaries;
        }
    }

    func crashedThreadRange() -> NSRange? {
        return RE.threadCrashed.findFirstRange(self.raw)
    }
    
    func backtraceRanges(withBinary binary: String) -> [NSRange] {
        var result:[NSRange] = []
        if let frameRE = RE.frame(binary),
            let frames = frameRE.findAllRanges(self.raw) {
            result = frames
        }
        return result
    }
    
    func appBacktraceRanges() -> [NSRange] {
        var binaryNames: [String] = []
        if let embededBinaries = self.embededBinaries {
            embededBinaries.forEach { (binary) in
                binaryNames.append(binary.name)
            }
        } else if let appName = self.appName {
            binaryNames.append(appName)
        }
        
        var ranges: [NSRange] = []
        binaryNames.forEach { (name) in
            ranges.append(contentsOf: self.backtraceRanges(withBinary: name))
        }
        
        return ranges;
    }
    
    func symbolicate(dsyms: [String]? = nil) -> String {
        if let content = SubProcess.symbolicatecrash(crash: self.raw, dsyms: dsyms), content.count > 0 {
            return content
        }
        
        return self.raw
    }
}

class CPUUsageLog: CrashInfo {
    override func parseCrashInfo() {
        self.appName = self.parseOneLineInfo(.powerstats)
        self.device = self.parseOneLineInfo(.hardware)
        self.arch = self.parseOneLineInfo(.architecture) ?? "arm64"
        self.osVersion = self.parseOneLineInfo(.osVersion)
        self.appVersion = self.parseOneLineInfo(.version)
        if let path = self.parseOneLineInfo(.path),
            let imageRE = RE.image(withPath: path),
            let imageMatch = imageRE.findFirst(self.raw) {
            //self.bundleID = imageMatch[1]
            self.uuid = imageMatch[1].uuidFormat()
        }
    }
    
    override func parseEmbededBinaries() {
        if let groups = RE.cpuUsageImage.findAll(self.raw) {
            var embededBinaries: [Binary] = []
            for group in groups {
                let binary = Binary(name: group[1],
                                    uuid: group[2].uuidFormat(),
                                    arch: nil,
                                    loadAddress: group[0],
                                    path: group[3])
                if !binary.inApp {
                    continue
                }
                
                binary.executable = binary.name == self.appName
                embededBinaries.append(binary)
            }
            self.embededBinaries = embededBinaries;
        }
    }

    override func backtraceRanges(withBinary binary: String) -> [NSRange] {
        var result:[NSRange] = []
        if let frameRE = RE.cpuUsageFrame(binary),
            let frames = frameRE.findAllRanges(self.raw) {
            result = frames
        }
        return result
    }
}

class FabricCrash: CrashInfo {
    override func parseCrashInfo() {
        self.device = self.parseOneLineInfo(.hashDevice)
        self.osVersion = self.parseOneLineInfo(.hashOSVersion)
        self.appVersion = self.parseOneLineInfo(.hashAppVersion)
        self.bundleID = self.parseOneLineInfo(.hashBundleID)
        if let osVersion = self.osVersion, let platform = self.parseOneLineInfo(.hashPlatform) {
            self.osVersion = "\(platform) \(osVersion)"
        }
    }
}

class UmengCrash: CrashInfo {
    override func parseCrashInfo() {
        self.appName = self.parseOneLineInfo(.binaryImage)
        self.uuid = self.parseOneLineInfo(.dsymUUID)
        self.arch = self.parseOneLineInfo(.cpuType) ?? "arm64"
    }

    func executableBinaryImage() -> Binary? {
        guard let appName = self.appName else {
                return nil
        }

        let loadAddress = self.parseOneLineInfo(.slideAddress)
        let ranges = self.appBacktraceRanges()
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

        let binary = Binary(name: appName,
                            uuid: self.uuid,
                            arch: self.arch,
                            loadAddress: loadAddress,
                            path: "")
        binary.backtrace = backtrace
        return binary
    }
    
    override func symbolicate(dsyms: [String]? = nil) -> String {
        guard let image = self.executableBinaryImage(), image.isValid else {
            return self.raw
        }
        
        image.fix()
        var dsymPath = ""
        if let dsymPaths = dsyms {
            dsymPath = dsymPaths[0]
        }
        guard let result = SubProcess.atos(image, dsym: dsymPath) else {
            return self.raw
        }
        
        var newContent = self.raw
        for frame in image.backtrace! {
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
        } else if (content.contains("Wakeups limit") || content.contains("CPU limit")) && content.contains("Limit duration:") {
            return CPUUsageLog(content)
        } else if content.contains("# Crashlytics - plaintext stacktrace") {
            return FabricCrash(content)
        }
        return CrashInfo(content)
    }
}
