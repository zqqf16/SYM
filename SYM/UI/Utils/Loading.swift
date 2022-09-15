// The MIT License (MIT)
//
// Copyright (c) 2022 zqqf16
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

import AppKit
import Foundation
import SnapKit

protocol LoadingAble: AnyObject {
    var loadingIndicator: NSProgressIndicator! { get set }
    func showLoading()
    func hideLoading()
}

extension LoadingAble where Self: NSViewController {
    func showLoading() {
        DispatchQueue.main.async {
            defer {
                self.loadingIndicator.startAnimation(nil)
                self.loadingIndicator.isHidden = false
            }

            if self.loadingIndicator != nil {
                return
            }

            self.loadingIndicator = NSProgressIndicator()
            self.loadingIndicator.style = .spinning
            self.loadingIndicator.isDisplayedWhenStopped = false
            self.view.addSubview(self.loadingIndicator)
            self.loadingIndicator.snp.makeConstraints { make in
                make.width.height.equalTo(48)
                make.center.equalTo(self.view)
            }
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.loadingIndicator.stopAnimation(nil)
        }
    }
}
