// The MIT License (MIT)
//
// Copyright (c) 2017 - 2019 zqqf16
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
    static let download: NSImage = #imageLiteral(resourceName: "Cloud")
}

class DsymToolBarButton: NSPopUpButton {
    var dsymManager: DsymManager! {
        didSet {
            self.dsymManager?.eventBus.sub(self, for: DsymUpdateEvent.self).async { (event) in
                self.dsymDidUpdated()
            }
        }
    }
    
    func dsymDidUpdated() {
        if let crash = self.dsymManager?.crash,
            let uuid = crash.uuid,
            let dsym = self.dsymManager.dsymFile(withUuid: uuid) {
            self.title = dsym.name
            self.image = .symbol
        } else {
            self.title = NSLocalizedString("dsym_file_not_found", comment: "")
            self.image = .alert
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.dsymDidUpdated()
    }
}

class DsymStatusBarItemCell: NSTextFieldCell {
    var leftPadding: CGFloat = 0

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let newRect = NSRect(x: rect.origin.x + self.leftPadding,
                             y: rect.origin.y,
                             width: rect.width - self.leftPadding,
                             height: rect.height)
        return super.drawingRect(forBounds: newRect)
    }
}

class DsymStatusBarItem: NSTextField {
    var indicator: NSProgressIndicator!
    var imageView: NSImageView!
    var rightButton: NSButton!
    var showImage: Bool = false
    
    func update(title: String, isLoading: Bool, buttonTitle: String? = nil) {
        self.stringValue = title
        if isLoading {
            self.indicator.startAnimation(nil)
            self.indicator.isHidden = false
        } else {
            self.indicator.isHidden = true
            self.indicator.stopAnimation(nil)
        }
        if buttonTitle != nil {
            self.rightButton.title = buttonTitle!
            self.rightButton.isHidden = false
        } else {
            self.rightButton.isHidden = true
        }
    }
    
    var dsymManager: DsymManager! {
        didSet {
            self.dsymManager?.eventBus.sub(self, for: DsymUpdateEvent.self).async { (event) in
                self.dsymDidUpdated()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self._initSubviews()
        self.dsymDidUpdated()
        
        let eventBus = DsymDownloader.shared.eventBus
        eventBus.sub(self, for: DsymDownloadStatusEvent.self).async { (event) in
            self.updateDownloadStatus(event.task)
        }
        eventBus.sub(self, for: DsymDownloadProgressEvent.self).async { (event) in
            self.updateDownloadStatus(event.task)
        }
    }
    
    private func _initSubviews() {
        if self.showImage {
            if let cell = self.cell as? DsymStatusBarItemCell {
                cell.leftPadding = 16.0
            }
        }
        
        // indicator
        self.indicator = NSProgressIndicator()
        self.indicator.style = .spinning
        self.indicator.translatesAutoresizingMaskIntoConstraints = false
        self.indicator.isHidden = true
        self.addSubview(self.indicator)
        
        // button
        self.rightButton = NSButton(image: .symbol, target: self, action: #selector(didClickRightButton))
        self.rightButton.bezelStyle = .recessed
        self.rightButton.image = .download
        self.rightButton.isBordered = false
        self.rightButton.isHidden = true
        self.rightButton.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.rightButton)
        
        // image
        self.imageView = NSImageView(image: #imageLiteral(resourceName: "symbol"))
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.imageView)
        self.imageView.isHidden = !self.showImage
        
        self.addConstraints([
            NSLayoutConstraint(item: self.imageView!, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 4),
            NSLayoutConstraint(item: self.imageView!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: self.imageView!, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: -4),
            NSLayoutConstraint(item: self.imageView!, attribute: .width, relatedBy: .equal, toItem: self.imageView, attribute: .height, multiplier: 1.0, constant: 0),
            
            NSLayoutConstraint(item: self.indicator!, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: -8),
            NSLayoutConstraint(item: self.indicator!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: self.indicator!, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: -8),
            NSLayoutConstraint(item: self.indicator!, attribute: .width, relatedBy: .equal, toItem: self.indicator, attribute: .height, multiplier: 1.0, constant: 0),
            
            NSLayoutConstraint(item: self.rightButton!, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: -4),
            NSLayoutConstraint(item: self.rightButton!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: self.rightButton!, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: -8),
            NSLayoutConstraint(item: self.rightButton!, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .width, multiplier: 1.0, constant: 32),
        ])
    }
    
    override func mouseDown(with event: NSEvent) {
        if let wc = self.window?.windowController as? MainWindowController {
            wc.showDsymInfo(self)
        }
    }
    
    @objc func didClickRightButton() {
        if let crash = self.dsymManager?.crash {
            DsymDownloader.shared.download(crashInfo: crash, fileURL: nil)
        }
    }
    
    func dsymDidUpdated() {
        if self.dsymManager?.crash == nil {
            self.stringValue = "Open a crash file"
            self.rightButton.isHidden = true
            return
        }
        
        self.rightButton.isHidden = !DsymDownloader.shared.canDownload()

        if let dsyms = self.dsymManager?.dsymFiles, dsyms.count > 0 {
            var title: String = "Ready to symbolicate"
            
            let dsymList = dsyms.values.map({ (dsym) -> String in
                return dsym.path
            })
            
            let count = Set(dsymList).count
            if count > 1 {
                title += " | \(count) dSYMs"
            } else if let uuid = self.dsymManager?.crash.uuid {
                if let dsymFile = dsyms[uuid] {
                    title += " | \(dsymFile.name)"
                }
            }
            self.stringValue = title
        } else {
            self.stringValue = "Import or download dSYM files"
        }
    }
}

extension DsymStatusBarItem {
    private func updateDownloadStatus(_ task: DsymDownloadTask) {
        guard let uuid = self.dsymManager?.crash?.uuid, uuid == task.crashInfo.uuid else {
            return
        }

        let progress = task.progress.percentage
        switch task.status {
        case .running:
            if progress > 0 {
                self.stringValue = "Downloading ... \(progress)%"
            } else {
                self.stringValue = "Downloading ..."
            }
        case .canceled:
            self.stringValue = "Download canceled"
        case .failed(let code, _):
            self.stringValue = "Download failed: | \(code)"
        case .success:
            self.stringValue = "Download completed"
        case .waiting:
            self.stringValue = "Downloading ..."
        }
    }
}
