// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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

    @IBOutlet weak var fontNameButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        let font = Config.editorFont
        self.fontNameButton.title = "\(font.fontName) \(Int(font.pointSize))"
        
        NotificationCenter.default.addObserver(self, selector: #selector(fontDidChanged(_:)), name: .configFontChanged, object: nil)
    }
    
    @IBAction func showFontPanel(_ sender: AnyObject?) {
        let fontManager = NSFontManager.shared
        fontManager.setSelectedFont(Config.editorFont, isMultiple: false)
        let panel = fontManager.fontPanel(true)
        panel?.setPanelFont(Config.editorFont, isMultiple: false)
        panel?.reloadDefaultFontFamilies()
        panel?.makeKeyAndOrderFront(self)
    }
    
    @objc func fontDidChanged(_ notification: Notification?) {
        let font = Config.editorFont
        self.fontNameButton.title = "\(font.fontName) \(Int(font.pointSize))"
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
