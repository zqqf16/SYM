// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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


extension NSView {
    
    var backgroundColor: NSColor? {
        
        get {
            if let colorRef = self.layer?.backgroundColor {
                return NSColor(cgColor: colorRef)
            } else {
                return nil
            }
        }
        
        set {
            self.wantsLayer = true
            self.layer?.backgroundColor = newValue?.cgColor
        }
    }
}


protocol ThreadTitleViewDelegate: NSObjectProtocol {
    func didCollapseButtonClicked(_ isCollapse: Bool)
}


class ThreadTitleView: NSView {

    enum ButtonState {
        case collapse
        case expand
    }
    
    @IBOutlet weak var collapseButton: NSButton!
    @IBOutlet weak var title: NSTextField!

    weak var delegate: ThreadTitleViewDelegate?
    
    var buttonState: ButtonState? {
        didSet {
            if let state = buttonState {
                switch state {
                case .collapse:
                    self.collapseButton.image = NSImage(named: "collapse")
                case .expand:
                    self.collapseButton.image = NSImage(named: "expand")
                }
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.setFill()
        NSRectFill(dirtyRect);
        
        let bottom = NSBezierPath()
        let start = NSMakePoint(NSMinX(self.bounds), NSMinY(self.bounds))
        let end = NSMakePoint(NSMaxX(self.bounds), NSMinY(self.bounds))

        bottom.move(to: start)
        bottom.line(to: end)
        bottom.lineWidth = 2;
        NSColor.gridColor.set()
        bottom.stroke()
        
        //let line = NSBezierPath.
    }
    
    func switchButtonState() {
        if self.buttonState == .collapse {
            self.buttonState = .expand
        } else {
            self.buttonState = .collapse
        }
    }
    
    @IBAction func collapse(_ sender: AnyObject?) {
        let isCollapse: Bool = (self.buttonState == .collapse)
        self.switchButtonState()
        if let delegate = self.delegate {
            delegate.didCollapseButtonClicked(isCollapse)
        }
    }
}
