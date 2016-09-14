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

class BaseWindow: NSWindow {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    required override init(contentRect: NSRect, styleMask aStyle: Int, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: aStyle, backing: bufferingType, defer: flag)
        //self.titleVisibility = .Hidden
        self.titlebarAppearsTransparent = true
        self.movableByWindowBackground = true
        self.styleMask |= NSFullSizeContentViewWindowMask
        self.backgroundColor = NSColor.whiteColor()
        //self.center()
    }
}


class MainWindow: BaseWindow {
    var indicator: NSProgressIndicator?
    
    required init(contentRect: NSRect, styleMask aStyle: Int, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: aStyle, backing: bufferingType, defer: flag)
        self.styleMask ^= NSFullSizeContentViewWindowMask
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateProgress(start: Bool) {
        var frame = CGRectZero
        let iconButton = self.standardWindowButton(.ZoomButton)
        if iconButton != nil {
            frame = iconButton!.frame
            frame.origin.x += 24
        }
        if indicator == nil {
            indicator = NSProgressIndicator(frame: frame)
            indicator!.style = .SpinningStyle
            iconButton?.superview?.addSubview(indicator!)
        } else {
            indicator?.frame = frame
        }
        
        if start {
            indicator?.startAnimation(nil)
        } else {
            indicator?.stopAnimation(nil)
        }
        indicator?.hidden = !start
    }
}


class Window: NSWindow, NSDraggingDestination {
    @IBOutlet weak var navigationButton: NSSegmentedControl!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required override init(contentRect: NSRect, styleMask aStyle: Int, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: aStyle, backing: bufferingType, defer: flag)
        self.titleVisibility = .Hidden
        self.backgroundColor = NSColor.whiteColor()

        self.registerForDraggedTypes([NSStringPboardType, NSFilenamesPboardType])
    }

    // MARK: Dragging
    
    func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        Swift.print("dragging entered")
        let pasteboard = sender.draggingPasteboard()
        
        guard let types = pasteboard.types else {
            return .None
        }
        
        if types.contains(NSFilenamesPboardType) {
            return sender.draggingSourceOperationMask()
        }
        return .Generic
    }
    
    func performDragOperation(sender: NSDraggingInfo) -> Bool {
//        let pasteboard = sender.draggingPasteboard()
//        
//        guard let types = pasteboard.types else {
//            return false
//        }
//        
//        if !types.contains(NSFilenamesPboardType) {
//            return false
//        }
//
//        if let files = pasteboard.propertyListForType(NSFilenamesPboardType) {
//            // TODO: handle files
//            return true
//        }
//        
        return false
    }
}
