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

let backtraceAttrs: [String: AnyObject] = [
    NSForegroundColorAttributeName: NSColor.red,
    NSFontAttributeName: NSFontManager.shared().font(withFamily: "Menlo", traits: .boldFontMask, weight: 0, size: 11)!
]

extension CrashReport.Frame {
    func description() -> String {
        let index = self.index.extendToLength(2)
        let image = self.image.extendToLength(30)
        let address = self.address.extendToLength(18)
        let symbol = self.symbol ?? ""
        return "\(index) \(image) \(address) \(symbol)"
    }
}

extension CrashReport {

    func pretty() -> NSAttributedString {
        guard let content = self.content else {
            return NSAttributedString()
        }
        
        var keyFrameRanges = [NSRange]()
        
        if self.threads.count == 0 {
            return NSAttributedString(string: content, attributes: defaultAttrs)
        }
        
        var backtrace: [Int: CrashReport.Frame] = [:]
        
        for thread in self.threads {
            for frame in thread.backtrace {
                backtrace[frame.line] = frame
            }
        }
        
        if backtrace.count == 0 {
            return NSAttributedString(string: self.content!, attributes: defaultAttrs)
        }
        
        let lines = content.components(separatedBy: "\n")
        let result = NSMutableString()
        
        for (index, line) in lines.enumerated() {
            if let frame = backtrace[index] {
                if frame.isKey {
                    let startIndex = result.length
                    result.append(frame.description())
                    let endIndex = result.length
                    keyFrameRanges.append(NSMakeRange(startIndex, endIndex-startIndex))
                } else {
                    result.append(frame.description())
                }
            } else {
                result.append(line)
            }
            
            result.append("\n")
        }
        
        // Remove the last "\n".
        result.deleteCharacters(in: NSMakeRange(result.length - 1, 1))
        
        let attr = NSMutableAttributedString(string: (result as String), attributes: defaultAttrs)
        
        for r in keyFrameRanges {
            attr.setAttributes(backtraceAttrs, range: r)
        }
        
        return attr
    }
}
