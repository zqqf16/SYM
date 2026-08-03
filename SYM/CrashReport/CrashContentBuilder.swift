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

protocol CrashContentComponent {
    var string: String { get }
}

@resultBuilder
enum CrashContentBuilder {
    static func buildBlock(_ components: CrashContentComponent...) -> String {
        components.compactMap { $0.string }.joined(separator: "")
    }

    static func buildArray(_ components: [CrashContentComponent]) -> String {
        components.compactMap { $0.string }.joined(separator: "")
    }

    static func buildEither(first component: CrashContentComponent) -> String {
        component.string
    }

    static func buildEither(second component: CrashContentComponent) -> String {
        component.string
    }

    static func buildOptional(_ component: CrashContentComponent?) -> String {
        component?.string ?? ""
    }
}

struct CrashLine: CrashContentComponent {
    var value: String

    var string: String {
        value + "\n"
    }

    static let empty: CrashLine = .init("")

    init(_ value: String) {
        self.value = value
    }

    init(@CrashContentBuilder builder: () -> String) {
        value = builder()
    }

    func format(_ args: CVarArg...) -> CrashLine {
        CrashLine(String(format: value, arguments: args))
    }
}

func crashString(@CrashContentBuilder builder: () -> String) -> String {
    builder()
}

struct CrashText: CrashContentComponent {
    let string: String

    init(_ string: String) {
        self.string = string
    }
}
