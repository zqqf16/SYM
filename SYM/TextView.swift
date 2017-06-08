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


protocol CrashTextViewDelegate: NSTextViewDelegate {
    func didChangeCrashContent()
}


extension NSTextView {
    func setAttributeString(attributeString: NSAttributedString) {
        self.textStorage?.beginEditing()
        self.textStorage?.setAttributedString(attributeString)
        self.textStorage?.endEditing()
    }
}


class TextView: NSTextView {
    /*
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard()
        
        guard let types = pboard.types else {
            return super.performDragOperation(sender)
        }
        
        if types.contains(NSFilenamesPboardType) {
            if let paths = pboard.propertyList(forType: NSFilenamesPboardType) as? Array<String> {
                let fileURL = URL(fileURLWithPath: paths[0])
                NSDocumentController.shared().openDocument(withContentsOf: fileURL, display: true, completionHandler: { (doc: NSDocument?, success: Bool, error: Error?) in
                    // Do nothing
                })
                return true
            }
        }
        
        return super.performDragOperation(sender)
    }
     */
    
    override func didChangeText() {
        super.didChangeText()
        
        if let delegate = self.delegate as? CrashTextViewDelegate {
            delegate.didChangeCrashContent()
        }
    }
}
