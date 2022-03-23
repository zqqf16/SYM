// The MIT License (MIT)
//
// Copyright (c) 2022 zqqf16
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

protocol CrashParser {
    static func match(_ content: String) -> Bool
    func parse(_ content: String) -> Crash
}

struct RegexHelper {
    typealias KeyValueRegexMap = [WritableKeyPath<Crash, String?>: Regex]
    
    static func parseBaseInfo(_ content: String, crash: inout Crash, map: KeyValueRegexMap) {
        for (keyPath, regex) in map {
            if let value = regex.firstMatch(in: content)?.captures?[1] {
                crash[keyPath: keyPath] = value
            }
        }
    }
    
    static func parseBinaries(_ content: String, crash: inout Crash, regex: Regex, convertor:([String])->Binary) {
        if let images = regex.matches(in: content) {
            for match in images {
                guard let captures = match.captures else {
                    continue
                }
                
                let binary = convertor(captures)
                binary.executable = binary.name == crash.appName
                crash.binaryImages.append(binary)
            }
        }
    }
    
    static func parseCrashedThreadRange(_ content: String, crash: inout Crash, regex: Regex) {
        if let match = regex.firstMatch(in: content) {
            crash.crashedThreadRange = match.range
        }
    }
    
    static func parseAppBacktrackRanges(_ content: String, crash: inout Crash, constructor:((String)->Regex?)) {
        let embeddedBinaries = crash.embeddedBinaries.map { $0.name }
        for binary in embeddedBinaries {
            guard let regex = constructor(binary) else {
                continue
            }
            
            regex.matches(in: content)?.forEach({ match in
                crash.appBacktraceRanges.append(match.range)
            })
        }
    }
}

extension Regex {
    func value(in string: String) -> String? {
        return self.firstMatch(in: string)?.captures?[1]
    }
}

// MARK: - Apple
extension Regex {
    // 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
    static let frame = try! Regex("^\\s*(\\d{1,3})\\s+([^ ]+)\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)", options: .anchorsMatchLines)
    
    // 0x19a8d8000 - 0x19a8f4fff libsystem_m.dylib arm64  <ee3277089d2b310c81263e5fbcbb3138> /usr/lib/system/libsystem_m.dylib
    static let image = try! Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+([^\\s]+)\\s*(\\w+)\\s*<(.*)> (.*)")
    
    // Thread 0:
    // Thread 0 Crashed:
    // Thread 0 name xxxxxx
    static let thread = try! Regex("Thread (\\d{1,3})(?:[: ])(?:(?:(Crashed):)|(?:name:\\s+(.*)))*$")
    
    // Process demo [1111]
    static let process = try! Regex("^Process:\\s*([^\\s]+)\\s*\\[*", options: .anchorsMatchLines)
    
    // Identifier:          im.zorro.demo
    static let identifier = try! Regex("^Identifier:\\s*([^\\s]+)", options: .anchorsMatchLines)
    
    // Hardware Model:      iPhone5,2
    static let hardware = try! Regex("Hardware Model:\\s*([^\\s]+)", options: .caseInsensitive)
    
    // Frame with specified binary
    static func frame(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        return try? Regex("^\\s*(\\d{1,3})\\s+(\(binary))\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)", options: options)
    }
    
    // Image with specified binary
    static func image(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        return try? Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+(\(binary))\\s*(\\w+)\\s*<(.*)>", options: options)
    }
    
    // UUID: E5B0A378-6816-3D90-86FD-2AEF15894A85
    static let uuid = try! Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", options: [.anchorsMatchLines, .caseInsensitive])
    
    // Thread 55 Crashed:
    static let threadCrashed = try! Regex("(?:^Thread \\d+.*\n)*^Thread \\d+ Crashed:\\s*\n(?:^\\s*\\d{1,3}.*\n)+", options: .anchorsMatchLines)
    
    // OS Version:          iPhone OS 11.4 (15F79)
    static let osVersion = try! Regex("^OS Version:\\s*(.*)", options: .anchorsMatchLines)
    
    // Version:             521 (5.7.8)
    static let version = try! Regex("^Version:\\s*(.*)", options: .anchorsMatchLines)
}

struct AppleParser: CrashParser {
    static func match(_ content: String) -> Bool {
        return true  //cover all
    }
    
    func parse(_ content: String) -> Crash {
        var crash = Crash(content)
        
        let regexMap: RegexHelper.KeyValueRegexMap = [
            \.appName: .process,
            \.device: .hardware,
            \.bundleID: .identifier,
            \.osVersion: .osVersion,
            \.appVersion: .version
        ]
        RegexHelper.parseBaseInfo(content, crash: &crash, map: regexMap)
        
        if let binary = crash.appName,
           let imageRegex = Regex.image(binary, options:[]),
           let captures = imageRegex.firstMatch(in: content)?.captures {
            crash.uuid = captures[4].uuidFormat()
            crash.arch = captures[3]
        }
        
        RegexHelper.parseBinaries(content, crash: &crash, regex: .image) { captures in
            return Binary(name: captures[2],
                          uuid: captures[4].uuidFormat(),
                          arch: captures[3],
                          loadAddress: captures[1],
                          path: captures[5])
        }
        
        // backtrace
        RegexHelper.parseCrashedThreadRange(content, crash: &crash, regex: .threadCrashed)
        RegexHelper.parseAppBacktrackRanges(content, crash: &crash) { binary in
            return Regex.frame(binary)
        }
  
        return crash
    }
}

// MARK: - CPU Usage
extension Regex {
    // Powerstats for:  demo [28286]
    static let powerstats = try! Regex("^Powerstats for:\\s*([^\\s]+)\\s*\\[*", options: .anchorsMatchLines)
    
    // Architecture:    arm64
    static let architecture = try! Regex("^Architecture:\\s*([^\\s]+)\\s*", options: .anchorsMatchLines)
    
    // App version:         5.7.8
    static let appVersion = try! Regex("^App version:\\s*(.*)", options: .anchorsMatchLines)
    
    // Build version:       521
    static let buildVersion = try! Regex("^Build version:\\s*(.*)", options: .anchorsMatchLines)
    
    // Path: /private/var/containers/Bundle/Application/xxx
    static let path = try! Regex("^Path:\\s*([^\\s]+)\\s*", options: .anchorsMatchLines)
    
    // 0x100874000 -   ???  com.your.app 5.8.0 (5044) <425D7866-BFF0-3D9C-B354-07057F9A903A> /private/var/containers/Bundle/Application/DACCA9B7-C6CD-4FBF-A2A2-2C78701748AA/demo.app/demo
    static func image(withPath path: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        return try? Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-.*<(.*)>\\s+\(path)", options: options)
    }
    
    // 0x18876d000 -        0x188790fff  libsystem_malloc.dylib  <6E321806-C54E-31DB-B4A8-9DEC04A5CA2C>  /usr/lib/system/libsystem_malloc.dylib
    // 0x18876d000 -        ???          libsystem_malloc.dylib  <6E321806-C54E-31DB-B4A8-9DEC04A5CA2C>  /usr/lib/system/libsystem_malloc.dylib
    // 0x18876d000 -        ???          libsystem_malloc.dylib 123 (1.1.1)  <6E321806-C54E-31DB-B4A8-9DEC04A5CA2C>  /usr/lib/system/libsystem_malloc.dylib
    static let cpuUsageImage = try! Regex("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+[^\\s]+\\s+([^\\s]+).*\\s*<(.*)> (.*)")
    
    // 2   -[NSRunLoop run] + 87 (Foundation + 512424) [0x182f721a8]
    // 2   -[TheClass function:] (xxx.m:1476 in binary + 12591292) [0x101b720bc]
    // 2   ??? (AGXMetalA11 + 553492) [0x1aaa7f214]
    static let cpuUsageFrame = try! Regex("^.*[\\( ](.*) \\+ \\d+\\) \\[(0[xX][A-Fa-f0-9]+)\\].*", options: .anchorsMatchLines)
    
    static func cpuUsageFrame(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> Regex? {
        //4  function_name (file.name:90 in binary + 869436) [0x1050a843c]
        //2   ??? (binary + 41878904) [0x1032d0578]
        return try? Regex("^\\s*\\d+.*(\(binary)).*\\[(0[xX][A-Fa-f0-9]+)\\].*", options: options)
    }
}

struct CPUUsageParser: CrashParser {
    static func match(_ content: String) -> Bool {
        return (content.contains("Wakeups limit")
                || content.contains("CPU limit"))
        && content.contains("Limit duration:")
    }

    func parse(_ content: String) -> Crash {
        var crash = Crash(content)
        
        let regexMap: RegexHelper.KeyValueRegexMap = [
            \.appName: .powerstats,
            \.device: .hardware,
            \.arch: .architecture,
            \.osVersion: .osVersion,
        ]
        RegexHelper.parseBaseInfo(content, crash: &crash, map: regexMap)
        
        crash.appVersion = self.parseAppVersion(content)
        let path = Regex.path.value(in: content)
        if path != nil,
           let regex = Regex.image(withPath: path!),
           let captures = regex.firstMatch(in: content)?.captures {
            crash.uuid = captures[2].uuidFormat()
        }
        
        RegexHelper.parseBinaries(content, crash: &crash, regex: .cpuUsageImage) { captures in
            var name: String = captures[2]
            let binaryPath = captures[4].strip()
            if path != nil && path == binaryPath {
                name = path!.components(separatedBy: "/").last!
            }
            return Binary(name: name,
                          uuid: captures[3].uuidFormat(),
                          arch: nil,
                          loadAddress: captures[1],
                          path: binaryPath)
        }
        
        // backtrace
        RegexHelper.parseCrashedThreadRange(content, crash: &crash, regex: .threadCrashed)
        RegexHelper.parseAppBacktrackRanges(content, crash: &crash) { binary in
            return Regex.cpuUsageFrame(binary)
        }
        
        return crash
    }
    
    private func parseAppVersion(_ content: String) -> String? {
        if let app = Regex.appVersion.value(in: content),
           let build = Regex.buildVersion.value(in: content) {
            return "\(app) (\(build))"
        }
        
        guard let versionString = Regex.version.value(in: content) else {
            return nil
        }
        
        return versionString
    }
}

// MARK: - Fabric
extension Regex {
    static let hashDevice = try! Regex("^# Device:\\s*(.+)", options: .anchorsMatchLines)
    static let hashAppVersion = try! Regex("^# Version:\\s*(.+)", options: .anchorsMatchLines)
    static let hashPlatform = try! Regex("^# Platform:\\s*(.+)", options: .anchorsMatchLines)
    static let hashOSVersion = try! Regex("^# OS Version:\\s*([^\\(]+)", options: .anchorsMatchLines)
    static let hashBundleID = try! Regex("^# Bundle Identifier:\\s*(.*)", options: .anchorsMatchLines)
}

struct FabricParser: CrashParser {
    static func match(_ content: String) -> Bool {
        return content.contains("# Crashlytics - plaintext stacktrace")
    }

    func parse(_ content: String) -> Crash {
        var crash = Crash(content)
        let regexMap: RegexHelper.KeyValueRegexMap = [
            \.device: .hashDevice,
            \.osVersion: .hashOSVersion,
            \.appVersion: .hashAppVersion,
            \.bundleID: .hashBundleID
        ]
        RegexHelper.parseBaseInfo(content, crash: &crash, map: regexMap)
        
        if let osVersion = crash.osVersion, let platform = Regex.hashPlatform.value(in: content) {
            crash.osVersion = "\(platform) \(osVersion)"
        }
        
        RegexHelper.parseBinaries(content, crash: &crash, regex: .image) { captures in
            return Binary(name: captures[2],
                          uuid: captures[4].uuidFormat(),
                          arch: captures[3],
                          loadAddress: captures[1],
                          path: captures[5])
        }
        
        // backtrace
        RegexHelper.parseCrashedThreadRange(content, crash: &crash, regex: .threadCrashed)
        RegexHelper.parseAppBacktrackRanges(content, crash: &crash) { binary in
            return Regex.frame(binary)
        }
        
        return crash
    }
}

// MARK: - Umeng
extension Regex {
    // Binary Image: demo
    static let binaryImage = try! Regex("Binary Image:\\s*([^\\s]+)")
    
    // dSYM UUID: 45AF800D-B56A-39D8-AB1C-AD0F3208EC50
    static let dsymUUID = try! Regex("dSYM UUID:\\s*([^\\s]+)")
    
    // Slide Address: 0x0000000100000000
    static let slideAddress = try! Regex("Slide Address:\\s*([^\\s]+)")
    
    // CPU Type: arm64
    static let cpuType = try! Regex("CPU Type:\\s*([^\\s]+)")
}

struct UmengParser: CrashParser {
    static func match(_ content: String) -> Bool {
        return content.contains("dSYM UUID") && content.contains("Slide Address")
    }

    func parse(_ content: String) -> Crash {
        var crash = Crash(content)
        let regexMap: RegexHelper.KeyValueRegexMap = [
            \.appName: .binaryImage,
            \.uuid: .dsymUUID,
            \.arch: .cpuType,
        ]
        RegexHelper.parseBaseInfo(content, crash: &crash, map: regexMap)
        
        guard let appName = crash.appName, let frameRegex = Regex.frame(appName) else {
            return crash
        }
        
        let loadAddress = Regex.slideAddress.value(in: content)
        
        var backtrace: [Frame] = []
        frameRegex.matches(in: content)?.forEach({ match in
            if let captures = match.captures {
                crash.appBacktraceRanges.append(match.range)
                let frame = Frame(raw: captures[0],
                                  index: captures[1],
                                  image: captures[2],
                                  address: captures[3],
                                  symbol: captures[4])
                backtrace.append(frame)
            }
        })

        let binary = Binary(name: appName,
                            uuid: crash.uuid,
                            arch: crash.arch,
                            loadAddress: loadAddress,
                            path: "/var/containers/Bundle/Application/\(appName)") //fake path
        binary.backtrace = backtrace
        crash.binaryImages.append(binary)
        
        return crash
    }
}


extension Crash {
    static func parser(for content: String) -> CrashParser {
        if UmengParser.match(content) {
            return UmengParser()
        }
        if CPUUsageParser.match(content) {
            return CPUUsageParser()
        }
        if FabricParser.match(content) {
            return FabricParser()
        }
        return AppleParser()
    }
    
    static func parse(_ content: String) -> Crash {
        let parser = self.parser(for: content)
        return parser.parse(content)
    }
}
