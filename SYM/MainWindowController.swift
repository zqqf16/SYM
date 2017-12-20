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

extension NSImage {
    static let alert: NSImage = #imageLiteral(resourceName: "alert")
    static let symbol: NSImage = #imageLiteral(resourceName: "symbol")
}

class MainWindowController: NSWindowController {
    // Toolbar buttons
    @IBOutlet weak var symButton: NSButton!
    @IBOutlet weak var indicator: NSProgressIndicator!
    @IBOutlet weak var dsymButton: NSButton!
    @IBOutlet weak var deviceLabel: NSTextField!
    
    private var dsym: Dsym? {
        didSet {
            DispatchQueue.main.async {
                if self.dsym == nil {
                    self.dsymButton.title = "Select a dSYM file"
                    self.dsymButton.image = .alert
                } else {
                    self.dsymButton.title = self.dsym!.name
                    self.dsymButton.image = .symbol
                }
            }
        }
    }
    
    private var device: String? {
        didSet {
            DispatchQueue.main.async {
                if let device = self.device {
                    self.deviceLabel.stringValue = modelToName(device)
                    self.deviceLabel.isHidden = false
                } else {
                    self.deviceLabel.stringValue = ""
                    self.deviceLabel.isHidden = true
                }
            }
        }
    }
    
    var crash: Crash?
    
    var crashContentViewController: ContentViewController! {
        if let vc = self.contentViewController as? ContentViewController {
            return vc
        }
        return nil
    }
    
    var currentCrashContent: String {
        return self.crashContentViewController.currentCrashContent
    }
    
    var crashDocument: CrashDocument? {
        return self.document as? CrashDocument
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.dsym = nil;
        DsymManager.shared.updateDsymList(nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dsymListDidUpdate), name: .dsymListUpdated, object: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder:coder)
    }
    
    fileprivate func sendNotification(_ name: Notification.Name) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: self)
        }
    }
}

// MARK: - Crash operation
extension MainWindowController {
    func didOpenCrash() {
        guard let crashContent = self.crashDocument?.content else {
            return
        }
        
        self.crash = Crash.parse(fromContent: crashContent)
        self.crashContentViewController.open(crash: self.crash!)
        
        self.device = self.crash!.device
        self.findCurrentDsym()
    }
    
    func didUpdateCrash(withContent content: String) {
        self.crashDocument!.content = content
        self.didOpenCrash()
    }
}

// MARK: - Symbolicate
extension MainWindowController {
    func autoSymbolicate() {
        if NSUserDefaultsController.shared.defaults.bool(forKey: "autoSymbolicate") {
            self.symbolicate(nil)
        }
    }
    
    @IBAction func symbolicate(_ sender: AnyObject?) {
        let content = self.crashContentViewController.currentCrashContent
        if content.strip().isEmpty {
            return
        }
        
        let crash = Crash.parse(fromContent: content)
        
        self.indicator.startAnimation(nil)
        DispatchQueue.global().async {
            let newContent = SYM.symbolicate(crash: crash, dsym: self.dsym?.path)
            DispatchQueue.main.async { [weak self] in
                self?.indicator.stopAnimation(nil)
                self?.didUpdateCrash(withContent: newContent)
            }
        }
    }
}

// MARK: - dSYM
extension MainWindowController: DsymListViewControllerDelegate {
    @objc func dsymListDidUpdate(notification: Notification) {
        if self.dsym == nil {
            self.findCurrentDsym()
        }
    }
    
    func findCurrentDsym() {
        if let uuid = self.crash?.uuid {
            self.dsym = DsymManager.shared.dsym(withUUID: uuid)
        }
    }

    func didSelectDsym(_ dsym: Dsym) {
        self.dsym = dsym
    }
    
    @IBAction func showDsymList(_ sender: AnyObject?) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let viewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "DsymListViewController")) as! DsymListViewController
        viewController.delegate = self
        
        if let uuid = self.crash?.uuid {
            viewController.uuid = uuid
        }
        
        self.window?.contentViewController?.presentViewControllerAsSheet(viewController)
    }
}
