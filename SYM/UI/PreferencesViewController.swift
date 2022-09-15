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

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet var fontNameButton: NSButton!
    @IBOutlet var colorButton: NSPopUpButton!
    @IBOutlet var colorMenu: NSMenu!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Font
        let font = Config.editorFont
        fontNameButton.title = "\(font.fontName) \(Int(font.pointSize))"

        NotificationCenter.default.addObserver(self, selector: #selector(fontDidChanged(_:)), name: .configFontChanged, object: nil)

        // Color
        setupColors()
    }

    private func setupColors() {
        colorMenu.removeAllItems()
        let currentColor = Config.highlightColor
        for colorCode in Config.highlightColors {
            guard let color = NSColor(hexString: colorCode) else {
                continue
            }
            let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            menuItem.image = NSImage(color: color, size: NSSize(width: 20, height: 10))
            menuItem.toolTip = colorCode
            colorMenu.addItem(menuItem)

            if colorCode == currentColor {
                colorButton.select(menuItem)
            }
        }
    }

    @IBAction func showFontPanel(_: AnyObject?) {
        let fontManager = NSFontManager.shared
        fontManager.setSelectedFont(Config.editorFont, isMultiple: false)
        let panel = fontManager.fontPanel(true)
        panel?.setPanelFont(Config.editorFont, isMultiple: false)
        panel?.reloadDefaultFontFamilies()
        panel?.makeKeyAndOrderFront(self)
    }

    @objc func fontDidChanged(_: Notification?) {
        let font = Config.editorFont
        fontNameButton.title = "\(font.fontName) \(Int(font.pointSize))"
    }

    @IBAction func colorDidChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem, let index = sender.menu?.index(of: selectedItem) else {
            return
        }

        Config.highlightColor = Config.highlightColors[index]
    }
}

extension PreferencesViewController: NSFontChanging {
    func changeFont(_ sender: NSFontManager?) {
        if let font = sender?.convert(Config.editorFont) {
            Config.editorFont = font
            print(font)
        }
    }
}
