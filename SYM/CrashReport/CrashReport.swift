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
        let paddedIndex = String(index).padding(length: 4)
        let paddedImage = imageName.padding(length: 39)
        var line = "\(paddedIndex)\(paddedImage)\(address.crashHexString) "
        if let symbol = symbol, let location = symbolLocation {
            line += "\(symbol) + \(location)"
        } else if let loadAddress = loadAddress, let offset = imageOffset {
            line += "\(loadAddress.crashHexString) + \(offset)"
        } else if let offset = imageOffset {
            line += "\(address.crashHexString) + \(offset)"
        }
        if let sourceFile = sourceFile, let sourceLine = sourceLine {
            line += " (\(sourceFile):\(sourceLine))"
        }
        return line
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
        guard let path = path else {
            return false
        }
        return path.contains("/var/containers/Bundle/Application")
            || path.hasPrefix("/var/mobile/Containers/Bundle/Application")
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
            return uuid.uppercased()
        }

        var formatted = ""
        for (index, char) in uuid.enumerated() {
            if [8, 12, 16, 20].contains(index) {
                formatted.append("-")
            }
            formatted.append(char)
        }
        return formatted.uppercased()
    }
}
