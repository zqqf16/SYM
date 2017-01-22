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


class CrashReport {
    enum Brand {
        case umeng
        case apple
        case bugly
        case unknow
    }
    
    class Frame: NSObject {
        var index: String
        var image: String
        var address: String
        var line: Int
        var symbol: String?
        var isKey: Bool = false
        
        init(index: String, image: String, address: String, line: Int) {
            self.index = index
            self.image = image
            self.address = address
            self.line = line
        }
        
        override var description: String {
            let index = self.index.extendToLength(2)
            let image = self.image.extendToLength(26)
            let address = self.address.extendToLength(18)
            let symbol = self.symbol ?? ""
            return "\(index) \(image) \(address) \(symbol)"
        }
    }
    
    class Image {
        var name: String
        var uuid: String?
        var loadAddress: String?
        var dSym: String?
        var backtrace: [Frame] = []

        init(name: String) {
            self.name = name
        }
    }
    
    class Thread {
        var number: Int?
        var name: String?
        var crashed: Bool = false
        var backtrace: [Frame] = []
        
        var description: String {
            let num = self.number != nil ? " \(self.number!)": ""
            let name = self.name != nil ? " name: \(self.name!)": ""
            let crashed = self.crashed ? " [Crashed]": ""
            return "Thread\(num)\(name)\(crashed)"
        }
    }
    
    var content: String?
    var brand: Brand = .unknow
    var reason: String?
    var arch: String = "arm64"
    var appName: String?
   
    var version: String?
    var osVersion: String?
    var device: String?
    
    var images:[String: Image] = [:]
    var threads: [Thread] = []
    
    var needSymbolicate: Bool {
        if self.brand == .umeng {
            return true
        }
        
        for thread in self.threads {
            for frame in thread.backtrace {
                if frame.symbol == nil || frame.symbol!.hasPrefix("0x") {
                    return true
                }
            }
        }
        return false
    }
}
