// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
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


import XCTest
@testable import SYM

class ParserTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func crashContent(fromFile file: String, ofType ftype: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: file, ofType: ftype)!
        return try! String(contentsOfFile: path)
    }
    
    func testRE() {
        let content: String = """
            E5B0A378-6816-3D90-86FD-2AEF15894A85
            E5B0A378-6816-3D90-86FD-2AEF15894A85
            E5B0A378-6816-3D90-86FD-2AEF15894A85
            E5B0A378-6816-3D90-86FD-2AEF15894A85
            asdfasdfasdfa
            asaewwqs
        """

        let uuid = RE.uuid.findAll(content)
        XCTAssertEqual(uuid?.count, 4)
    }

    func testAppleParser() {
        let content = self.crashContent(fromFile: "AppleDemo", ofType: "ips")
        
        let parser = AppleParser()
        let crash: Crash! = parser.parse(content)

        XCTAssertNotNil(crash)

        XCTAssertEqual(crash.uuid, "42fd89f730be3ac5a40a4c1a99438dfb".uuidFormat())
        XCTAssertEqual(crash.appName, "demo")
        XCTAssertEqual(crash.device, "iPhone9,2")
        XCTAssertEqual(crash.arch, "arm64")
        XCTAssertEqual(crash.osVersion, "iPhone OS 10.1.1 (14B100)")
        XCTAssertEqual(crash.appVersion, "3.5.5.2 (3.5.5)")
        XCTAssertEqual(crash.bundleID, "im.zorro.demo")
        XCTAssertEqual(crash.symbolicateMethod, .symbolicatecrash)

        let embedded = crash.embeddedBinaries
        XCTAssertEqual(embedded.count, 16)
        
        XCTAssertTrue(crash.appBacktraceRanges.count > 0)
        XCTAssertNotNil(crash.crashedThreadRange)
    }
    
    func testUmengParser() {
        let content = self.crashContent(fromFile: "UmengDemo", ofType: "crash")
        let parser = UmengParser()
        let crash: Crash! = parser.parse(content)
        
        XCTAssertNotNil(crash)

        XCTAssertEqual(crash.appName, "DemoApp")
        XCTAssertNil(crash.device)
        XCTAssertEqual(crash.uuid, "E5B0A378-6816-3D90-86FD-2AEF15894A85")
        
        XCTAssertTrue(crash.appBacktraceRanges.count > 0)
        
        let binary: Binary! = crash.binaryImages.first
        XCTAssertNotNil(binary)
        XCTAssertEqual(binary.name, "DemoApp")
        XCTAssertEqual(binary.loadAddress, "0x0000000100000000")

    }
}
