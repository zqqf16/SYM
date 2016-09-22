// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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

class SYMTests: XCTestCase {
    
    var umengDemo: String?

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "UmengDemo", ofType: "crash")!
        do {
            self.umengDemo = try String(contentsOfFile: path)
        } catch {
            XCTFail()
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCrashType() {
        let type = CrashType.fromContent(self.umengDemo!)
        XCTAssertEqual(type, CrashType.umeng)
    }
    
    func testCrashParser() {
        let crash = Parser.parse(self.umengDemo!)!
        XCTAssertEqual(crash.arch, "arm64")
        XCTAssertEqual(crash.appName, "DemoApp")
        XCTAssertNotNil(crash.images)

        let image = crash.images![crash.appName!]
        XCTAssertNotNil(image)
        XCTAssertEqual(image!.name, "DemoApp")
        XCTAssertEqual(image!.loadAddress, "0x0000000100000000")
        XCTAssertEqual(image!.uuid, "E5B0A378-6816-3D90-86FD-2AEF15894A85")
        XCTAssertNotNil(image!.backtrace)
        XCTAssertEqual(image!.backtrace?.count, 2)
        
        let frame = image!.backtrace![0];
        XCTAssertEqual(frame.address, "0x100b32844")
        XCTAssertEqual(frame.index, "3")
        XCTAssertEqual(frame.image, "DemoApp")
        XCTAssertEqual(frame.symbol, "UmengSignalHandler (in DemoApp) + 128")
    }
    
    func testParserPerformance() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            let _ = Parser.parse(self.umengDemo!)!
        }
    }
    
}
