// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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

class AboutViewController: NSViewController {

    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var name: NSTextField!
    @IBOutlet weak var version: NSTextField!
    @IBOutlet weak var copyright: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.icon.image = NSApp.applicationIconImage
        let infoDict = Bundle.main.infoDictionary!
        
        let shortVersion = infoDict["CFBundleShortVersionString"] as! String
        let buildVersion = infoDict["CFBundleVersion"] as! String
        self.version.stringValue = "\(shortVersion) (\(buildVersion))"

        self.copyright.stringValue = infoDict["NSHumanReadableCopyright"] as! String
    }
    
    @IBAction func gotoWebsite(_ sender: AnyObject) {
        let url = URL(string: "http://blog.zorro.im?utm_source=share&utm_medium=sym")!
        NSWorkspace.shared().open(url)
    }
    
    @IBAction func gotoGithub(_ sender: AnyObject) {
        let url = URL(string: "https://github.com/zqqf16/SYM")!
        NSWorkspace.shared().open(url)
    }
}
