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
import Cocoa


// MARK: - String
extension String {
    var drop0xPrefix:          String { return hasPrefix("0x") ? String(characters.dropFirst(2)) : self }
    var drop0bPrefix:          String { return hasPrefix("0b") ? String(characters.dropFirst(2)) : self }
    var hexaToDecimal:            Int { return Int(drop0xPrefix, radix: 16) ?? 0 }
    var hexaToBinaryString:    String { return String(hexaToDecimal, radix: 2) }
    var decimalToHexaString:   String { return String(Int(self) ?? 0, radix: 16) }
    var decimalToBinaryString: String { return String(Int(self) ?? 0, radix: 2) }
    var binaryToDecimal:          Int { return Int(drop0bPrefix, radix: 2) ?? 0 }
    var binaryToHexaString:    String { return String(binaryToDecimal, radix: 16) }

    subscript (r: Range<Int>) -> String {
        get {
            let startIndex = self.characters.index(self.startIndex, offsetBy: r.lowerBound)
            let endIndex = self.characters.index(self.startIndex, offsetBy: r.upperBound)
            
            return self[startIndex..<endIndex]
        }
    }

    func strip() -> String {
        return self.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )
    }

    func matchGroups(_ match: NSTextCheckingResult) -> [String] {
        let number = match.numberOfRanges
        var result = [String]()
        
        for index in 0..<number {
            let range = match.rangeAt(index)
            result.append(self[range.toRange()!])
        }
        return result
    }

    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let newLength = self.characters.count
        if newLength < toLength {
            return String(repeatElement(character, count: toLength - newLength)) + self
        } else {
            return self.substring(from: index(self.startIndex, offsetBy: newLength - toLength))
        }
    }
    
    func extendToLength(_ length: Int, withString padString: String=" ", atRight: Bool=true) -> String {
        return self.padding(toLength: length, withPad: padString, startingAt: 0)
    }

    func uuidFormat() -> String {
        var uuid = ""
        for (index, char) in self.characters.enumerated() {
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
        if value.characters.count == 0 {
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
        if value.characters.count == 0 {
            return nil
        }
        
        return value
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
}
