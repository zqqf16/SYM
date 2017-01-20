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


import Foundation


class CrashFile: Equatable {
    var name: String
    var url: URL?

    var fileWrapper: FileWrapper?

    private var _crash: CrashReport?
    var crash: CrashReport? {
        get {
            if self._crash == nil {
                self._crash = self.crashGenerator()
            }
            return self._crash
        }
        set {
            self._crash = newValue
        }
    }
    
    var crashGenerator: (()->CrashReport?) {
        didSet {
            self._crash = nil
        }
    }

    var children: [CrashFile]?
    
    init(name: String = "Untitled") {
        self.name = name
        
        self.crashGenerator = {
            return nil
        }
    }
    
    convenience init(from fileWrapper: FileWrapper) {
        self.init(name: fileWrapper.filename!)
        self.fileWrapper = fileWrapper
        
        self.crashGenerator = {
            if let data = fileWrapper.regularFileContents,
                let content = String(data: data, encoding: String.Encoding.utf8){
                return CrashReport(content)
            }
            
            return nil
        }
    }
    
    static func ==(l:CrashFile, r:CrashFile) -> Bool {
        return l.name == r.name && (l.url == r.url || l.fileWrapper == r.fileWrapper)
    }
}
