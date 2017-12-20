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

import Cocoa

extension NSViewController {
    func windowController() -> MainWindowController? {
        return self.view.window?.windowController as? MainWindowController
    }
}

class ContentViewController: NSViewController {
    @IBOutlet var textView: NSTextView!
    
    var crash: Crash?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupTextView()
    }
    
    func open(crash: Crash) {
        self.crash = crash
        let formatted = crash.pretty()
        self.textView.setAttributeString(attributeString: formatted)
        self.textView.scrollToBeginningOfDocument(nil)
    }
    
    var currentCrashContent: String {
        return self.textView.string
    }
    
    private func setupTextView() {
        self.textView.font = NSFont(name: "Menlo", size: 11)
        self.textView.textContainerInset = CGSize(width: 10, height: 10)
        self.textView.allowsUndo = true
        self.textView.delegate = self
    }
}

extension ContentViewController: CrashTextViewDelegate {
    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        let menu = NSMenu(title: "dSYM")
        let showItem = NSMenuItem(title: "Symbolicate", action: #selector(symbolicate), keyEquivalent: "")
        showItem.isEnabled = true
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        return menu
    }
    
    func didPasteCrashContent() {
        /*
        let newContent = textView.string
        if newContent.count > 0 {
            DispatchQueue.main.async {
                //self.document()?.updateCrash(withContent: newContent)
            }
        }
        */
    }
    
    @objc func symbolicate(_ sender: AnyObject?) {
        self.windowController()?.symbolicate(sender)
    }
}
