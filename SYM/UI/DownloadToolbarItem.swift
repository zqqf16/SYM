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

    private var cancellable: AnyCancellable?

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
        self.indicator.isHidden = true
        self.view?.superview?.addSubview(self.indicator)
    }
    
    func bind(task: DsymDownloadTask?) {
        self.cancellable?.cancel()
        if task != nil {
            self.cancellable = Publishers
                .CombineLatest(task!.$status, task!.$progress)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] (status, progress) in
                    self?.update(status: status, progress: progress)
                }
        } else {
            self.running = false
        }
    }
    
    private func update(status: DsymDownloadTask.Status, progress: DsymDownloadTask.Progress) {
        switch status {
        case .running:
            self.running = true
            self.updateFrame()
        default:
            self.running = false
        }
        
        if progress.percentage == 0 {
            self.indicator.isIndeterminate = true
        } else {
            self.indicator.isIndeterminate = false
            self.indicator.doubleValue = Double(progress.percentage)
        }
    }
    
    private func updateFrame() {
        let imageFrame = self.view!.frame
        self.indicator.frame = CGRect(x: imageFrame.origin.x,
                                      y: imageFrame.origin.y - 2,
                                      width: imageFrame.width,
                                      height: 4.0)
    }
}
