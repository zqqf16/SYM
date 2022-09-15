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
        return view.window?.windowController as? MainWindowController
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
                .sink { [weak self] crashInfo in
                    self?.update(crashInfo: crashInfo)
                }
            self.update(crashInfo: document.crashInfo)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        toggleBottomBar(false)
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configFontChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configColorChanged, object: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTextView()
    }

    private func toggleBottomBar(_ show: Bool) {
        bottomBar.isHidden = !show
        splitView.adjustSubviews()
    }

    private func setupTextView() {
        textView.font = font
        textView.textContainerInset = CGSize(width: 0, height: 4)
        textView.allowsUndo = true
        textView.delegate = self
        textView.lnv_setUpLineNumberView()
        textView.layoutManager?.allowsNonContiguousLayout = false
    }

    private func infoString(fromCrash crash: Crash) -> String {
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

    func update(crashInfo: Crash?) {
        updateHighlighting(crashInfo)
        updateSummary(crashInfo)
    }

    private func updateHighlighting(_ crashInfo: Crash?) {
        guard let textStorage = textView.textStorage,
              let ranges = crashInfo?.appBacktraceRanges
        else {
            return
        }
        textStorage.beginEditing()
        textStorage.font = font
        textStorage.highlight(at: ranges)
        textStorage.endEditing()
    }

    private func updateSummary(_ crashInfo: Crash?) {
        guard let info = crashInfo else {
            toggleBottomBar(false)
            return
        }
        infoLabel.stringValue = infoString(fromCrash: info)
        toggleBottomBar(true)
    }

    @objc func configFontDidChanged(_: Notification) {
        font = Config.editorFont
        update(crashInfo: document?.crashInfo)
    }
}

extension ContentViewController: NSTextViewDelegate {
    func textView(_: NSTextView, menu _: NSMenu, for _: NSEvent, at _: Int) -> NSMenu? {
        let menu = NSMenu(title: "dSYM")
        let showItem = NSMenuItem(title: "Symbolicate", action: #selector(symbolicate), keyEquivalent: "")
        showItem.isEnabled = true
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        return menu
    }

    @objc func symbolicate(_ sender: AnyObject?) {
        windowController()?.symbolicate(sender)
    }
}

extension ContentViewController: NSSplitViewDelegate {
    func splitView(_: NSSplitView, effectiveRect _: NSRect, forDrawnRect _: NSRect, ofDividerAt _: Int) -> NSRect {
        return NSZeroRect
    }
}

extension ContentViewController {
    @IBAction func scrollToTarget(_: AnyObject?) {
        guard let crashInfo = document?.crashInfo, let range = crashInfo.crashedThreadRange else {
            return
        }

        textView.scrollRangeToVisible(range)
        textView.highlight(range)
    }

    @IBAction func zoomIn(_: AnyObject?) {
        let size = min(font.pointSize + 1, 20.0)
        font = NSFont(name: font.fontName, size: size)!
        update(crashInfo: document?.crashInfo)
    }

    @IBAction func zoomOut(_: AnyObject?) {
        let size = max(font.pointSize - 1, 10.0)
        font = NSFont(name: font.fontName, size: size)!
        update(crashInfo: document?.crashInfo)
    }
}
