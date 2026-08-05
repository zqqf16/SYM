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

struct StackFrame: Equatable {
    var index: Int
    var imageName: String
    var address: UInt64
    var imageOffset: UInt64?
    var loadAddress: UInt64?
    var imageUUID: String?
    var symbol: String?
    var symbolLocation: Int?
    var sourceFile: String?
    var sourceLine: Int?

    var formattedLine: String {
        // Match classic Apple text: "%-4d%-30s\t0x%016llx symbol"
        let paddedIndex = String(index).padding(length: 4)
        let paddedImage = imageName.padding(length: 30)
        var line = "\(paddedIndex)\(paddedImage)\t\(address.crashHexString16) "
        if let symbolText = symbolDescription, !symbolText.isEmpty {
            line += symbolText
        } else if let loadAddress = loadAddress, let offset = imageOffset {
            line += "\(loadAddress.crashHexString16) + \(offset)"
        } else if let offset = imageOffset {
            line += "\(address.crashHexString16) + \(offset)"
        }
        return line
    }

    /// Symbol / source text after the PC address (no leading space).
    var symbolDescription: String? {
        guard let symbol = symbol?.trimmingCharacters(in: .whitespacesAndNewlines),
              !symbol.isEmpty
        else {
            return nil
        }
        var text: String
        if let location = symbolLocation {
            text = "\(symbol) + \(location)"
        } else {
            text = symbol
        }
        if let sourceFile = sourceFile, let sourceLine = sourceLine {
            text += " (\(sourceFile):\(sourceLine))"
        }
        return text
    }

    var isSymbolicated: Bool {
        guard let symbol = symbol?.trimmingCharacters(in: .whitespacesAndNewlines),
              !symbol.isEmpty
        else {
            return false
        }
        // Hex address + offset is still unresolved (common in Keep/Umeng placeholders).
        if symbol.range(of: #"^0[xX][0-9A-Fa-f]+\s*\+\s*\d+$"#, options: .regularExpression) != nil {
            return false
        }
        return true
    }
}

struct BinaryImage: Equatable {
    var name: String
    var uuid: String?
    var arch: String?
    var loadAddress: UInt64?
    var size: UInt64?
    var path: String?
    var isExecutable: Bool
    var inApp: Bool

    static func isInApp(path: String?) -> Bool {
        guard let path = path, !path.isEmpty else {
            return false
        }
        // iOS / iPadOS / tvOS / visionOS app bundles
        if path.contains("/var/containers/Bundle/Application")
            || path.contains("/var/mobile/Containers/Bundle/Application")
            || path.contains("/private/var/containers/Bundle/Application")
        {
            return true
        }
        // macOS app bundles (incl. privacy-redacted `/Users/USER/*/App.app/...`)
        if path.contains(".app/Contents/MacOS/")
            || path.contains(".app/Contents/Frameworks/")
            || (path.contains(".app/") && path.contains("/Users/"))
            || (path.hasPrefix("/Applications/") && path.contains(".app/"))
        {
            return true
        }
        return false
    }
}

struct CrashThread: Equatable {
    var index: Int
    var name: String?
    var queue: String?
    var crashed: Bool
    var frames: [StackFrame]
}

struct CrashReport: Equatable {
    var rawContent: String
    var formattedContent: String
    var appName: String?
    var device: String?
    var bundleID: String?
    var arch: String?
    var uuid: String?
    var osVersion: String?
    var appVersion: String?
    var binaryImages: [BinaryImage]
    var threads: [CrashThread]
    var lastExceptionBacktrace: [StackFrame]?
    var crashedThreadIndex: Int?
    var exceptionType: String?
    var exceptionCodes: String?
    var crashedThreadRange: NSRange?
    var appBacktraceRanges: [NSRange]
    var needsUmengAddressFix: Bool

    var embeddedBinaries: [BinaryImage] {
        binaryImages.filter(\.inApp)
    }

    init(
        rawContent: String,
        formattedContent: String? = nil,
        appName: String? = nil,
        device: String? = nil,
        bundleID: String? = nil,
        arch: String? = nil,
        uuid: String? = nil,
        osVersion: String? = nil,
        appVersion: String? = nil,
        binaryImages: [BinaryImage] = [],
        threads: [CrashThread] = [],
        lastExceptionBacktrace: [StackFrame]? = nil,
        crashedThreadIndex: Int? = nil,
        exceptionType: String? = nil,
        exceptionCodes: String? = nil,
        crashedThreadRange: NSRange? = nil,
        appBacktraceRanges: [NSRange] = [],
        needsUmengAddressFix: Bool = false
    ) {
        self.rawContent = rawContent
        self.formattedContent = formattedContent ?? rawContent
        self.appName = appName
        self.device = device
        self.bundleID = bundleID
        self.arch = arch
        self.uuid = uuid
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.binaryImages = binaryImages
        self.threads = threads
        self.lastExceptionBacktrace = lastExceptionBacktrace
        self.crashedThreadIndex = crashedThreadIndex
        self.exceptionType = exceptionType
        self.exceptionCodes = exceptionCodes
        self.crashedThreadRange = crashedThreadRange
        self.appBacktraceRanges = appBacktraceRanges
        self.needsUmengAddressFix = needsUmengAddressFix
    }
}

enum CrashUUID {
    static func normalize(_ uuid: String?) -> String? {
        guard var uuid = uuid?.trimmingCharacters(in: .whitespacesAndNewlines), !uuid.isEmpty else {
            return nil
        }

        if uuid.contains("-") {
            uuid = uuid.uppercased()
        } else {
            var formatted = ""
            for (index, char) in uuid.enumerated() {
                if [8, 12, 16, 20].contains(index) {
                    formatted.append("-")
                }
                formatted.append(char)
            }
            uuid = formatted.uppercased()
        }

        let hex = uuid.replacingOccurrences(of: "-", with: "")
        guard hex.count == 32, hex.allSatisfy(\.isHexDigit) else {
            return nil
        }
        // Canonical 8-4-4-4-12 form.
        let parts = [
            hex.prefix(8),
            hex.dropFirst(8).prefix(4),
            hex.dropFirst(12).prefix(4),
            hex.dropFirst(16).prefix(4),
            hex.dropFirst(20).prefix(12),
        ]
        return parts.map(String.init).joined(separator: "-")
    }

    /// Build a UUID → image map without trapping on duplicate keys.
    /// Prefer the executable (or in-app) image when UUIDs collide.
    static func imagesByUUID(_ images: [BinaryImage]) -> [String: BinaryImage] {
        var map = [String: BinaryImage]()
        for image in images {
            guard let uuid = normalize(image.uuid) else {
                continue
            }
            if let existing = map[uuid] {
                let preferNew = (image.isExecutable && !existing.isExecutable)
                    || (image.inApp && !existing.inApp && !existing.isExecutable)
                if preferNew {
                    map[uuid] = image
                }
            } else {
                map[uuid] = image
            }
        }
        return map
    }
}
