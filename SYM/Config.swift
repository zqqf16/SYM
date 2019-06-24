// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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

extension String {
    static let downloadScriptURLKey = "symDownloadScriptURL"
    static let downloadFolderKey = "dsymDownloadFolder"
    static let editorFontNameKey = "editorFontName"
    static let editorFontSizeKey = "editorFontSize"
}

extension Notification.Name {
    static let configFontChanged = Notification.Name("sym.config.fontChanged")
}

struct Config {
    static func downloadScriptURL() -> URL {
        if let stored = UserDefaults.standard.url(forKey: .downloadScriptURLKey) {
            return stored
        }
        
        var path = FileManager.default.appSupportDirectory() ?? NSTemporaryDirectory()
        path = (path as NSString).appendingPathComponent("download.sh")
        let url = URL(fileURLWithPath: path)
        UserDefaults.standard.set(url, forKey: .downloadScriptURLKey)
        return url
    }
    
    static func dsymDownloadDirectory() -> String {
        if let stored = UserDefaults.standard.string(forKey: .downloadFolderKey) {
            if stored.hasPrefix("~/") {
                let newPath = "\(NSHomeDirectory())/\(stored.dropFirst(2))"
                UserDefaults.standard.set(newPath, forKey: .downloadFolderKey)
                return newPath
            }
            
            return stored
        }
        let urls = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        let path = urls.first?.path ?? NSHomeDirectory()
        UserDefaults.standard.set(path, forKey: .downloadFolderKey)
        return path
    }
    
    static var editorFont: NSFont {
        get {
            var fontSize: CGFloat = NSFont.systemFontSize
            
            let size = UserDefaults.standard.integer(forKey: .editorFontSizeKey)
            if size > 0 {
                fontSize = CGFloat(size)
            }
            
            var font: NSFont?
            if let name = UserDefaults.standard.string(forKey: .editorFontNameKey) {
                font = NSFont(name: name, size: fontSize)
            }
            
            return font ?? NSFont.userFixedPitchFont(ofSize: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        }
        set(newFont) {
            let name = newFont.fontName
            let size = Int(newFont.pointSize)
            UserDefaults.standard.set(name, forKey: .editorFontNameKey)
            UserDefaults.standard.set(size, forKey: .editorFontSizeKey)
            NotificationCenter.default.post(name: .configFontChanged, object: newFont)
        }
    }
}
