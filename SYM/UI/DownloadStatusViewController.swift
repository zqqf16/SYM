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

protocol DownloadStatusViewControllerDelegate: AnyObject {
    func cancelDownload() -> Void
    func startDownloading() -> Void
    func currentDownloadTask() -> DsymDownloadTask?
}

class DownloadStatusViewController: NSViewController {
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var infoLabel: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var downloadButton: NSButton!
    
    weak var delegate: DownloadStatusViewControllerDelegate?

    private var taskCancellable: AnyCancellable?
    private var status: DsymDownloadTask.Status?

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.taskCancellable?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.bind(task: self.delegate?.currentDownloadTask())
    }
    
    func bind(task: DsymDownloadTask?) {
        if !self.isViewLoaded {
            return
        }

        self.taskCancellable?.cancel()

        guard let downloadTask = task else {
            self.titleLabel.stringValue = ""
            self.infoLabel.stringValue = ""
            self.progressIndicator.isHidden = true
            self.cancelButton.isHidden = true
            self.downloadButton.isHidden = false
            return
        }

        self.downloadButton.isHidden = true
        self.taskCancellable = Publishers
            .CombineLatest(downloadTask.$status, downloadTask.$progress)
            .receive(on: DispatchQueue.main)
            .sink { (status, progress) in
                self.update(status: status, progress: progress)
            }
    }
    
    func update(status: DsymDownloadTask.Status, progress: DsymDownloadTask.Progress) {
        self.status = status
        switch status {
        case .running:
            self.cancelButton.isHidden = false
            self.progressIndicator.isHidden = false
            self.cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            
            var title = NSLocalizedString("download_prefix", comment: "Downloading ...")
            if progress.percentage > 0 {
                title += " \(progress.percentage)%"
                self.progressIndicator.isIndeterminate = false
                self.progressIndicator.doubleValue = Double(progress.percentage)
            } else {
                self.progressIndicator.isIndeterminate = true
            }
            self.infoLabel.stringValue = "\(progress.downloadedSize)/\(progress.totalSize) \(progress.timeLeft) \(progress.speed)/s"
            self.titleLabel.stringValue = title
        case .canceled:
            self.titleLabel.stringValue = NSLocalizedString("Canceled", comment: "Canceled")
            self.infoLabel.stringValue = ""
            self.cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
        case .failed(let code, let message):
            let prefix = NSLocalizedString("Failed", comment: "Failed")
            self.titleLabel.stringValue = "\(prefix) (\(code))"
            self.infoLabel.stringValue = message ?? ""
            self.cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
        case .success:
            self.titleLabel.stringValue = NSLocalizedString("Success", comment: "Success")
            self.infoLabel.stringValue = ""
            self.cancelButton.isHidden = true
        case .waiting:
            self.titleLabel.stringValue = NSLocalizedString("Waiting", comment: "Waiting ...")
            self.titleLabel.stringValue = "Waiting ..."
            self.infoLabel.stringValue = ""
            self.progressIndicator.isIndeterminate = true
            self.progressIndicator.isHidden = false
            self.cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            self.cancelButton.isHidden = false
        }
    }
    
    @IBAction func startDownloading(_ sender: Any?) {
        self.delegate?.startDownloading()
    }
    
    @IBAction func cancelDownload(_ sender: Any?) {
        guard let status = self.status else {
            return
        }
        
        switch status {
        case .canceled, .failed(_, _):
            self.delegate?.startDownloading()
        case .running, .waiting:
            self.delegate?.cancelDownload()
        case .success:
            break
        }
    }
}
