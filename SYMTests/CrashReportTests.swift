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

@testable import SYM
import XCTest

final class CrashReportTests: XCTestCase {
    private func crashContent(fromFile file: String, ofType fileType: String) -> String {
        let bundle = Bundle(for: Swift.type(of: self))
        let path = bundle.path(forResource: file, ofType: fileType)!
        return try! String(contentsOfFile: path)
    }

    func testAppleIPSDecoderMatchesModernJSON() {
        let content = crashContent(fromFile: "AppleJson", ofType: "ips")
        XCTAssertTrue(AppleIPSDecoder.match(content))
        XCTAssertFalse(KeepJSONDecoder.match(content))
    }

    func testAppleIPSDecoderDecodesModernJSON() {
        let content = crashContent(fromFile: "AppleJson", ofType: "ips")
        let report = AppleIPSDecoder().decode(content)

        XCTAssertEqual(report.appName, "Demo")
        XCTAssertEqual(report.device, "iPhone13,4")
        XCTAssertEqual(report.bundleID, "im.zorro.demo")
        XCTAssertEqual(report.uuid, "DB2FD9EC-8DD1-3021-98DF-93DB16CF4863")
        XCTAssertEqual(report.osVersion, "iPhone OS 15.2.1 (19C63)")
        XCTAssertEqual(report.appVersion, "1.0 (4)")
        XCTAssertEqual(report.crashedThreadIndex, 1)
        // JSON IPS writes cpuType as "ARM-64"; normalize for symbolication tools.
        XCTAssertEqual(report.arch, "arm64")
        XCTAssertFalse(report.binaryImages.isEmpty)
        XCTAssertFalse(report.threads.isEmpty)
        let crashed = report.threads.first(where: \.crashed)
        XCTAssertNotNil(crashed)
        XCTAssertEqual(crashed?.index, 1)
        XCTAssertEqual(crashed?.queue, "com.apple.root.default-qos")
        XCTAssertTrue(report.formattedContent.contains("Binary Images:"))
        XCTAssertTrue(report.formattedContent.contains("Thread 1 Crashed:"))
        XCTAssertTrue(report.formattedContent.contains("Identifier:          im.zorro.demo"))
        XCTAssertTrue(report.formattedContent.contains("Translated Report"))
        XCTAssertTrue(report.formattedContent.contains("\n-----------\nFull Report\n-----------\n"))
        XCTAssertTrue(report.formattedContent.contains(report.rawContent))
        XCTAssertNotNil(report.crashedThreadRange)
        XCTAssertNotEqual(report.rawContent, report.formattedContent)
        // Highlight ranges must stay in the translated section.
        if let range = report.crashedThreadRange {
            XCTAssertLessThanOrEqual(NSMaxRange(range), report.formattedContent.crashTranslatedSection.utf16.count)
        }
    }

    func testFullReportAppendixIsIgnoredByFramePatching() {
        let content = crashContent(fromFile: "AppleJson", ofType: "ips")
        let report = AppleIPSDecoder().decode(content)
        var before = report
        var after = report
        guard var frame = after.threads.first(where: \.crashed)?.frames.first else {
            XCTFail("expected crashed frame")
            return
        }
        frame.symbol = "SYMTestSymbol"
        frame.symbolLocation = 42
        after.threads = after.threads.map { thread in
            guard thread.crashed, !thread.frames.isEmpty else { return thread }
            var updated = thread
            updated.frames[0] = frame
            return updated
        }

        let patched = CrashFormatter.patchResolvedFrames(
            in: report.formattedContent,
            before: before,
            after: after
        )
        let parts = patched.crashSplitTranslatedAndFullReport()
        XCTAssertNotNil(parts.appendix)
        XCTAssertTrue(parts.translated.contains("SYMTestSymbol"))
        XCTAssertFalse(parts.appendix?.contains("SYMTestSymbol") == true)
        XCTAssertTrue(parts.appendix?.contains("\"usedImages\"") == true || parts.appendix?.contains("usedImages") == true)
    }

    func testLegacyIPSDecodesAsAppleText() {
        let content = crashContent(fromFile: "AppleDemo", ofType: "ips")
        XCTAssertFalse(AppleIPSDecoder.match(content))
        let report = CrashDecoding.decode(content)

        XCTAssertEqual(report.appName, "demo")
        XCTAssertEqual(report.device, "iPhone9,2")
        XCTAssertEqual(report.arch, "arm64")
        XCTAssertEqual(report.osVersion, "iPhone OS 10.1.1 (14B100)")
        XCTAssertEqual(report.appVersion, "3.5.5.2 (3.5.5)")
        XCTAssertEqual(report.bundleID, "im.zorro.demo")
        XCTAssertEqual(report.uuid, "42FD89F7-30BE-3AC5-A40A-4C1A99438DFB")
        XCTAssertEqual(report.embeddedBinaries.count, 16)
        XCTAssertTrue(report.appBacktraceRanges.count > 0)
        XCTAssertNotNil(report.crashedThreadRange)
        XCTAssertFalse(report.threads.isEmpty)
        // Classic already-rendered text must stay intact (no lossy rebuild).
        XCTAssertEqual(report.formattedContent, content)
        XCTAssertTrue(report.formattedContent.contains("Binary Images:"))
        XCTAssertTrue(report.formattedContent.contains("Incident Identifier:"))
        let crashedThread = report.threads.first(where: \.crashed)
        XCTAssertNotNil(crashedThread)
        XCTAssertFalse(crashedThread?.frames.isEmpty == true)
        XCTAssertTrue(
            crashedThread?.frames.first?.isSymbolicated == true,
            "AppleDemo frames are already symbolicated in the source text"
        )
        // name: + Crashed: headers must merge into one thread.
        XCTAssertEqual(report.threads.filter { $0.index == 0 }.count, 1)
        XCTAssertEqual(crashedThread?.index, 0)
        XCTAssertEqual(crashedThread?.queue, "com.apple.main-thread")
        XCTAssertFalse(crashedThread?.frames.isEmpty == true)
    }

    func testDwarfdumpRegexCapturesUUIDAndArch() {
        // dwarfdump --uuid lines end with a trailing space before the newline.
        let output = "UUID: 42FD89F7-30BE-3AC5-A40A-4C1A99438DFB (arm64) \n"
            + "UUID: AABBCCDD-EEFF-0011-2233-445566778899 (x86_64) \n"
        let re = try! Regex(
            "UUID: ([0-9a-z\\-]{36}) \\((.*)\\) ",
            options: [.anchorsMatchLines, .caseInsensitive]
        )
        let matches = re.matches(in: output) ?? []
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].captures?[1].uppercased(), "42FD89F7-30BE-3AC5-A40A-4C1A99438DFB")
        XCTAssertEqual(matches[0].captures?[2], "arm64")
        XCTAssertEqual(matches[1].captures?[1].uppercased(), "AABBCCDD-EEFF-0011-2233-445566778899")
        XCTAssertEqual(matches[1].captures?[2], "x86_64")
        // Full-match index must not be treated as the UUID.
        XCTAssertNotEqual(matches[0].captures?[0], matches[0].captures?[1])
    }

    func testKeepJSONAddressUsesLoadBasePlusOffset() {
        let json = """
        {
          "app_package_name": "im.zorro.demo",
          "key_stack": [],
          "trace": {
            "systemMsg": {
              "CFBundleExecutable": "Demo",
              "CFBundleIdentifier": "im.zorro.demo",
              "machine": "iPhone14,2",
              "cpu_arch": "arm64",
              "system_version": "17.0",
              "os_version": "21A329"
            },
            "errorMsg": { "mach": {}, "signal": {} },
            "threads": [
              {
                "index": 0,
                "thread_type": "Crashed",
                "thread_name": "main",
                "thread_stack": [
                  {
                    "image_name": "Demo",
                    "uuid": "42fd89f730be3ac5a40a4c1a99438dfb",
                    "load_address": 4294967296,
                    "address": 4096,
                    "is_key": true
                  }
                ]
              }
            ]
          }
        }
        """
        XCTAssertTrue(KeepJSONDecoder.match(json))
        let report = KeepJSONDecoder().decode(json)
        let frame = report.threads.first?.frames.first
        XCTAssertEqual(frame?.loadAddress, 0x1_0000_0000)
        XCTAssertEqual(frame?.imageOffset, 4096)
        XCTAssertEqual(frame?.address, 0x1_0000_0000 + 4096)
        XCTAssertEqual(report.binaryImages.first?.loadAddress, 0x1_0000_0000)
        XCTAssertFalse(frame?.isSymbolicated == true)
    }

    func testUnresolvedHexOffsetIsNotSymbolicated() {
        let frame = StackFrame(
            index: 0,
            imageName: "Demo",
            address: 0x100004000,
            symbol: "0x100000000 + 16384"
        )
        XCTAssertFalse(frame.isSymbolicated)

        let resolved = StackFrame(
            index: 0,
            imageName: "Demo",
            address: 0x100004000,
            symbol: "DemoApp.main",
            symbolLocation: 32
        )
        XCTAssertTrue(resolved.isSymbolicated)
    }

    func testClassicLineParserThreadHeadersAndFrames() {
        XCTAssertNil(ClassicCrashLineParser.parseThreadHeader("Thread 0 crashed with ARM Thread State (64-bit):"))

        let nameHeader = ClassicCrashLineParser.parseThreadHeader("Thread 0 name:  Dispatch queue: com.apple.main-thread")
        XCTAssertEqual(nameHeader?.index, 0)
        XCTAssertEqual(nameHeader?.queue, "com.apple.main-thread")
        XCTAssertFalse(nameHeader?.crashed == true)

        let crashedHeader = ClassicCrashLineParser.parseThreadHeader("Thread 0 Crashed:")
        XCTAssertEqual(crashedHeader?.index, 0)
        XCTAssertTrue(crashedHeader?.crashed == true)

        let plain = ClassicCrashLineParser.parseThreadHeader("Thread 12:")
        XCTAssertEqual(plain?.index, 12)
        XCTAssertFalse(plain?.crashed == true)

        // Console / recent macOS-translated headers use "::" and may embed the queue.
        let modernCrashed = ClassicCrashLineParser.parseThreadHeader(
            "Thread 0 Crashed::  Dispatch queue: com.apple.main-thread"
        )
        XCTAssertEqual(modernCrashed?.index, 0)
        XCTAssertTrue(modernCrashed?.crashed == true)
        XCTAssertEqual(modernCrashed?.queue, "com.apple.main-thread")

        let modernPlain = ClassicCrashLineParser.parseThreadHeader(
            "Thread 3::  Dispatch queue: com.apple.root.default-qos"
        )
        XCTAssertEqual(modernPlain?.index, 3)
        XCTAssertFalse(modernPlain?.crashed == true)
        XCTAssertEqual(modernPlain?.queue, "com.apple.root.default-qos")

        let mixedNameQueue = ClassicCrashLineParser.parseThreadNameFields(
            "Worker Dispatch Queue: com.example.worker"
        )
        XCTAssertEqual(mixedNameQueue.name, "Worker")
        XCTAssertEqual(mixedNameQueue.queue, "com.example.worker")

        let frame = ClassicCrashLineParser.parseStackFrameLine(
            "0   demo                          \t0x0000000100125780 DEMOViewController.status() + 140"
        )
        XCTAssertEqual(frame?.index, 0)
        XCTAssertEqual(frame?.imageName, "demo")
        XCTAssertEqual(frame?.address, 0x0000_0001_0012_5780)
        XCTAssertEqual(frame?.symbol, "DEMOViewController.status() + 140")
    }

    func testClassicLineParserBinaryImageLine() {
        let image = ClassicCrashLineParser.parseBinaryImageLine(
            "0x100070000 - 0x101607fff demo        arm64  <42fd89f730be3ac5a40a4c1a99438dfb> /var/containers/Bundle/Application/demo.app/demo"
        )
        XCTAssertEqual(image?.name, "demo")
        XCTAssertEqual(image?.arch, "arm64")
        XCTAssertEqual(image?.loadAddress, 0x1000_70000)
        XCTAssertEqual(image?.uuid, "42FD89F7-30BE-3AC5-A40A-4C1A99438DFB")
        XCTAssertEqual(image?.path, "/var/containers/Bundle/Application/demo.app/demo")
        XCTAssertEqual(image?.size, 0x1016_07fff - 0x1000_70000 + 1)
        XCTAssertTrue(image?.inApp == true)

        let spaced = ClassicCrashLineParser.parseBinaryImageLine(
            "       0x18232f000 -        0x182635fff Foundation arm64e  <9618b2f2a4c23e07b7eed8d9e1bdeaec> /System/Library/Frameworks/Foundation.framework/Foundation"
        )
        XCTAssertEqual(spaced?.name, "Foundation")
        XCTAssertEqual(spaced?.arch, "arm64e")
        XCTAssertEqual(spaced?.loadAddress, 0x1823_2f000)

        // Non-OS marker: leading '+' must not become part of the binary name.
        let marked = ClassicCrashLineParser.parseBinaryImageLine(
            "0x100e88000 -        0x101e2bfff +Demo arm64  <42fd89f730be3ac5a40a4c1a99438dfb> /var/containers/Bundle/Application/Demo.app/Demo"
        )
        XCTAssertEqual(marked?.name, "Demo")
        XCTAssertEqual(marked?.arch, "arm64")
        XCTAssertEqual(marked?.uuid, "42FD89F7-30BE-3AC5-A40A-4C1A99438DFB")
        XCTAssertTrue(marked?.inApp == true)

        let markedBundle = ClassicCrashLineParser.parseBinaryImageLine(
            "       0x1025e5000 -        0x1025e6ffb +com.example.Demo arm64  <5ed9bd632a553dddb3ffefcf61382f6f> /Users/USER/*/Demo.app/Contents/MacOS/Demo"
        )
        XCTAssertEqual(markedBundle?.name, "com.example.Demo")
        XCTAssertEqual(markedBundle?.arch, "arm64")
        XCTAssertTrue(markedBundle?.inApp == true)

        // macOS Console style: version in parentheses, no arch token.
        let macOSVersioned = ClassicCrashLineParser.parseBinaryImageLine(
            "       0x1025e5000 -        0x1025e6ffb +com.example.Demo (1.0 - 1) <5ED9BD63-2A55-3DDD-B3FF-EFCF61382F6F> /Users/USER/*/Demo.app/Contents/MacOS/Demo"
        )
        XCTAssertEqual(macOSVersioned?.name, "com.example.Demo")
        XCTAssertNil(macOSVersioned?.arch)
        XCTAssertEqual(macOSVersioned?.uuid, "5ED9BD63-2A55-3DDD-B3FF-EFCF61382F6F")
        XCTAssertTrue(macOSVersioned?.inApp == true)

        let macOSStar = ClassicCrashLineParser.parseBinaryImageLine(
            "0x104f44000 - 0x105257fff bdlli-bind (*) <18e247a7-aa91-3530-bb56-8be40b25fcbb> /Users/USER/*/bdlli-bind"
        )
        XCTAssertEqual(macOSStar?.name, "bdlli-bind")
        XCTAssertNil(macOSStar?.arch)
        XCTAssertEqual(macOSStar?.uuid, "18E247A7-AA91-3530-BB56-8BE40B25FCBB")
    }

    func testCrashArchNormalize() {
        XCTAssertEqual(CrashArch.normalize("ARM-64"), "arm64")
        XCTAssertEqual(CrashArch.normalize("arm64e"), "arm64e")
        XCTAssertEqual(CrashArch.normalize("X86-64"), "x86_64")
        XCTAssertTrue(CrashArch.looksLikeArch("arm64"))
        XCTAssertFalse(CrashArch.looksLikeArch("Demo"))
    }

    func testBinaryImageInAppPaths() {
        XCTAssertTrue(BinaryImage.isInApp(path: "/var/containers/Bundle/Application/ABC/Demo.app/Demo"))
        XCTAssertTrue(BinaryImage.isInApp(path: "/Users/USER/*/Demo.app/Contents/MacOS/Demo"))
        XCTAssertTrue(BinaryImage.isInApp(path: "/Applications/Demo.app/Contents/MacOS/Demo"))
        XCTAssertFalse(BinaryImage.isInApp(path: "/System/Library/Frameworks/Foundation.framework/Foundation"))
    }

    func testFormattedLineMatchesClassicColumns() {
        let frame = StackFrame(
            index: 0,
            imageName: "demo",
            address: 0x0000_0001_0012_5780,
            symbol: "DEMOViewController.status()",
            symbolLocation: 140
        )
        let line = frame.formattedLine
        XCTAssertTrue(line.contains("\t"), "classic Apple frames separate image and address with a tab")
        XCTAssertEqual(line.firstIndex(of: "\t").map { line.distance(from: line.startIndex, to: $0) }, 34)
        XCTAssertTrue(line.hasPrefix("0   demo"))
        XCTAssertTrue(line.contains("0x0000000100125780"), "PC must be zero-padded to 16 hex digits")
        XCTAssertTrue(line.contains("\t0x0000000100125780 "))
        XCTAssertTrue(line.contains("DEMOViewController.status() + 140"))
    }

    func testPatchResolvedFramesPreservesAddressColumn() {
        let before = StackFrame(
            index: 4,
            imageName: "UnicomWoCloud",
            address: 0x0000_0001_0415_8f84,
            imageOffset: 0x158f84,
            loadAddress: 0x1_0400_0000
        )
        var after = before
        after.symbol = "handleExceptions"
        after.symbolLocation = 220

        // Space-padded KSCrash-style column (PC starts at index 40).
        let original =
            "4   UnicomWoCloud                       0x0000000104158f84 0x104000000 + 1410948"
        let reportBefore = CrashReport(
            rawContent: original,
            threads: [CrashThread(index: 3, name: nil, queue: nil, crashed: false, frames: [before])]
        )
        let reportAfter = CrashReport(
            rawContent: original,
            threads: [CrashThread(index: 3, name: nil, queue: nil, crashed: false, frames: [after])]
        )

        let patched = CrashFormatter.patchResolvedFrames(
            in: original,
            before: reportBefore,
            after: reportAfter
        )
        let pc = "0x0000000104158f84"
        guard let originalPC = original.range(of: pc),
              let patchedPC = patched.range(of: pc)
        else {
            return XCTFail("expected PC in original and patched lines")
        }
        XCTAssertEqual(
            original.distance(from: original.startIndex, to: originalPC.lowerBound),
            patched.distance(from: patched.startIndex, to: patchedPC.lowerBound),
            "address column must stay put after symbolicate"
        )
        XCTAssertTrue(patched.contains("handleExceptions + 220"))
        XCTAssertFalse(patched.contains("0x104000000 + 1410948"))
    }

    func testSymbolicateWithoutDsymsPreservesClassicContent() async {
        let content = crashContent(fromFile: "AppleDemo", ofType: "ips")
        let report = CrashFormatter.format(CrashDecoding.decode(content))
        let symbolicated = await report.symbolicated(using: CompositeSymbolEngine(), dsyms: [:])

        XCTAssertEqual(symbolicated.formattedContent, content)
        XCTAssertTrue(symbolicated.formattedContent.contains("DEMOViewController.status()"))
        XCTAssertTrue(symbolicated.formattedContent.contains("Binary Images:"))
        XCTAssertTrue(symbolicated.formattedContent.contains("Incident Identifier:"))
    }

    func testCrashUUIDNormalize() {
        XCTAssertEqual(
            CrashUUID.normalize("42fd89f730be3ac5a40a4c1a99438dfb"),
            "42FD89F7-30BE-3AC5-A40A-4C1A99438DFB"
        )
        XCTAssertEqual(
            CrashUUID.normalize("E5B0A378-6816-3D90-86FD-2AEF15894A85"),
            "E5B0A378-6816-3D90-86FD-2AEF15894A85"
        )
        XCTAssertNil(CrashUUID.normalize("not-a-uuid"))
        XCTAssertNil(CrashUUID.normalize("ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"))
        XCTAssertNil(CrashUUID.normalize("42fd89f730be3ac5a40a4c1a99438d")) // too short
    }

    func testImagesByUUIDPrefersExecutableOnDuplicate() {
        let uuid = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        let framework = BinaryImage(
            name: "FooKit",
            uuid: uuid,
            arch: "arm64",
            loadAddress: 0x1000,
            size: 0x100,
            path: "/App.app/Frameworks/FooKit.framework/FooKit",
            isExecutable: false,
            inApp: true
        )
        let executable = BinaryImage(
            name: "Demo",
            uuid: uuid,
            arch: "arm64",
            loadAddress: 0x100000000,
            size: 0x1000,
            path: "/App.app/Demo",
            isExecutable: true,
            inApp: true
        )
        // Must not trap (unlike Dictionary(uniqueKeysWithValues:)).
        let map = CrashUUID.imagesByUUID([framework, executable])
        XCTAssertEqual(map.count, 1)
        XCTAssertEqual(map[uuid]?.name, "Demo")
        XCTAssertTrue(map[uuid]?.isExecutable == true)
    }

    func testCrashDocumentReadRejectsInvalidUTF8AndPlist() {
        let doc = CrashDocument()
        XCTAssertThrowsError(try doc.read(from: Data([0xFF, 0xFE, 0xFD]), ofType: CrashFileType.crash)) { error in
            XCTAssertEqual(error as? CrashDocumentError, .invalidEncoding)
        }
        XCTAssertThrowsError(try doc.read(from: Data("not a plist".utf8), ofType: CrashFileType.plist)) { error in
            XCTAssertEqual(error as? CrashDocumentError, .invalidPlist)
        }
        let emptyPlist = try! PropertyListSerialization.data(
            fromPropertyList: ["other": "value"],
            format: .xml,
            options: 0
        )
        XCTAssertThrowsError(try doc.read(from: emptyPlist, ofType: CrashFileType.plist)) { error in
            XCTAssertEqual(error as? CrashDocumentError, .missingCrashDescription)
        }
    }

    func testCrashDecodingDispatcher() {
        let appleJson = crashContent(fromFile: "AppleJson", ofType: "ips")
        let appleDemo = crashContent(fromFile: "AppleDemo", ofType: "ips")

        XCTAssertFalse(CrashDecoding.decode(appleJson).formattedContent.isEmpty)
        XCTAssertEqual(CrashDecoding.decode(appleDemo).appName, "demo")
        XCTAssertTrue(AppleIPSDecoder.match(appleJson))
        XCTAssertFalse(AppleIPSDecoder.match(appleDemo))
    }

    func testDsymLocatorConditionQuotesUUIDsAndOrdersExecutableFirst() {
        let images = [
            BinaryImage(
                name: "FooKit",
                uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                arch: "arm64",
                loadAddress: 0x1,
                isExecutable: false,
                inApp: true
            ),
            BinaryImage(
                name: "Demo",
                uuid: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                arch: "arm64",
                loadAddress: 0x2,
                isExecutable: true,
                inApp: true
            ),
        ]
        let ordered = DsymLocator.orderedUUIDs(from: images)
        XCTAssertEqual(ordered.first, "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")
        XCTAssertEqual(ordered.count, 2)

        let condition = DsymLocator.createCondition(bundleID: "im.zorro.demo", binaries: images)
        XCTAssertNotNil(condition)
        XCTAssertTrue(condition!.contains("com_apple_xcode_dsym_uuids == \"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\""))
        XCTAssertTrue(condition!.contains("kMDItemCFBundleIdentifier == \"im.zorro.demo\""))
        XCTAssertTrue(condition!.hasPrefix("com_apple_xcode_dsym_uuids == \"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\""))
    }

    func testDsymFilesMapNormalizesUUIDKeys() {
        let file = DsymFile(
            name: "Demo.dSYM",
            path: "/tmp/Demo.dSYM",
            binaryPath: "/tmp/Demo.dSYM/Contents/Resources/DWARF/Demo",
            uuids: ["42fd89f730be3ac5a40a4c1a99438dfb"]
        )
        let map = DsymLocator.dsymFilesMap(from: [file])
        XCTAssertNotNil(map["42FD89F7-30BE-3AC5-A40A-4C1A99438DFB"])
        XCTAssertEqual(map.count, 1)
    }

    func testDwarfdumpDownloadRegexCaptureIndexes() {
        let line = "UUID: F9E72B35-ACE9-3B64-8D8C-6A59BE609683 (arm64) /tmp/Demo.dSYM/Contents/Resources/DWARF/Demo\n"
        let match = Regex.dwarfdump.firstMatch(in: line)
        XCTAssertEqual(match?.captures?[1].uppercased(), "F9E72B35-ACE9-3B64-8D8C-6A59BE609683")
        XCTAssertEqual(match?.captures?[2], "/tmp/Demo.dSYM/Contents/Resources/DWARF/Demo")
    }

    func testVersionHintsParseBuildInParentheses() {
        let hints = DsymLocator.versionHints(from: "6.1.0 (20260804173156)")
        XCTAssertEqual(hints.marketing, "6.1.0")
        XCTAssertEqual(hints.build, "20260804173156")
    }

    func testUUIDsOfBinaryReadsMachOHeaderWithoutDwarfdump() throws {
        let path = "/usr/bin/dwarfdump"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: path))
        let uuids = DsymLocator.uuidsOfBinary(at: path)
        XCTAssertFalse(uuids.isEmpty, "expected LC_UUID from \(path)")
        XCTAssertEqual(uuids.first?.count, 36)
        XCTAssertEqual(uuids.first, CrashUUID.normalize(uuids.first))
    }

    func testHighlightFramesMatchesMultipleBinariesInOnePass() {
        let regex = CrashRegex.frames(forBinaries: ["Demo", "DemoKit", "com.example.App"])
        XCTAssertNotNil(regex)
        let content =
            "0   Demo                           0x0000000100000000 main + 4\n"
            + "0   DemoKit                        0x0000000100001000 start + 1\n"
            + "0   com.example.App                0x0000000100002000 foo + 2\n"
        let matches = regex?.matches(in: content) ?? []
        XCTAssertEqual(matches.count, 3)
    }

    func testHighlightFramesEscapesBinaryNames() {
        // '.' in a bundle-id style name is literal, not a wildcard.
        let regex = CrashRegex.frames(forBinaries: ["com.example.App"])
        let notMatch = "0   comXexampleXApp                0x0000000100002000 foo + 2\n"
        XCTAssertNil(regex?.firstMatch(in: notMatch))

        let literal = "0   com.example.App                0x0000000100002000 foo + 2\n"
        XCTAssertNotNil(regex?.firstMatch(in: literal))
    }

    // MARK: - Atos output parsing

    func testAtosOutputParsing() {
        let frame = StackFrame(index: 0, imageName: "Demo", address: 0x1_0000_4000)

        // "symbol (in image) (file:line)" — the informative form.
        let withSource = AtosSymbolEngine.parseAtosOutput(
            "DemoViewController.viewDidLoad() (in Demo) (/Users/x/DemoViewController.swift:42)",
            frame: frame
        )
        XCTAssertEqual(withSource.symbol, "DemoViewController.viewDidLoad()")
        XCTAssertEqual(withSource.sourceFile, "/Users/x/DemoViewController.swift")
        XCTAssertEqual(withSource.sourceLine, 42)

        // "symbol + offset" form.
        let withOffset = AtosSymbolEngine.parseAtosOutput("main + 128", frame: frame)
        XCTAssertEqual(withOffset.symbol, "main")
        XCTAssertEqual(withOffset.symbolLocation, 128)

        // "symbol (in image)" form.
        let inImage = AtosSymbolEngine.parseAtosOutput("main (in Demo)", frame: frame)
        XCTAssertEqual(inImage.symbol, "main")

        // atos echoes the bare address when it cannot resolve — the frame must
        // stay unsymbolicated (hex garbage would also inflate the summary count).
        let unresolved = AtosSymbolEngine.parseAtosOutput("0x0000000102ba2000", frame: frame)
        XCTAssertEqual(unresolved, frame)
        XCTAssertFalse(unresolved.isSymbolicated)

        // Empty output keeps the frame untouched.
        let empty = AtosSymbolEngine.parseAtosOutput("  \n", frame: frame)
        XCTAssertEqual(empty, frame)
    }

    // MARK: - patchResolvedFrames matching

    func testPatchResolvedFramesKeysByImageAndAddress() {
        // Same PC in two different images: only the resolved image's line may change.
        let lineA = "0   AppA                          \t0x0000000100000000 0x100000000 + 12"
        let lineB = "0   AppB                          \t0x0000000100000000 0x100000000 + 12"
        let content = "Thread 0 Crashed:\n\(lineA)\n\(lineB)\n"

        let frameA = StackFrame(index: 0, imageName: "AppA", address: 0x1_0000_0000, imageOffset: 12, loadAddress: 0x1_0000_0000)
        let frameB = StackFrame(index: 0, imageName: "AppB", address: 0x1_0000_0000, imageOffset: 12, loadAddress: 0x1_0000_0000)

        let reportBefore = CrashReport(
            rawContent: content,
            threads: [CrashThread(index: 0, name: nil, queue: nil, crashed: true, frames: [frameA, frameB])]
        )

        var resolvedA = frameA
        resolvedA.symbol = "AppA.main"
        resolvedA.symbolLocation = 12
        let reportAfter = CrashReport(
            rawContent: content,
            threads: [CrashThread(index: 0, name: nil, queue: nil, crashed: true, frames: [resolvedA, frameB])]
        )

        let patched = CrashFormatter.patchResolvedFrames(in: content, before: reportBefore, after: reportAfter)
        XCTAssertTrue(patched.contains("AppA.main + 12"), "resolved frame must be patched in place")
        XCTAssertTrue(patched.contains(lineB), "same address in another image must keep its line")
        XCTAssertFalse(patched.contains("AppB                          \t0x0000000100000000 AppA.main"))
    }

    // MARK: - dSYM index store

    func testDsymIndexStorePersistsAndServesHits() throws {
        let dir = URL(fileURLWithPath: FileManager.default.temporaryPath(), isDirectory: true)
        try FileManager.default.createDirectory(atPath: dir.path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir.path) }

        let uuidA = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        let uuidB = "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
        let dwarfPath = dir.path + "/Demo.dSYM/Contents/Resources/DWARF/Demo"
        try FileManager.default.createDirectory(
            atPath: (dwarfPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )

        let store = DsymIndexStore(directory: dir)
        store.record([DsymFile(
            name: "Demo.dSYM",
            path: dir.path + "/Demo.dSYM",
            binaryPath: dwarfPath,
            uuids: [uuidA]
        )])
        store.save()

        // Entries survive the process boundary.
        let reloaded = DsymIndexStore(directory: dir)
        XCTAssertEqual(reloaded.count, 1)
        let needed: Set<String> = [uuidA]
        let hit = reloaded.cachedFiles(neededUUIDs: needed, stopUUIDs: needed)
        XCTAssertEqual(hit?.count, 1)
        XCTAssertEqual(hit?.first?.binaryPath, dwarfPath)

        // Partial coverage is a miss — the caller falls back to a full scan.
        XCTAssertNil(reloaded.cachedFiles(neededUUIDs: [uuidA, uuidB], stopUUIDs: [uuidA, uuidB]))

        // A vanished path is a miss even before save() prunes it.
        try FileManager.default.removeItem(atPath: dir.path + "/Demo.dSYM")
        XCTAssertNil(reloaded.cachedFiles(neededUUIDs: needed, stopUUIDs: needed))
        reloaded.save()
        XCTAssertEqual(reloaded.count, 0, "stale entries must be pruned on save")
    }

    // MARK: - Download progress parsing

    func testDownloadProgressParsesCurlOutput() {
        var progress = DsymDownloadTask.Progress()
        let output = "% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current\n"
            + "                                 Dload  Upload   Total   Spent    Left  Speed\n"
            + " 10  286M   10 30.2M    0     0   830k      0  0:05:53  0:00:37  0:05:16  1660k\r"
            + " 25  286M   25 71.5M    0     0  1890k      0  0:02:35  0:00:38  0:01:57  1930k\r"
        progress.update(fromConsoleOutput: output)
        XCTAssertEqual(progress.percentage, 25)
        XCTAssertEqual(progress.totalSize, "286M")
        XCTAssertEqual(progress.downloadedSize, "71.5M")
        XCTAssertEqual(progress.timeLeft, "0:01:57")
        XCTAssertEqual(progress.speed, "1930k")

        // Output without a curl progress table leaves the values untouched.
        var plain = DsymDownloadTask.Progress()
        plain.update(fromConsoleOutput: "downloading...\ndone")
        XCTAssertEqual(plain.percentage, 0)
    }
}

/// Guards `SubProcess.run()` against dropped trailing output and races between the
/// readability handler and the caller (regression tests for the readToEnd drain).
final class SubProcessTests: XCTestCase {
    func testCapturesOutputWithoutTrailingNewline() {
        let process = SubProcess(cmd: "/bin/echo", args: ["-n", "hello world"])
        XCTAssertTrue(process.run())
        XCTAssertEqual(process.exitCode, 0)
        XCTAssertEqual(process.output, "hello world")
    }

    func testCapturesStderr() {
        let process = SubProcess(cmd: "/bin/sh", args: ["-c", "echo err >&2"])
        XCTAssertTrue(process.run())
        XCTAssertEqual(process.output, "")
        XCTAssertEqual(process.error.trimmingCharacters(in: .whitespacesAndNewlines), "err")
    }

    func testCapturesLargeOutputWithoutDroppingTail() {
        let lineCount = 10_000
        let process = SubProcess(cmd: "/bin/sh", args: ["-c", "seq 1 \(lineCount)"])
        XCTAssertTrue(process.run())
        let lines = process.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, lineCount)
        XCTAssertEqual(lines.last, "\(lineCount)")
    }
}
