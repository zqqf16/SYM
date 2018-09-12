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

struct RE {
    let regex: NSRegularExpression
    
    init(_ pattern: String, options: NSRegularExpression.Options = []) throws {
        try regex = NSRegularExpression(pattern: pattern,
                                        options: options)
    }
    
    func findFirst(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> [String]? {
        if let result = regex.firstMatch(in: input, options: options, range: input.nsRange) {
            return input.matchGroups(fromResult: result)
        }
        
        return nil
    }
    
    func findAll(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> [[String]]? {
        let matches = regex.matches(in: input, options: options, range: input.nsRange)
        if matches.count == 0 {
            return nil
        }
        
        return matches.map { input.matchGroups(fromResult: $0) }
    }
    
    func match(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> [String]? {
        return findFirst(input, options: options)
    }
    
    func findAllRanges(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> [NSRange]? {
        let matches = regex.matches(in: input, options: options, range: input.nsRange)
        if matches.count == 0 {
            return nil
        }
        
        return matches.map { $0.range }
    }
    
    func findFirstRange(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> NSRange? {
        let nsRange = input.nsRange
        let range = regex.rangeOfFirstMatch(in: input, options: options, range: nsRange)
        if range.location >= nsRange.location + nsRange.length {
            return nil
        }
        
        return range
    }
}

// MARK: Apple
extension RE {
    // 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
    static let frame = try! RE("^\\s*(\\d{1,3})\\s+([^ ]+)\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)", options: .anchorsMatchLines)
    
    // 0x19a8d8000 - 0x19a8f4fff libsystem_m.dylib arm64  <ee3277089d2b310c81263e5fbcbb3138> /usr/lib/system/libsystem_m.dylib
    static let image = try! RE("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+([^\\s]+)\\s*(\\w+)\\s*<(.*)>")
    
    // Thread 0:
    // Thread 0 Crashed:
    // Thread 0 name xxxxxx
    static let thread = try! RE("Thread (\\d{1,3})(?:[: ])(?:(?:(Crashed):)|(?:name:\\s+(.*)))*$")
    
    // Process demo [1111]
    static let process = try! RE("^Process:\\s*([^\\s]+)\\s*\\[*", options: .anchorsMatchLines)

    // Identifier:          im.zorro.demo
    static let identifier = try! RE("^Identifier:\\s*([^\\s]+)", options: .anchorsMatchLines)
    
    // Hardware Model:      iPhone5,2
    static let hardware = try! RE("Hardware Model:\\s*([^\\s]+)", options: .caseInsensitive)

    // Frame with specified binary
    static func frame(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> RE? {
        return try? RE("^\\s*(\\d{1,3})\\s+(\(binary))\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)", options: options)
    }
    
    // Image with specified binary
    static func image(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> RE? {
        return try? RE("\\s*(0[xX][A-Fa-f0-9]+)\\s+-\\s+\\w+\\s+(\(binary))\\s*(\\w+)\\s*<(.*)>", options: options)
    }
    
    // UUID: E5B0A378-6816-3D90-86FD-2AEF15894A85
    static let uuid = try! RE("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{8}", options: [.anchorsMatchLines, .caseInsensitive])
    
    // Thread 55 Crashed:
    static let threadCrashed = try! RE("(?:^Thread \\d+.*\n)*^Thread \\d+ Crashed:\\s*\n(?:^\\s*\\d{1,3}.*\n)+", options: .anchorsMatchLines)
}

// MARK: CPU Usage
extension RE {
    // Powerstats for:  demo [28286]
    static let powerstats = try! RE("^Powerstats for:\\s*([^\\s]+)\\s*\\[*", options: .anchorsMatchLines)
    
    // Architecture:    arm64
    static let architecture = try! RE("^Architecture:\\s*([^\\s]+)\\s*", options: .anchorsMatchLines)
    
    // OS Version:          iPhone OS 11.4 (15F79)
    static let osVersion = try! RE("^OS Version:\\s*(.*)", options: .anchorsMatchLines)

    // Version:             521 (5.7.8)
    static let version = try! RE("^Version:\\s*(.*)", options: .anchorsMatchLines)
    
    // Path: /private/var/containers/Bundle/Application/xxx
    static let path = try! RE("^Path:\\s*([^\\s]+)\\s*", options: .anchorsMatchLines)
    
    // 0x100874000 -   ???  com.kwai.gifshow.beta 5.8.0 (5044) <425D7866-BFF0-3D9C-B354-07057F9A903A> /private/var/containers/Bundle/Application/DACCA9B7-C6CD-4FBF-A2A2-2C78701748AA/com_kwai_gif.app/com_kwai_gif
    static func image(withPath path: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> RE? {
        return try? RE("\\s*(0[xX][A-Fa-f0-9]+)\\s+-.*<(.*)>\\s+\(path)", options: options)
    }
    
    // 2   -[NSRunLoop run] + 87 (Foundation + 512424) [0x182f721a8]
    // 2   -[TheClass function:] (xxx.m:1476 in binary + 12591292) [0x101b720bc]
    // 2   ??? (AGXMetalA11 + 553492) [0x1aaa7f214]
    static let cpuUsageFrame = try! RE("^.*[\\( ](.*) \\+ \\d+\\) \\[(0[xX][A-Fa-f0-9]+)\\].*", options: .anchorsMatchLines)
    
    static func cpuUsageFrame(_ binary: String, options: NSRegularExpression.Options = .anchorsMatchLines) -> RE? {
        //4  function_name (file.name:90 in binary + 869436) [0x1050a843c]
        //2   ??? (binary + 41878904) [0x1032d0578]
        return try? RE("^\\s*\\d+.*(\(binary)).*\\[(0[xX][A-Fa-f0-9]+)\\].*", options: options)
    }
}

// MARK: Umeng
extension RE {
    // Binary Image: demo
    static let binaryImage = try! RE("Binary Image:\\s*([^\\s]+)")
    
    // dSYM UUID: 45AF800D-B56A-39D8-AB1C-AD0F3208EC50
    static let dsymUUID = try! RE("dSYM UUID:\\s*([^\\s]+)")
    
    // Slide Address: 0x0000000100000000
    static let slideAddress = try! RE("Slide Address:\\s*([^\\s]+)")
    
    // CPU Type: arm64
    static let cpuType = try! RE("CPU Type:\\s*([^\\s]+)")
}

// MARK: Fabric
extension RE {
    static let hashDevice = try! RE("^# Device:\\s*(.+)", options: .anchorsMatchLines)
    static let hashAppVersion = try! RE("^# Version:\\s*(.+)", options: .anchorsMatchLines)
    static let hashPlatform = try! RE("^# Platform:\\s*(.+)", options: .anchorsMatchLines)
    static let hashOSVersion = try! RE("^# OS Version:\\s*([^\\(]+)", options: .anchorsMatchLines)
    static let hashBundleID = try! RE("^# Bundle Identifier:\\s*(.*)", options: .anchorsMatchLines)
}
