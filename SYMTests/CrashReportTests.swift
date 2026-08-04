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
        XCTAssertFalse(report.binaryImages.isEmpty)
        XCTAssertFalse(report.threads.isEmpty)
        XCTAssertTrue(report.formattedContent.contains("Binary Images:"))
        XCTAssertTrue(report.formattedContent.contains("Thread 1 Crashed:"))
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
}
