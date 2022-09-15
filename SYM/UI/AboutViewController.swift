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

class AboutWindow: BaseWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        titlebarAppearsTransparent = true
        titleVisibility = .visible
        // self.backgroundColor = NSColor.white
        // self.center()
    }
}

class AboutViewController: NSViewController {
    @IBOutlet var icon: NSImageView!
    @IBOutlet var name: NSTextField!
    @IBOutlet var version: NSTextField!
    @IBOutlet var copyright: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        icon.image = NSApp.applicationIconImage
        let infoDict = Bundle.main.infoDictionary!

        let shortVersion = infoDict["CFBundleShortVersionString"] as! String
        let buildVersion = infoDict["CFBundleVersion"] as! String
        version.stringValue = "\(shortVersion) (\(buildVersion))"

        copyright.stringValue = infoDict["NSHumanReadableCopyright"] as! String
    }

    @IBAction func gotoWebsite(sender _: AnyObject) {
        let url = URL(string: "https://zorro.im?utm_source=sym&utm_medium=referral")!
        NSWorkspace.shared.open(url)
    }

    @IBAction func gotoGithub(_: AnyObject) {
        let url = URL(string: "https://github.com/zqqf16/SYM")!
        NSWorkspace.shared.open(url)
    }
}
