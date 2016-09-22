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


// MARK: - Bracktrace Frame

// 0       BinaryName    0x00000001000effdc 0x1000e4000 + 49116
// index   image         address            symbol

class Frame {
    var index: String
    var image: String
    var address: String
    var symbol: String?
    var lineNumber: Int?
    
    static let re = RE.compile("^\\s*(\\d{1,3})\\s+([^ ]+)\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)")!
    
    init?(line: String) {
        guard let g = Frame.re.match(line) else {
            return nil
        }
        
        self.index = g[0]
        self.image = g[1]
        self.address = g[2]
        self.symbol = g[3]
        self.lineNumber = nil
    }
}

class Image {
    var name: String?
    var uuid: String?
    var loadAddress: String?
    var backtrace: [Frame]?
}

class Crash {
    let content: String
    var reason: String?
    var arch: String = "arm64"
    var appName: String?
    var images:[String: Image]?
    
    init(content: String) {
        self.content = content
    }
}

enum CrashType: Int {
    case umeng = 0
    case apple = 1
    case csv = 2
    
    static func fromContent(_ content: String?) -> CrashType? {
        guard let crash = content else {
            return nil
        }
        
        if crash.contains("摘要,应用版本,错误次数") {
            return .csv
        } else if crash.contains("Application received") {
            return .umeng
        } else if crash.contains("Incident Identifier") {
            return .apple
        }
        
        return nil
    }
}
