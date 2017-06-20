// The MIT License (MIT)
//
// Copyright (c) 2017 zqqf16
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

struct RE {
    let regex: NSRegularExpression
    
    init(_ pattern: String, optoins: NSRegularExpression.Options = []) throws {
        try regex = NSRegularExpression(pattern: pattern,
                                        options: optoins)
    }
    
    func findFirst(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> [String]? {
        if let result = regex.firstMatch(in: input, options: options, range: NSMakeRange(0, input.utf16.count)) {
            return input.matchGroups(fromResult: result)
        }
        
        return nil
    }
    
    func findAll(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> [[String]]? {
        let matches = regex.matches(in: input,
                                    options: options,
                                    range: NSMakeRange(0, input.utf16.count))
        if matches.count == 0 {
            return nil
        }
        
        return matches.map { input.matchGroups(fromResult: $0) }
    }
    
    func match(_ input: String, options: NSRegularExpression.MatchingOptions = []) -> [String]? {
        return findFirst(input, options: options)
    }
}
