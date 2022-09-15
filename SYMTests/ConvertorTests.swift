//
//  ConvertorTests.swift
//  SYMTests
//
//  Created by 张全全 on 2022/3/18.
//  Copyright © 2022 zqqf16. All rights reserved.
//

@testable import SYM
import XCTest

class ConvertorTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func loadFile() -> String {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "AppleJson", ofType: "ips")!
        return try! String(contentsOfFile: path)
    }

    func testMatching() throws {
        let content = loadFile()
        XCTAssertTrue(AppleJsonConvertor.match(content))
    }

    func testConvertor() throws {
        let content = loadFile()
        let convertor = AppleJsonConvertor()
        let converted = convertor.convert(content)
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "AppleConverted", ofType: "log")!
        let target = try! String(contentsOfFile: path)

        // XCTAssertEqual(converted, target)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
