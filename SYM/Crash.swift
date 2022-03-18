// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
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

class Crash {
    let content: String
    
    var appName: String?
    var device: String?
    var bundleID: String?
    var arch: String? = "arm64"
    var uuid: String?
    var osVersion: String?
    var appVersion: String?
    var binaryImages: [Binary] = []
    
    var crashedThreadRange: NSRange?
    var appBacktraceRanges: [NSRange] = []
    
    var embeddedBinaries: [Binary] {
        // executable, embedded dynamic libraries
        return binaryImages.filter { $0.inApp }
    }
    
    enum SymbolicateMethod {
        case atos
        case symbolicatecrash // buildin symbolicatecrash
    }
    
    var symbolicateMethod: SymbolicateMethod = .symbolicatecrash
    
    init(_ content: String) {
        self.content = content
    }
}
