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

func parseBacktrace(input: String) -> [String] {
    let btPattern = "^(\\d{1,3})\\s+([^ ]+)\\s+(0[xX][A-Fa-f0-9]+)\\s+(.*)"
    let matcher: RegexHelper
    do {
        matcher = try RegexHelper(btPattern)
    } catch _ {
        return []
    }
    return matcher.match(input)
}

// 0       TheElements   0x00000001000effdc 0x1000e4000 + 49116
// index   image         address            symbol

class Frame {
    var index: String
    var image: String
    var address: String
    var symbol: String?
    var raw: String
    var lineNumber: Int?
    
    init?(input: String) {
        self.raw = input
        let groups = parseBacktrace(input)
        if groups.count != 5 {
            return nil
        }
        
        self.index = groups[1]
        self.image = groups[2]
        self.address = groups[3]
        self.symbol = groups[4]
    }
}


// MARK: - Crash

// MARK: Crash line
enum LineType: Int {
    case Plain
    case Reason
    case Info
    case Backtrace
    case Arch
    case LoadAddress
    case SlideAddress
    case UUID
    case Binary
}

struct LineEntry {
    var type: LineType = .Plain
    var value: String
}

// MARK: Crash class
class Crash {
    var lines = [LineEntry]()
    var reason: String?
    var crashInfo: String?
    var arch: String = "arm64"
    var loadAddress: String?
    var uuid: String?
    var binary: String?
    var backtrace = [Int: Frame]()
    var filePath: String?
    var isChanged: Bool = false
    
    var appVersion: String?
    var numberOfErrors: Int?
    
    init(content: String?) {
        if content == nil {
            return
        }
        let lines = content!.componentsSeparatedByString("\n")
        for line in lines {
            self.lines.append(LineEntry(type: .Plain, value: line))
        }
    }
    
    func isValid() -> Bool {
        return self.uuid != nil
            && self.binary != nil
            && self.loadAddress != nil
    }
    
    func isEmpty() -> Bool {
        return self.lines.count == 0 && self.filePath == nil
    }
    
    func keyFrames() -> [Frame]? {
        if self.binary == nil {
            return nil
        }
        
        return self.backtrace.values.filter{
            (frame: Frame) -> Bool in
            return frame.image == self.binary!
        }
    }
}