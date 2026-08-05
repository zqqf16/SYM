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

extension String {
    static let downloadFolderKey = "dsymDownloadFolder"
    static let editorFontNameKey = "editorFontName"
    static let editorFontSizeKey = "editorFontSize"
    static let editorHighlightColorKey = "editorHighlightColorKey"
    static let showLineNumbersKey = "showLineNumbers"
    static let showCrashSummaryKey = "showCrashSummary"
}

extension Notification.Name {
    static let configFontChanged = Notification.Name("sym.config.fontChanged")
    static let configColorChanged = Notification.Name("sym.config.colorChanged")
    static let configLineNumbersChanged = Notification.Name("sym.config.lineNumbersChanged")
    static let configCrashSummaryChanged = Notification.Name("sym.config.crashSummaryChanged")
    static let configDownloadFolderChanged = Notification.Name("sym.config.downloadFolderChanged")
}

enum Config {
    static var downloadScriptURL: URL {
        let dir = FileManager.default.appSupportDirectory() ?? NSTemporaryDirectory()
        var url = URL(fileURLWithPath: dir)
        url.appendPathComponent("download.sh")
        return url
    }

    /// Blank, whitespace-only, comment/shebang-only, or `exit N` stub-only scripts
    /// count as missing (matches the shipped editor template).
    static func isDownloadScriptEmpty(_ script: String) -> Bool {
        for line in script.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            // Unfinished template stubs like a lone `exit 1`.
            if trimmed == "exit" || trimmed.hasPrefix("exit ") {
                continue
            }
            return false
        }
        return true
    }

    /// Delete `download.sh` when empty so callers treat it as “no script configured”.
    @discardableResult
    static func sanitizeDownloadScriptFile() -> Bool {
        let url = downloadScriptURL
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }
        guard let script = try? String(contentsOf: url, encoding: .utf8),
              !isDownloadScriptEmpty(script)
        else {
            try? fileManager.removeItem(at: url)
            return false
        }
        return true
    }

    /// Whether a real user/builtin download script is on disk (sanitizes stubs first).
    static func isDownloadScriptConfigured() -> Bool {
        sanitizeDownloadScriptFile()
    }

    static func removeDownloadScript() {
        try? FileManager.default.removeItem(at: downloadScriptURL)
    }

    static func prepareDsymDownloadDirectory() {
        let path = dsymDownloadDirectory
        UserDefaults.standard.set(path, forKey: .downloadFolderKey)
    }

    static var dsymDownloadDirectory: String {
        get {
            let home = NSHomeDirectory()
            var path: String!
            if let stored = UserDefaults.standard.string(forKey: .downloadFolderKey) {
                if stored.hasPrefix("~/") {
                    path = "\(home)/\(stored.dropFirst(2))"
                } else {
                    path = stored
                }
            }

            if path == nil {
                let urls = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
                path = urls.first?.path ?? home
            }

            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createDirectory(path)
            }

            return path
        }
        set {
            UserDefaults.standard.set(newValue, forKey: .downloadFolderKey)
            if !FileManager.default.fileExists(atPath: newValue) {
                FileManager.default.createDirectory(newValue)
            }
            NotificationCenter.default.post(name: .configDownloadFolderChanged, object: newValue)
        }
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

    static let highlightColors: [String] = [
        "#F44336",
        "#E91E63",
        "#9C27B0",
        "#673AB7",
        "#3F51B5",
        "#2196F3",
        "#03A9F4",
        "#00BCD4",
        "#009688",
        "#4CAF50",
        "#8BC34A",
        "#CDDC39",
        "#FFEB3B",
        "#FFC107",
        "#FF9800",
        "#FF5722",
        "#795548",
        "#9E9E9E",
        "#607D8B",
    ]

    static var highlightColor: String {
        get {
            return UserDefaults.standard.string(forKey: .editorHighlightColorKey) ?? highlightColors[0]
        }
        set(newColor) {
            UserDefaults.standard.set(newColor, forKey: .editorHighlightColorKey)
            NotificationCenter.default.post(name: .configColorChanged, object: newColor)
        }
    }

    static var showLineNumbers: Bool {
        get {
            if UserDefaults.standard.object(forKey: .showLineNumbersKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: .showLineNumbersKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: .showLineNumbersKey)
            NotificationCenter.default.post(name: .configLineNumbersChanged, object: newValue)
        }
    }

    /// Whether the bottom crash summary bar is shown after parsing.
    static var showCrashSummary: Bool {
        get {
            if UserDefaults.standard.object(forKey: .showCrashSummaryKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: .showCrashSummaryKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: .showCrashSummaryKey)
            NotificationCenter.default.post(name: .configCrashSummaryChanged, object: newValue)
        }
    }
}
