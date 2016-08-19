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
    subscript (r: Range<Int>) -> String {
        get {
            let startIndex = self.startIndex.advancedBy(r.startIndex)
            let endIndex = self.startIndex.advancedBy(r.endIndex)
            
            return self[startIndex..<endIndex]
        }
    }

    func strip() -> String {
        return self.stringByTrimmingCharactersInSet(
            NSCharacterSet.whitespaceAndNewlineCharacterSet()
        )
    }

    func matchGroups(match: NSTextCheckingResult) -> [String] {
        let number = match.numberOfRanges
        var result = [String]()
        
        for index in 0..<number {
            let range = match.rangeAtIndex(index)
            result.append(self[range.toRange()!])
        }
        return result
    }

    func extendToLength(length: Int, withString padString: String=" ") -> String {
        return self.stringByPaddingToLength(length, withString: padString, startingAtIndex: 0)
    }

    func uuidFormat() -> String {
        var uuid = ""
        for (index, char) in self.characters.enumerate() {
            if [8, 12, 16, 20].contains(index) {
                uuid.append("-" as Character)
            }
            uuid.append(char)
        }
        
        return uuid.uppercaseString
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
enum FileError: ErrorType {
    case DirectoryNotExist
    case CreateFailed
}

extension NSFileManager {
    func findOrCreateDirectory(searchPathDirectory directory: NSSearchPathDirectory, inDomain domain: NSSearchPathDomainMask, appendPathComponent component: String?) throws -> String {
        let paths = NSSearchPathForDirectoriesInDomains(directory, domain, true)
        
        if paths.count == 0 {
            throw FileError.DirectoryNotExist
        }
    
        var path = paths[0]
        if component != nil {
            path = (path as NSString).stringByAppendingPathComponent(component!)
        }
        
        do {
            try self.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw FileError.CreateFailed
        }
        
        return path
    }
    
    func appSupportDirectory() -> String? {
        let app = NSBundle.mainBundle().infoDictionary!["CFBundleExecutable"] as! String
        
        let path: String
        do {
            path = try self.findOrCreateDirectory(searchPathDirectory: .ApplicationSupportDirectory, inDomain: .UserDomainMask, appendPathComponent: app)
        } catch {
            return nil
        }
        
        return path
    }
    
    func temporaryPath() -> String {
        let uuid = NSProcessInfo.processInfo().globallyUniqueString
        return (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(uuid)
    }
}