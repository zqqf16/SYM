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

@testable import SYM
import XCTest

class ConfigTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDownloadDir() throws {
        UserDefaults.standard.removeObject(forKey: .downloadFolderKey)
        Config.prepareDsymDownloadDirectory()

        // path init
        let path = Config.dsymDownloadDirectory
        let userDefault = UserDefaults.standard.string(forKey: .downloadFolderKey)
        let target = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
        XCTAssertEqual(path, target)
        XCTAssertEqual(userDefault, target)

        // directory creation
        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)

        // relative path
        let home = NSHomeDirectory()
        let relative = target.replacingOccurrences(of: home, with: "~")
        UserDefaults.standard.set(relative, forKey: .downloadFolderKey)
        let newPath = Config.dsymDownloadDirectory
        XCTAssertEqual(newPath, target)
    }
}
