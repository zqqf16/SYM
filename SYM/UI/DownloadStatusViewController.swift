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

class DownloadStatusViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var infoLabel: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var downloadButton: NSButton!
    
    private var storage = Set<AnyCancellable>()
    private var task: DsymDownloadTask?
    private var downloaderCancellable: AnyCancellable?

    var crashInfo: CrashInfo?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.downloaderCancellable = DsymDownloader.shared.$tasks.sink { (tasks) in
            if let uuid = self.crashInfo?.uuid, let task = tasks[uuid] {
                self.bind(task: task)
            } else {
                self.bind(task: nil)
            }
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.downloaderCancellable?.cancel()
        self.storage.forEach { (cancellable) in
            cancellable.cancel()
        }
    }
    
    func bind(task: DsymDownloadTask?) {
        self.task = task
        self.storage.forEach { (cancellable) in
            cancellable.cancel()
        }
        
        guard let downloadTask = task else {
            self.titleLabel.stringValue = ""
            self.infoLabel.stringValue = ""
            self.progressIndicator.isHidden = true
            self.cancelButton.isHidden = true
            if self.crashInfo?.uuid != nil {
                self.downloadButton.isHidden = false
            }
            return
        }
        
        self.downloadButton.isHidden = true
        
        downloadTask.$status.sink { [weak self] (status) in
            DispatchQueue.main.async {
                self?.updateInfo()
            }
        }.store(in: &storage)
        
        downloadTask.$progress.sink { [weak self] (progress) in
            DispatchQueue.main.async {
                self?.updateInfo()
            }
        }.store(in: &storage)
    }
    
    func updateInfo() {
        if let status = self.task?.status {
            switch status {
            case .running:
                self.cancelButton.isHidden = false
                self.progressIndicator.isHidden = false
                self.cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)

                var title = "Downloading ..."
                if let progress = self.task?.progress {
                    if progress.percentage > 0 {
                        title += " \(progress.percentage)%"
                        self.progressIndicator.isIndeterminate = false
                        self.progressIndicator.doubleValue = Double(progress.percentage)
                    } else {
                        self.progressIndicator.isIndeterminate = true
                    }
                    self.infoLabel.stringValue = "\(progress.downloadedSize)/\(progress.totalSize) \(progress.timeLeft) \(progress.speed)/s"
                }
                self.titleLabel.stringValue = title
            case .canceled:
                self.titleLabel.stringValue = "Canceled"
                self.infoLabel.stringValue = ""
                self.cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
            case .failed(let code, let message):
                self.titleLabel.stringValue = "Failed (\(code))"
                self.infoLabel.stringValue = message ?? ""
                self.cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
            case .success:
                self.titleLabel.stringValue = "Success"
                self.infoLabel.stringValue = ""
                self.cancelButton.isHidden = true
            case .waiting:
                self.titleLabel.stringValue = "Waiting ..."
                self.infoLabel.stringValue = ""
                self.progressIndicator.isIndeterminate = true
                self.progressIndicator.isHidden = false
                self.cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
                self.cancelButton.isHidden = false
            }
        }
    }
    
    @IBAction func startDownloading(_ sender: Any?) {
        if let crashInfo = self.crashInfo {
            DsymDownloader.shared.download(crashInfo: crashInfo, fileURL: nil)
        }
    }
    
    @IBAction func cancelDownload(_ sender: Any?) {
        guard let status = self.task?.status else {
            return
        }
        
        switch status {
        case .canceled, .failed(_, _):
            self.startDownloading(sender)
        case .running, .waiting:
            self.task?.cancel()
        case .success:
            break
        }
    }
}
