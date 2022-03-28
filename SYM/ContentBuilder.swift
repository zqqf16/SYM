// The MIT License (MIT)
//
// Copyright (c) 2022 zqqf16
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
import SwiftyJSON

protocol ContentComponent {
    var string: String { get }
}

@resultBuilder
struct ContentBuilder {
    static func buildBlock(_ components: ContentComponent...) -> String {
        return components.compactMap({$0.string}).joined(separator: "")
    }
    static func buildArray(_ components: [ContentComponent]) -> String {
        return components.compactMap({$0.string}).joined(separator: "")
    }
    static func buildEither(first component: ContentComponent) -> String {
        component.string
    }
    static func buildEither(second component: ContentComponent) -> String {
        component.string
    }
    static func buildOptional(_ component: ContentComponent?) -> String {
        return component?.string ?? ""
    }
}

extension String: ContentComponent {
    var string: String {
        return self
    }
    
    func format(_ args: CVarArg...) -> Self {
        return String(format: self, arguments: args)
    }
    
    init(@ContentBuilder builder: () -> String) {
        self = builder()
    }
}

struct Line: ContentComponent {
    var value: String
    
    var string: String {
        return value + "\n"
    }
    
    static let empty: Line = Line("")
    
    init(_ value: String) {
        self.value = value
    }
    
    init(@ContentBuilder builder: () -> String) {
        self.value = builder()
    }
    
    func format(_ args: CVarArg...) -> Line {
        return Line(self.value.format(args))
    }
}
