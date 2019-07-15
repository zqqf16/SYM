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

class StatusBarCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let newRect = NSRect(x: rect.origin.x + 16, y: rect.origin.y, width: rect.width-16, height: rect.height)
        return super.drawingRect(forBounds: newRect)
    }
}


class StatusBar: NSTextField {
    var indicator: NSProgressIndicator!
    var image: NSImageView!
    var button: NSButton!
    
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
            self.button.title = buttonTitle!
            self.button.isHidden = false
        } else {
            self.button.isHidden = true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self._initSubviews()
    }
    
    private func _initSubviews() {
        // indicator
        self.indicator = NSProgressIndicator()
        self.indicator.style = .spinning
        self.indicator.translatesAutoresizingMaskIntoConstraints = false
        self.indicator.isHidden = true
        self.addSubview(self.indicator)
        
        // button
        self.button = NSButton()
        self.button.bezelStyle = .recessed
        self.button.title = "Fix"
        self.button.isHidden = false
        self.button.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.button)
        
        // image
        self.image = NSImageView(image: #imageLiteral(resourceName: "symbol"))
        self.image.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.image)
        
        self.addConstraints([
            NSLayoutConstraint(item: self.image!, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 4),
            NSLayoutConstraint(item: self.image!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: self.image!, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: -4),
            NSLayoutConstraint(item: self.image!, attribute: .width, relatedBy: .equal, toItem: self.image, attribute: .height, multiplier: 1.0, constant: 0),
            
            NSLayoutConstraint(item: self.indicator!, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: -8),
            NSLayoutConstraint(item: self.indicator!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: self.indicator!, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: -8),
            NSLayoutConstraint(item: self.indicator!, attribute: .width, relatedBy: .equal, toItem: self.indicator, attribute: .height, multiplier: 1.0, constant: 0),
            
            NSLayoutConstraint(item: self.button!, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: -4),
            NSLayoutConstraint(item: self.button!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: self.button!, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant: -8),
            NSLayoutConstraint(item: self.button!, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .width, multiplier: 1.0, constant: 32),
        ])
    }
    
    override func mouseDown(with event: NSEvent) {
        
    }
}
