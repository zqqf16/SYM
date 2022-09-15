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

import AppKit
import Foundation

// MARK: Highlight

extension NSTextStorage {
    func applyStyle(textFont: NSFont? = Config.editorFont,
                    textColor: NSColor = .textColor)
    {
        let font = textFont ?? self.font ?? layoutManagers.first?.firstTextView?.font
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        var attributes: [NSAttributedString.Key: AnyObject] = [
            .foregroundColor: textColor,
            .paragraphStyle: style,
        ]
        if font != nil {
            attributes[.font] = font!
        }

        setAttributes(attributes, range: string.nsRange)
    }

    func highlight(at ranges: [NSRange]) {
        var attributes: [NSAttributedString.Key: AnyObject] = [:]
        attributes[.foregroundColor] = NSColor(hexString: Config.highlightColor)!
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        attributes[.paragraphStyle] = style
        if let font = font, let familyName = font.familyName {
            // .font: NSFontManager.shared.font(withFamily: "Menlo", traits: .boldFontMask, weight: 0, size: 11)!
            attributes[.font] = NSFontManager.shared.font(withFamily: familyName, traits: .boldFontMask, weight: 0, size: font.pointSize)
        }
        for range in ranges {
            setAttributes(attributes, range: range)
        }
    }
}
