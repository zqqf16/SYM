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

struct Regex {
    class Match {
        let string: String
        fileprivate let result: NSTextCheckingResult
        
        init(_ string: String, result: NSTextCheckingResult) {
            self.string = string
            self.result = result
        }
        
        lazy var captures: [String]? = {
            let number = result.numberOfRanges
            guard number >= 1 else {
                return nil
            }
            
            var groups = [String]()
            for index in 0..<number {
                if let range = Range(result.range(at: index), in: string) {
                    groups.append(String(string[range]))
                }
            }
            
            return groups
        }()
        
        var range: NSRange {
            return result.range
        }
    }
    
    fileprivate let _regex: NSRegularExpression
    
    var pattern: String {
        return _regex.pattern
    }
    
    typealias Options = NSRegularExpression.Options
    typealias MatchingOptions = NSRegularExpression.MatchingOptions
    
    init(_ pattern: String, options: Options = []) throws {
        try _regex = NSRegularExpression(pattern: pattern, options: options)
    }
    
    func firstMatch(in string: String, options: MatchingOptions = []) -> Match? {
        let range = NSRange(string.startIndex..., in: string)
        guard let result = _regex.firstMatch(in: string, options: options, range: range) else {
            return nil
        }
        
        return Match(string, result: result)
    }
    
    func matches(in string: String, options: MatchingOptions = []) -> [Match]? {
        let range = NSRange(string.startIndex..., in: string)
        let matches = _regex.matches(in: string, options: options, range: range)
        if matches.count == 0 {
            return nil
        }
        
        return matches.map { Match(string, result: $0) }
    }
}

// MARK: dwarfdump
extension Regex {
    //UUID: F9E72B35-ACE9-3B64-8D8C-6A59BE609683 (armv7) /path/to/xxx.dSYM/Contents/Resources/DWARF/xxx
    static let dwarfdump = try! Regex("^UUID: ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) \\(.*\\) (.*)", options: [.anchorsMatchLines, .caseInsensitive])
}
