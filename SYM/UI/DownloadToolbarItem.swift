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

class DownloadToolbarItem: NSToolbarItem {
    @IBOutlet var indicator: NSProgressIndicator!

    private var storage = Set<AnyCancellable>()

    var running: Bool = false {
        didSet {
            self.indicator.isHidden = !running
            //self.view?.isHidden = running
            if running {
                self.indicator.startAnimation(nil)
            } else {
                self.indicator.stopAnimation(nil)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.indicator = NSProgressIndicator()
        self.indicator.isIndeterminate = true
                
        let imageFrame = self.view!.frame
        self.indicator.frame = CGRect(x: imageFrame.origin.x,
                                      y: imageFrame.origin.y - 2,
                                      width: imageFrame.width,
                                      height: 4.0)
        
        self.indicator.isHidden = true
        self.view?.superview?.addSubview(self.indicator)
    }
    
    func bind(task: DsymDownloadTask) {
        self.storage.forEach { (cancellable) in
            cancellable.cancel()
        }
        
        task.$status.sink { [weak self] (status) in
            DispatchQueue.main.async {
                self?.update(status: status)
            }
        }.store(in: &storage)
        
        task.$progress.sink { [weak self] (progress) in
            DispatchQueue.main.async {
                self?.update(progress: progress)
            }
        }.store(in: &storage)
    }
    
    private func update(status: DsymDownloadTask.Status) {
        switch status {
        case .running:
            self.running = true
        default:
            self.running = false
        }
    }
    
    private func update(progress: DsymDownloadTask.Progress) {
        if progress.percentage == 0 {
            self.indicator.isIndeterminate = true
        } else {
            self.indicator.isIndeterminate = false
            self.indicator.doubleValue = Double(progress.percentage)
        }
    }
}
