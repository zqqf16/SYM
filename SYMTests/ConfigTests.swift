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
import AppKit
import XCTest

class ConfigTests: XCTestCase {
    private var savedAutoSymbolicate: Any?
    private var savedWrap: Any?
    private var savedAppearance: Any?
    private var savedAppearanceObject: NSAppearance?

    override func setUpWithError() throws {
        savedAutoSymbolicate = UserDefaults.standard.object(forKey: .autoSymbolicateOnOpenKey)
        savedWrap = UserDefaults.standard.object(forKey: .wrapCrashTextKey)
        savedAppearance = UserDefaults.standard.object(forKey: .appearanceKey)
        savedAppearanceObject = NSApp.appearance
    }

    override func tearDownWithError() throws {
        restore(.autoSymbolicateOnOpenKey, savedAutoSymbolicate)
        restore(.wrapCrashTextKey, savedWrap)
        restore(.appearanceKey, savedAppearance)
        NSApp.appearance = savedAppearanceObject
    }

    private func restore(_ key: String, _ value: Any?) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func testEditorPreferenceDefaults() {
        UserDefaults.standard.removeObject(forKey: .autoSymbolicateOnOpenKey)
        UserDefaults.standard.removeObject(forKey: .wrapCrashTextKey)
        UserDefaults.standard.removeObject(forKey: .appearanceKey)

        XCTAssertFalse(Config.autoSymbolicateOnOpen)
        XCTAssertTrue(Config.wrapCrashText)
        XCTAssertEqual(Config.appearance, .system)
        XCTAssertEqual(Config.editorLineBreakMode, .byCharWrapping)
    }

    func testAutoSymbolicateAndWrapRoundTrip() {
        Config.autoSymbolicateOnOpen = true
        XCTAssertTrue(Config.autoSymbolicateOnOpen)
        Config.autoSymbolicateOnOpen = false
        XCTAssertFalse(Config.autoSymbolicateOnOpen)

        Config.wrapCrashText = false
        XCTAssertFalse(Config.wrapCrashText)
        XCTAssertEqual(Config.editorLineBreakMode, .byClipping)
        Config.wrapCrashText = true
        XCTAssertTrue(Config.wrapCrashText)
        XCTAssertEqual(Config.editorLineBreakMode, .byCharWrapping)
    }

    func testAppearanceRoundTrip() {
        Config.appearance = .dark
        XCTAssertEqual(Config.appearance, .dark)
        XCTAssertEqual(NSApp.appearance?.name, NSAppearance.Name.darkAqua)

        Config.appearance = .light
        XCTAssertEqual(Config.appearance, .light)
        XCTAssertEqual(NSApp.appearance?.name, NSAppearance.Name.aqua)

        Config.appearance = .system
        XCTAssertEqual(Config.appearance, .system)
        XCTAssertNil(NSApp.appearance)
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

    func testDownloadScriptEmptyTreatsTemplateStubAsMissing() {
        XCTAssertTrue(Config.isDownloadScriptEmpty(""))
        XCTAssertTrue(Config.isDownloadScriptEmpty("#!/bin/bash\n\n# only comments\n"))
        XCTAssertTrue(Config.isDownloadScriptEmpty("#!/bin/bash\n# docs\nexit 1\n"))
        XCTAssertTrue(Config.isDownloadScriptEmpty("#!/bin/bash\nexit 1"))

        XCTAssertFalse(Config.isDownloadScriptEmpty("#!/bin/bash\ncurl -O https://example.com/a.zip\n"))
        XCTAssertFalse(Config.isDownloadScriptEmpty("#!/bin/bash\nexit 1\necho hi\n"))
    }
}
