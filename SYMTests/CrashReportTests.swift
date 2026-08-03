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
