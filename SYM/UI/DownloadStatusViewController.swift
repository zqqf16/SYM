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
    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var infoLabel: NSTextField!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var downloadButton: NSButton!

    weak var delegate: DownloadStatusViewControllerDelegate?

    private var taskCancellable: AnyCancellable?
    private var status: DsymDownloadTask.Status?

    override func viewDidDisappear() {
        super.viewDidDisappear()
        taskCancellable?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind(task: delegate?.currentDownloadTask())
    }

    func bind(task: DsymDownloadTask?) {
        if !isViewLoaded {
            return
        }

        taskCancellable?.cancel()

        guard let downloadTask = task else {
            titleLabel.stringValue = ""
            infoLabel.stringValue = ""
            progressIndicator.isHidden = true
            cancelButton.isHidden = true
            downloadButton.isHidden = false
            return
        }

        downloadButton.isHidden = true
        taskCancellable = Publishers
            .CombineLatest(downloadTask.$status, downloadTask.$progress)
            .receive(on: DispatchQueue.main)
            .sink { status, progress in
                self.update(status: status, progress: progress)
            }
    }

    func update(status: DsymDownloadTask.Status, progress: DsymDownloadTask.Progress) {
        self.status = status
        switch status {
        case .running:
            cancelButton.isHidden = false
            progressIndicator.isHidden = false
            cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)

            var title = NSLocalizedString("download_prefix", comment: "Downloading ...")
            if progress.percentage > 0 {
                title += " \(progress.percentage)%"
                progressIndicator.isIndeterminate = false
                progressIndicator.doubleValue = Double(progress.percentage)
            } else {
                progressIndicator.isIndeterminate = true
            }
            infoLabel.stringValue = "\(progress.downloadedSize)/\(progress.totalSize) \(progress.timeLeft) \(progress.speed)/s"
            titleLabel.stringValue = title
        case .canceled:
            titleLabel.stringValue = NSLocalizedString("Canceled", comment: "Canceled")
            infoLabel.stringValue = ""
            cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
        case let .failed(code, message):
            let prefix = NSLocalizedString("Failed", comment: "Failed")
            titleLabel.stringValue = "\(prefix) (\(code))"
            infoLabel.stringValue = message ?? ""
            cancelButton.image = NSImage(named: NSImage.refreshFreestandingTemplateName)
        case .success:
            titleLabel.stringValue = NSLocalizedString("Success", comment: "Success")
            infoLabel.stringValue = ""
            cancelButton.isHidden = true
        case .waiting:
            titleLabel.stringValue = NSLocalizedString("Waiting", comment: "Waiting ...")
            titleLabel.stringValue = "Waiting ..."
            infoLabel.stringValue = ""
            progressIndicator.isIndeterminate = true
            progressIndicator.isHidden = false
            cancelButton.image = NSImage(named: NSImage.stopProgressFreestandingTemplateName)
            cancelButton.isHidden = false
        }
    }

    @IBAction func startDownloading(_: Any?) {
        delegate?.startDownloading()
    }

    @IBAction func cancelDownload(_: Any?) {
        guard let status = status else {
            return
        }

        switch status {
        case .canceled, .failed:
            delegate?.startDownloading()
        case .running, .waiting:
            delegate?.cancelDownload()
        case .success:
            break
        }
    }
}
