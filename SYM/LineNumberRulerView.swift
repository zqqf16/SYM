//
//  LineNumberRulerView.swift
//  LineNumber
//
//  Copyright (c) 2015 Yichi Zhang. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

import AppKit
import Foundation

/// Line-number gutter drawn beside an `NSScrollView` (not as an `NSRulerView`).
/// Using a sibling gutter avoids AppKit ruler tiling that can shift the text
/// view horizontally and hide the leading columns.
final class LineNumberGutterView: NSView {
    static let defaultWidth: CGFloat = 44

    private weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?
    private var observers: [NSObjectProtocol] = []

    override var isFlipped: Bool { true }

    deinit {
        detach()
    }

    func attach(textView: NSTextView, scrollView: NSScrollView) {
        detach()
        self.textView = textView
        self.scrollView = scrollView

        scrollView.contentView.postsBoundsChangedNotifications = true
        textView.postsFrameChangedNotifications = true

        let center = NotificationCenter.default
        let refresh: (Notification) -> Void = { [weak self] _ in
            self?.needsDisplay = true
        }

        observers = [
            center.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main, using: refresh),
            center.addObserver(forName: NSView.frameDidChangeNotification, object: textView, queue: .main, using: refresh),
            center.addObserver(forName: NSText.didChangeNotification, object: textView, queue: .main, using: refresh),
        ]
        needsDisplay = true
    }

    func detach() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        textView = nil
        scrollView = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        separator.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        NSColor.separatorColor.setStroke()
        separator.lineWidth = 1
        separator.stroke()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return
        }

        let visibleRect = textView.visibleRect
        let textContainerOrigin = textView.textContainerOrigin
        let font = textView.font ?? NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard visibleGlyphRange.length > 0 || textView.string.isEmpty else {
            return
        }

        let firstVisibleCharacterIndex = layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location)
        let newLineRegex = try! NSRegularExpression(pattern: "\n", options: [])
        var lineNumber = newLineRegex.numberOfMatches(
            in: textView.string,
            options: [],
            range: NSRange(location: 0, length: firstVisibleCharacterIndex)
        ) + 1

        var glyphIndexForStringLine = visibleGlyphRange.location
        let visibleGlyphEnd = NSMaxRange(visibleGlyphRange)

        while glyphIndexForStringLine < visibleGlyphEnd {
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndexForStringLine)
            let characterRangeForStringLine = (textView.string as NSString).lineRange(
                for: NSRange(location: characterIndex, length: 0)
            )
            let glyphRangeForStringLine = layoutManager.glyphRange(
                forCharacterRange: characterRangeForStringLine,
                actualCharacterRange: nil
            )

            var glyphIndexForGlyphLine = glyphIndexForStringLine
            var glyphLineCount = 0

            while glyphIndexForGlyphLine < NSMaxRange(glyphRangeForStringLine) {
                var effectiveRange = NSRange(location: 0, length: 0)
                let lineRect = layoutManager.lineFragmentRect(
                    forGlyphAt: glyphIndexForGlyphLine,
                    effectiveRange: &effectiveRange,
                    withoutAdditionalLayout: true
                )

                let y = lineRect.minY + textContainerOrigin.y - visibleRect.origin.y
                let label = glyphLineCount > 0 ? "-" : "\(lineNumber)"
                let attributed = NSAttributedString(string: label, attributes: attributes)
                let size = attributed.size()
                attributed.draw(at: NSPoint(x: bounds.width - size.width - 6, y: y))

                glyphLineCount += 1
                glyphIndexForGlyphLine = NSMaxRange(effectiveRange)
            }

            glyphIndexForStringLine = NSMaxRange(glyphRangeForStringLine)
            lineNumber += 1
        }

        if layoutManager.extraLineFragmentTextContainer != nil {
            let y = layoutManager.extraLineFragmentRect.minY + textContainerOrigin.y - visibleRect.origin.y
            let attributed = NSAttributedString(string: "\(lineNumber)", attributes: attributes)
            let size = attributed.size()
            attributed.draw(at: NSPoint(x: bounds.width - size.width - 6, y: y))
        }
    }
}
