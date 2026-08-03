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
    private let button = NSButton()
    private let indicator = NSProgressIndicator()
    private var cancellable: AnyCancellable?

    var running: Bool = false {
        didSet {
            indicator.isHidden = !running
            if running {
                indicator.startAnimation(nil)
            } else {
                indicator.stopAnimation(nil)
            }
        }
    }

    override var target: AnyObject? {
        get { button.target }
        set { button.target = newValue }
    }

    override var action: Selector? {
        get { button.action }
        set { button.action = newValue }
    }

    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)
        setupView()
    }

    private func setupView() {
        label = "Download"
        paletteLabel = "Download"
        toolTip = NSLocalizedString("Download dSYM file", comment: "")
        isBordered = true

        button.image = NSImage.sfSymbol("arrow.down.circle", accessibilityDescription: "Download")
        button.imagePosition = .imageOnly
        button.bezelStyle = .toolbar
        button.isBordered = true
        button.setButtonType(.momentaryPushIn)

        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isDisplayedWhenStopped = false
        indicator.isHidden = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 36, height: 28))
        container.addSubview(button)
        container.addSubview(indicator)
        button.translatesAutoresizingMaskIntoConstraints = false
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            indicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        view = container
        minSize = NSSize(width: 36, height: 28)
        maxSize = NSSize(width: 40, height: 32)
    }

    func bind(task: DsymDownloadTask?) {
        cancellable?.cancel()
        guard let task else {
            running = false
            return
        }
        cancellable = Publishers
            .CombineLatest(task.$status, task.$progress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status, progress in
                self?.update(status: status, progress: progress)
            }
    }

    private func update(status: DsymDownloadTask.Status, progress: DsymDownloadTask.Progress) {
        switch status {
        case .running, .waiting:
            running = true
            button.isHidden = true
        default:
            running = false
            button.isHidden = false
        }

        if progress.percentage == 0 {
            indicator.isIndeterminate = true
        } else {
            indicator.isIndeterminate = false
            indicator.doubleValue = Double(progress.percentage)
            indicator.maxValue = 100
        }
    }
}
