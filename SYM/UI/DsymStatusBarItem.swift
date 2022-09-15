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

class DsymToolBarButton: NSPopUpButton {
    private var cancellable: AnyCancellable?

    var dsymManager: DsymManager? {
        didSet {
            cancellable?.cancel()
            cancellable = dsymManager?.$dsymFiles
                .receive(on: DispatchQueue.main)
                .sink { [weak self] dsymFiles in
                    self?.update(withDsymFiles: dsymFiles)
                }
        }
    }

    private func update(withDsymFiles dsymFiles: [String: DsymFile]) {
        if let crash = dsymManager?.crash,
           let uuid = crash.uuid,
           let dsym = dsymFiles[uuid]
        {
            title = dsym.name
            image = .symbol
        } else {
            title = NSLocalizedString("dsym_file_not_found", comment: "")
            image = .alert
        }
    }
}
