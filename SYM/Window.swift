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
    override init(contentRect: NSRect, styleMask style: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.styleMask.insert(.fullSizeContentView)
        //self.backgroundColor = NSColor.white
        //self.center()
    }
}

class MainWindow: BaseWindow {
    var indicator: NSProgressIndicator?
    
    required override init(contentRect: NSRect, styleMask style: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        self.styleMask.remove(.fullSizeContentView)
    }

    func updateProgress(start: Bool) {
        var frame = CGRect.zero
        let iconButton = self.standardWindowButton(.zoomButton)
        if iconButton != nil {
            frame = iconButton!.frame
            frame.origin.x += 64
        }
        if indicator == nil {
            indicator = NSProgressIndicator(frame: frame)
            indicator!.style = .spinningStyle
            iconButton?.superview?.addSubview(indicator!)
        } else {
            indicator?.frame = frame
        }
        
        if start {
            indicator?.startAnimation(nil)
        } else {
            indicator?.stopAnimation(nil)
        }
        indicator?.isHidden = !start
    }
}


class Window: NSWindow, NSDraggingDestination {    
    required override init(contentRect: NSRect, styleMask aStyle: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: aStyle, backing: bufferingType, defer: flag)
        self.titleVisibility = .hidden
        self.backgroundColor = NSColor.white

        self.registerForDraggedTypes([NSStringPboardType, NSFilenamesPboardType])
        self.center()
    }

    // MARK: Dragging
    
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Swift.print("dragging entered")
        let pasteboard = sender.draggingPasteboard()
        
        guard let types = pasteboard.types else {
            return NSDragOperation()
        }
        
        if types.contains(NSFilenamesPboardType) {
            return sender.draggingSourceOperationMask()
        }
        return .generic
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
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
