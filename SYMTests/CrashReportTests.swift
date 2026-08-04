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
        XCTAssertNotNil(report.crashedThreadRange)
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
        XCTAssertTrue(line.contains("DEMOViewController.status() + 140"))
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

    func testUmengDecoder() {
        let content = crashContent(fromFile: "UmengDemo", ofType: "crash")
        XCTAssertTrue(UmengDecoder.match(content))

        let report = UmengDecoder().decode(content)
        XCTAssertEqual(report.appName, "DemoApp")
        XCTAssertNil(report.device)
        XCTAssertEqual(report.uuid, "E5B0A378-6816-3D90-86FD-2AEF15894A85")
        XCTAssertTrue(report.needsUmengAddressFix)
        XCTAssertTrue(report.appBacktraceRanges.count > 0)

        let binary = report.binaryImages.first
        XCTAssertNotNil(binary)
        XCTAssertEqual(binary?.name, "DemoApp")
        XCTAssertEqual(binary?.loadAddress, 0x0000000100000000)
        XCTAssertEqual(report.embeddedBinaries.first?.name, "DemoApp")
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
    }

    func testCrashDecodingDispatcher() {
        let appleJson = crashContent(fromFile: "AppleJson", ofType: "ips")
        let appleDemo = crashContent(fromFile: "AppleDemo", ofType: "ips")
        let umeng = crashContent(fromFile: "UmengDemo", ofType: "crash")

        XCTAssertFalse(CrashDecoding.decode(appleJson).formattedContent.isEmpty)
        XCTAssertEqual(CrashDecoding.decode(appleDemo).appName, "demo")
        XCTAssertTrue(CrashDecoding.decode(umeng).needsUmengAddressFix)
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
}
