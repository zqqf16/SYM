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

import Foundation
import Cocoa

// MARK: - NSRange
extension NSRange {
    init(range:Range <Int>) {
        self.init()
        self.location = range.startIndex
        self.length = range.endIndex - range.startIndex
    }
}

// MARK: - String
extension String {
    var hexaToDecimal: Int {
        var hex = self
        if hex.hasPrefix("0x") {
            let startIndex = self.index(self.startIndex, offsetBy: 2)
            hex = String(self[startIndex...])
        }
        
        return Int(hex, radix:16) ?? 0
    }
    
    subscript (r: Range<Int>) -> String? {
        get {
            let nsRange = NSRange(r)
            return self.substring(with: nsRange)
        }
    }

    func strip() -> String {
        return self.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )
    }

    func matchGroups(fromResult result: NSTextCheckingResult) -> [String] {
        let number = result.numberOfRanges
        if number == 1 {
            if let range = Range(result.range(at:0)) {
                if let subString = self[range] {
                    return [subString]
                }
            }
            return []
        }
        
        var groups = [String]()
        
        for index in 1..<number {
            if let range = Range(result.range(at: index)) {
                groups.append(self[range] ?? "")
            }
        }
        
        return groups
    }

    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let newLength = self.count
        if newLength < toLength {
            return String(repeatElement(character, count: toLength - newLength)) + self
        } else {
            return self[0..<newLength-toLength]!
            //return self.substring(from: index(self.startIndex, offsetBy: newLength - toLength))
        }
    }
    
    func padding(length: Int, atLeft: Bool = false) -> String {
        if atLeft {
            return String(repeatElement(" ", count: length - self.count)) + self
        }
        return self.padding(toLength: length, withPad: " ", startingAt: 0)
    }
    
    func extendToLength(_ length: Int, withString padString: String=" ", atRight: Bool=true) -> String {
        return self.padding(toLength: length, withPad: padString, startingAt: 0)
    }

    func uuidFormat() -> String {
        if self.contains("-") {
            return self.uppercased()
        }

        var uuid = ""
        for (index, char) in self.enumerated() {
            if [8, 12, 16, 20].contains(index) {
                uuid.append("-" as Character)
            }
            uuid.append(char)
        }
        
        return uuid.uppercased()
    }
    
    func parseKeyValue(separatedBy: String) -> (String, String)? {
        let list = self.components(separatedBy: separatedBy)
        if list.count != 2 {
            return nil
        }
        
        let name = list[0].strip()
        let value = list[1].strip()
        if value.count == 0 {
            return nil
        }
        
        return (name, value)
    }
    
    func separatedValue() -> String? {
        let list = self.components(separatedBy: ":")
        if list.count != 2 {
            return nil
        }
        
        let value = list[1].strip()
        if value.count == 0 {
            return nil
        }
        
        return value
    }
    
    func separate(by: String = ":") -> (String, String)? {
        let list = self.components(separatedBy: ":")
        if list.count != 2 {
            return nil
        }
        
        return (list[0].strip(), list[1].strip())
    }
    
    func rangeFromNSRange(nsRange : NSRange) -> Range<String.Index>? {
        return Range(nsRange, in: self)
    }
    
    var nsRange: NSRange {
        return NSRange(self.startIndex..<self.endIndex, in: self)
    }
    
    func substring(with nsrange: NSRange) -> String? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return String(self[range])
    }
}

// MARK: - Dictionary
extension Dictionary {
    init(keys: [Key], values: [Value]) {
        self.init()
        
        for (key, value) in zip(keys, values) {
            self[key] = value
        }
    }
}

// MARK: - NSFileManager
enum FileError: Error {
    case directoryNotExist
    case createFailed
}

extension FileManager {
    func findOrCreateDirectory(searchPathDirectory directory: FileManager.SearchPathDirectory, inDomain domain: FileManager.SearchPathDomainMask, appendPathComponent component: String?) throws -> String {
        let paths = NSSearchPathForDirectoriesInDomains(directory, domain, true)
        
        if paths.count == 0 {
            throw FileError.directoryNotExist
        }
    
        var path = paths[0]
        if component != nil {
            path = (path as NSString).appendingPathComponent(component!)
        }
        
        do {
            try self.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw FileError.createFailed
        }
        
        return path
    }
    
    func appSupportDirectory() -> String? {
        let app = Bundle.main.infoDictionary!["CFBundleExecutable"] as! String
        
        let path: String
        do {
            path = try self.findOrCreateDirectory(searchPathDirectory: .applicationSupportDirectory, inDomain: .userDomainMask, appendPathComponent: app)
        } catch {
            return nil
        }
        
        return path
    }
    
    func temporaryPath() -> String {
        let uuid = ProcessInfo.processInfo.globallyUniqueString
        return (NSTemporaryDirectory() as NSString).appendingPathComponent(uuid)
    }
    
    @discardableResult
    func createDirectory(_ path: String) -> Bool {
        var isDir : ObjCBool = false
        if self.fileExists(atPath: path, isDirectory: &isDir) {
            return true
        }
        
        do {
            try self.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return false
        }
        
        return true
    }
    
    func localCrashDirectory(_ udid: String) -> String {
        guard let directory = self.appSupportDirectory() else {
            return self.temporaryPath()
        }
        
        var path = (directory as NSString).appendingPathComponent("crashes")
        if !self.createDirectory(path) {
            return self.temporaryPath()
        }
        
        path = (path as NSString).appendingPathComponent(udid)
        if !self.createDirectory(path) {
            return self.temporaryPath()
        }
        
        return path
    }
    
    @discardableResult
    func chmod(_ path: String, permissions: Int) -> Bool {
        do {
            try self.setAttributes([.posixPermissions : permissions], ofItemAtPath: path)
        } catch {
            Swift.print("Set permissions \(permissions) to \(path) failed")
            return false
        }
        
        return true
    }
    
    @discardableResult
    func cp(fromPath: String, toPath: String) -> Bool {
        do {
            try self.copyItem(atPath: fromPath, toPath: toPath)
        } catch {
            Swift.print("Copy \(fromPath) to \(toPath) failed")
            return false
        }
        
        return true
    }
}

extension NSPasteboard.PasteboardType {
    static let backwardsCompatibleFileURL: NSPasteboard.PasteboardType = {
        if #available(OSX 10.13, *) {
            return NSPasteboard.PasteboardType.fileURL
        } else {
            return NSPasteboard.PasteboardType(kUTTypeFileURL as String)
        }
    } ()
}

extension DateFormatter {
    static let symDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

extension Date {
    var formattedString: String {
        return DateFormatter.symDate.string(from: self)
    }
}

extension UInt {
    var readableSize: String {
        if self < 1024 {
            return "\(self)"
        }
        var value = Double(self) / 1024.0
        let units = ["K", "M", "G", "T"]
        var index = 0
        while value > 1024 && index < units.count - 1 {
            index += 1
            value /= 1024
        }
        
        return "\(String(format: "%.2f", value))\(units[index])"
    }
}

extension NSToolbar {
    public func removeItem(with identifier: NSToolbarItem.Identifier) {
        let index = self.items.firstIndex { (item) -> Bool in
            return item.itemIdentifier == identifier
        }
        if index != nil {
            self.removeItem(at: index!)
        }
    }
}
