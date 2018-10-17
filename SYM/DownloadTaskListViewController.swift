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

class DownloadTaskListCell: NSTableCellView {
    @IBOutlet weak var nameField: NSTextField!
    @IBOutlet weak var indicator: NSProgressIndicator!
    
    var task: DsymDownloadTask? {
        didSet {
            if let task = self.task {
                let name = task.crashInfo.appVersion ?? task.crashInfo.appName ?? "Utitled task"
                if task.isRunning {
                    let progress = task.progress.percentage
                    if (progress > 0) {
                        self.nameField.stringValue = "🏃‍♂️ \(name) \(progress)%"
                    } else {
                        self.nameField.stringValue = "🏃‍♂️ \(name)"
                    }
                    self.indicator.startAnimation(nil)
                    self.indicator.isHidden = false
                } else {
                    self.indicator.stopAnimation(nil)
                    self.indicator.isHidden = true
                    
                    let code = task.statusCode
                    if code == 0 {
                        self.nameField.stringValue = "✅ \(name)"
                    } else {
                        self.nameField.stringValue = "☠️ \(name) [error code: \(code)]"
                    }
                }
            }
        }
    }
}

class DownloadTaskListViewController: NSViewController {

    @IBOutlet weak var tableView: NSTableView!
    var tasks:[DsymDownloadTask] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.white.cgColor
        // Do view setup here.
        self.tasks = Array(DsymDownloader.shared.tasks.values)
    }
}

extension DownloadTaskListViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.tasks.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "cell"), owner: nil) as? DownloadTaskListCell
        cell?.task = self.tasks[row]
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}
