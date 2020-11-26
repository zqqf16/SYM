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
import Combine

extension NSViewController {
    func windowController() -> MainWindowController? {
        return self.view.window?.windowController as? MainWindowController
    }
}

class ContentViewController: NSViewController {
    @IBOutlet var textView: TextView!
    @IBOutlet var infoLabel: NSTextField!
    @IBOutlet var splitView: NSSplitView!
    @IBOutlet var bottomBar: NSView!
    
    private var font: NSFont = Config.editorFont
    private var cancellable: AnyCancellable?

    var document: CrashDocument? {
        didSet {
            self.cancellable?.cancel()
            guard let document = document else {
                return
            }

            self.textView.layoutManager?.replaceTextStorage(document.textStorage)
            self.cancellable = document.$crashInfo
                .sink { [weak self] (crashInfo) in
                    self?.update(crashInfo: crashInfo)
                }
            self.update(crashInfo: document.crashInfo)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.toggleBottomBar(false)
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configFontChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configColorChanged, object: nil)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.setupTextView()
    }
    
    private func toggleBottomBar(_ show: Bool) {
        self.bottomBar.isHidden = !show
        self.splitView.adjustSubviews()
    }

    private func setupTextView() {
        self.textView.font = self.font
        self.textView.textContainerInset = CGSize(width: 0, height: 4)
        self.textView.allowsUndo = true
        self.textView.delegate = self
        
        self.textView.lnv_setUpLineNumberView()
        
        /* horizontally scrolling
        //self.textView.isHorizontallyResizable = true
        self.textView.textContainer?.widthTracksTextView = false
        self.textView.textContainer?.containerSize = NSMakeSize(CGFloat(Float.greatestFiniteMagnitude), CGFloat(Float.greatestFiniteMagnitude))
        //self.textView.textContainer?.containerSize = self.textView.maxSize
         */
        self.textView.layoutManager?.allowsNonContiguousLayout = false
    }
    
    func textDidChange(_ notification: Notification) {
        self.update(crashInfo: self.document?.crashInfo)
    }
    
    private func infoString(fromCrash crash: CrashInfo) -> String {
        var info = ""
        var divider = ""
        if let device = crash.device {
            info += "🏷 " + modelToName(device)
            divider = " - "
        }
        if let osVersion = crash.osVersion {
            info += "\(divider)\(osVersion)"
        }
        
        if let appVersion = crash.appVersion {
            info += "\(divider)\(appVersion)"
        }
        
        return info
    }
    
    func update(crashInfo: CrashInfo?) {
        self.updateHighlighting(crashInfo)
        self.updateSummary(crashInfo)
    }
    
    private func updateHighlighting(_ crashInfo: CrashInfo?) {
        guard let textStorage = self.textView.textStorage else {
            return
        }
        self.textView.font = self.font
        textStorage.beginEditing()
        textStorage.font = self.font
        let ranges = crashInfo?.appBacktraceRanges() ?? []
        textStorage.processHighlighting(ranges)
        textStorage.endEditing()
    }
    
    private func updateSummary(_ crashInfo: CrashInfo?) {
        guard let info = crashInfo else {
            self.toggleBottomBar(false)
            return
        }
        self.infoLabel.stringValue = self.infoString(fromCrash: info)
        self.toggleBottomBar(true)
    }
    
    @objc func configFontDidChanged(_ notification: Notification) {
        self.font = Config.editorFont
        self.update(crashInfo: self.document?.crashInfo)
    }
}

extension ContentViewController: NSTextViewDelegate {
    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        let menu = NSMenu(title: "dSYM")
        let showItem = NSMenuItem(title: "Symbolicate", action: #selector(symbolicate), keyEquivalent: "")
        showItem.isEnabled = true
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        return menu
    }
    
    @objc func symbolicate(_ sender: AnyObject?) {
        self.windowController()?.symbolicate(sender)
    }
}

extension ContentViewController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        return NSZeroRect
    }
}

extension ContentViewController {
    @IBAction func scrollToTarget(_ sender: AnyObject?) {
        guard let crashInfo = self.document?.crashInfo, let range = crashInfo.crashedThreadRange() else {
            return
        }
        
        self.textView.scrollRangeToVisible(range)
        self.textView.highlight(range)
    }
    
    @IBAction func zoomIn(_ sender: AnyObject?) {
        let size = min(self.font.pointSize + 1, 20.0)
        self.font = NSFont(name: self.font.fontName, size: size)!
        self.update(crashInfo: self.document?.crashInfo)
    }
    
    @IBAction func zoomOut(_ sender: AnyObject?) {
        let size = max(self.font.pointSize - 1, 10.0)
        self.font = NSFont(name: self.font.fontName, size: size)!
        self.update(crashInfo: self.document?.crashInfo)
    }
}

// Mark: Highlight
extension NSTextStorage {
    func processHighlighting(_ ranges:[NSRange]) {
        let style: NSMutableParagraphStyle = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        var defaultAttrs: [NSAttributedString.Key: AnyObject] = [
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style,
        ]
        
        if let font = self.font {
            defaultAttrs[.font] = font
        }
        self.setAttributes(defaultAttrs, range: self.string.nsRange)
        
        var attrs = defaultAttrs
        attrs[.foregroundColor] = NSColor(hexString: Config.highlightColor)!
        if let font = self.font, let familyName = font.familyName {
            //.font: NSFontManager.shared.font(withFamily: "Menlo", traits: .boldFontMask, weight: 0, size: 11)!
            attrs[.font] = NSFontManager.shared.font(withFamily: familyName, traits: .boldFontMask, weight: 0, size: font.pointSize)
        }
        for range in ranges {
            self.setAttributes(attrs, range: range)
        }
    }
}
