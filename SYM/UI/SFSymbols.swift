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

import AppKit

extension NSImage {
    static func sfSymbol(_ name: String, accessibilityDescription: String? = nil) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) else {
            return nil
        }
        // Prefer monochrome template rendering in toolbars.
        image.isTemplate = true
        return image
    }

    static var symDsymFound: NSImage? { sfSymbol("shippingbox") }
    static var symDsymMissing: NSImage? { sfSymbol("shippingbox.and.arrow.backward") }
}

extension NSToolbarItem.Identifier {
    static let symbolicate = NSToolbarItem.Identifier("ToolbarItemSymbolicate")
    static let progress = NSToolbarItem.Identifier("ToolbarItemProgress")
    static let dsym = NSToolbarItem.Identifier("ToolbarItemDsym")
    static let download = NSToolbarItem.Identifier("ToolbarItemDownload")
    static let device = NSToolbarItem.Identifier("ToolbarItemDevice")
}

extension NSToolbarItem {
    /// System-styled toolbar item using an SF Symbol image (no custom view).
    static func systemSymbolItem(
        identifier: NSToolbarItem.Identifier,
        symbolName: String,
        label: String,
        toolTip: String,
        target: AnyObject?,
        action: Selector?
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = toolTip
        item.image = NSImage.sfSymbol(symbolName, accessibilityDescription: label)
        item.target = target
        item.action = action
        item.isBordered = true
        return item
    }
}
