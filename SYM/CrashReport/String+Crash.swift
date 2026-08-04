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

extension String {
    var crashHexAddress: UInt64? {
        var hex = self
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        return UInt64(hex, radix: 16)
    }

    func crashUUIDFormat() -> String {
        CrashUUID.normalize(self) ?? self
    }

    func crashStrip() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func crashPadding(length: Int, atLeft: Bool = false) -> String {
        if atLeft {
            return String(repeating: " ", count: max(0, length - count)) + self
        }
        return padding(toLength: length, withPad: " ", startingAt: 0)
    }
}

/// Normalize CPU / image architecture tokens from modern Apple crash reports.
/// JSON IPS uses values like `ARM-64`; classic text uses `arm64` / `arm64e`.
enum CrashArch {
    static func normalize(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        switch raw.lowercased() {
        case "arm-64", "arm64":
            return "arm64"
        case "arm64e":
            return "arm64e"
        case "x86-64", "x86_64":
            return "x86_64"
        case "i386":
            return "i386"
        case "arm", "armv6", "armv7", "armv7s":
            return raw.lowercased()
        default:
            return raw
        }
    }

    static func looksLikeArch(_ token: String) -> Bool {
        let normalized = token.lowercased()
        return [
            "arm64", "arm64e", "arm-64",
            "arm", "armv6", "armv7", "armv7s",
            "x86_64", "x86-64", "i386",
        ].contains(normalized)
    }
}

extension UInt64 {
    var crashHexString: String {
        String(format: "0x%llx", self)
    }
}

extension Optional where Wrapped == String {
    var crashHexAddress: UInt64? {
        self?.crashHexAddress
    }
}

extension Optional where Wrapped == Int {
    var crashUInt64: UInt64? {
        guard let value = self else {
            return nil
        }
        return UInt64(value)
    }
}

extension Optional where Wrapped == Int64 {
    var crashUInt64: UInt64? {
        guard let value = self else {
            return nil
        }
        return UInt64(value)
    }
}
