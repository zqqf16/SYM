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

extension NSViewController {
    func windowController() -> MainWindowController? {
        return self.view.window?.windowController as? MainWindowController
    }
}

class ContentViewController: NSViewController {
    @IBOutlet var textView: NSTextView!
    @IBOutlet var infoLabel: NSTextField!
    @IBOutlet var splitView: NSSplitView!
    @IBOutlet var bottomBar: NSView!
    @IBOutlet var binaryButton: NSPopUpButton!
    
    private let lastSelectedBinaryKey = "lastSelectedBinaryName"
    
    var selectedBinaryName: String? {
        didSet {
            UserDefaults.standard.setValue(selectedBinaryName, forKey: self.lastSelectedBinaryKey)
        }
    }
    
    private let font: NSFont = NSFont(name: "Menlo", size: 11)!

    var document: CrashDocument? {
        didSet {
            guard let document = document else {
                return
            }
            self.textView.layoutManager?.replaceTextStorage(document.textStorage)
            self.textView.font = self.font
            self.updateCrashInfo()
            
            document.notificationCenter.addObserver(forName: .crashSymbolicated, object: nil, queue: nil) {  [weak self] (notification) in
                self?.updateCrashInfo()
            }
            document.notificationCenter.addObserver(forName: .crashDidOpen, object: nil, queue: nil) {  [weak self] (notification) in
                self?.textView.font = self?.font
                self?.updateCrashInfo()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTextView()
        self.toggleBottomBar(false)
    }
    
    private func toggleBottomBar(_ show: Bool) {
        self.bottomBar.isHidden = !show
        self.splitView.adjustSubviews()
    }

    private func setupTextView() {
        self.textView.font = self.font
        self.textView.textContainerInset = CGSize(width: 10, height: 10)
        self.textView.allowsUndo = true
        self.textView.delegate = self
    }
    
    func textDidChange(_ notification: Notification) {
        self.updateCrashInfo()
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
    
    func updateCrashInfo() {
        guard let document = self.document else {
            return
        }
        
        let crashInfo = document.crashInfo
        let binary = self.selectedBinaryName ?? crashInfo?.appName ?? (UserDefaults.standard.value(forKey: self.lastSelectedBinaryKey) as? String)
        
        self.updateHighlighting(crashInfo, binary: binary)
        self.updateSummary(crashInfo, binary: binary)
        self.updateBinaryButton(crashInfo, binary: binary)
    }
    
    private func updateHighlighting(_ crashInfo: CrashInfo?, binary: String?) {
        if let textStorage = self.textView.textStorage,
            let binaryName = binary,
            let ranges = crashInfo?.backgraceRanges(withBinary: binaryName) {
            textStorage.beginEditing()
            textStorage.processHighlighting(ranges)
            textStorage.endEditing()
        }
    }
    
    private func updateSummary(_ crashInfo: CrashInfo?, binary: String?) {
        guard let info = crashInfo else {
            self.toggleBottomBar(false)
            return
        }
        self.infoLabel.stringValue = self.infoString(fromCrash: info)
        self.toggleBottomBar(true)
    }
    
    private func updateBinaryButton(_ crashInfo: CrashInfo?, binary: String?) {
        guard let info = crashInfo else {
            self.binaryButton.isHidden = true
            return
        }
        
        if let binaries = info.allBinaryImages() {
            self.binaryButton.isHidden = false
            self.binaryButton.addItems(withTitles: binaries.sorted())
            self.binaryButton.selectItem(withTitle: binary ?? "")
        }
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
    @IBAction func didSelectBinary(_ sender: AnyObject?) {
        self.selectedBinaryName = self.binaryButton.titleOfSelectedItem
        self.updateHighlighting(self.document?.crashInfo, binary: self.selectedBinaryName)
    }
}

// Mark: Highlight
extension NSTextStorage {
    func processHighlighting(_ ranges:[NSRange]) {
        var defaultAttrs: [NSAttributedString.Key: AnyObject] = [
            .foregroundColor: NSColor.textColor,
        ]
        if let font = self.font {
            defaultAttrs[.font] = font
        }
        self.setAttributes(defaultAttrs, range: self.string.nsRange)
        
        let attrs: [NSAttributedString.Key: AnyObject] = [
            .foregroundColor: NSColor(red:1.00, green:0.23, blue:0.18, alpha:1.0),
            .font: NSFontManager.shared.font(withFamily: "Menlo", traits: .boldFontMask, weight: 0, size: 11)!
        ]
        for range in ranges {
            self.setAttributes(attrs, range: range)
        }
    }
}
