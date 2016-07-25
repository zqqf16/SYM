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
import Cocoa


let defaultAttrs: [String: AnyObject] = [
    NSFontAttributeName: NSFont(name: "Menlo", size: 11)!
]

let backtraceAttrs:[String: AnyObject] = [
    NSForegroundColorAttributeName: NSColor.redColor(),
    NSFontAttributeName: NSFontManager.sharedFontManager().fontWithFamily("Menlo", traits: .BoldFontMask, weight: 0, size: 11)!
]


extension Crash {
    func pretty() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let newLine = NSMutableAttributedString(string: "\n")
        for (index, line) in self.lines.enumerate() {
            result.appendAttributedString(self.pretty(index, line: line))
            result.appendAttributedString(newLine)
        }
        
        return result
    }
    
    func pretty(index: Int, line: LineEntry) -> NSAttributedString {
        switch line.type {
        case .Backtrace:
            let frame = self.backtrace[index]!
            let frameStr = self.formatFrame(frame)
            if frame.image == self.binary {
                return NSAttributedString(string: frameStr, attributes: backtraceAttrs)
            } else {
                return NSAttributedString(string: frameStr, attributes: defaultAttrs)
            }
        default:
            return NSAttributedString(string: line.value, attributes: defaultAttrs)
        }
    }
    
    func formatFrame(frame: Frame) -> String {
        let index = frame.index.extendToLength(2)
        let image = frame.image.extendToLength(30)
        let address = frame.address.extendToLength(18)
        
        return "  \(index) \(image) \(address) \(frame.symbol!)"
    }
}