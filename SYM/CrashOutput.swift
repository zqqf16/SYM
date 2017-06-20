// The MIT License (MIT)
//
// Copyright (c) 2017 zqqf16
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

struct Style {
    static let plain = Style([.font: NSFont(name: "Menlo", size: 11)!])
    static let keyFrame = Style([
        .foregroundColor: NSColor.red,
        .font: NSFontManager.shared.font(withFamily: "Menlo", traits: .boldFontMask, weight: 0, size: 11)!
    ])
    
    let attrs: [NSAttributedStringKey: AnyObject]
    init(_ attrs: [NSAttributedStringKey: AnyObject]) {
        self.attrs = attrs
    }
}

extension Crash {
    func pretty() -> NSAttributedString {
        let lines = self.content.components(separatedBy: "\n")
        let result = NSMutableString()
        var keyFrameRanges = [NSRange]()
        
        for line in lines {
            if let group = LineRE.frame.match(line) {
                let frame = Frame(index: group[0], image: group[1], address: group[2], symbol: group[3])
                if frame.image == self.appName {
                    let startIndex = result.length
                    result.append(frame.description)
                    let endIndex = result.length
                    keyFrameRanges.append(NSMakeRange(startIndex, endIndex-startIndex))
                } else {
                    result.append(frame.description)
                }
            } else {
                result.append(line)
            }
            
            result.append("\n")
        }
        
        // Remove the last "\n"
        result.deleteCharacters(in: NSMakeRange(result.length - 1, 1))
        
        let attr = NSMutableAttributedString(string: result as String, attributes: Style.plain.attrs)
        for r in keyFrameRanges {
            attr.setAttributes(Style.keyFrame.attrs, range: r)
        }
        
        return attr
    }
}
