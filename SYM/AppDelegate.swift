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

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var preferencesWindow: NSWindow?
    private var downloadScriptWindow: NSWindow?
    private var aboutWindow: NSWindow?
    var deviceWindowController: DeviceWindowController?

    override init() {
        super.init()
        _ = DocumentController()
    }

    func applicationWillFinishLaunching(_: Notification) {
        _ = NSApp.setActivationPolicy(.regular)
        // Participate in system “Prefer tabs when opening documents”.
        NSWindow.allowsAutomaticWindowTabbing = true
        // MainMenu.xib (NSMainNibFile) should already be loaded; rebuild if missing.
        ensureMainMenu()
    }

    func applicationDidFinishLaunching(_: Notification) {
        ensureMainMenu()
        MDDeviceMonitor.shared().start()
        NSApp.activate(ignoringOtherApps: true)

        if NSDocumentController.shared.documents.isEmpty {
            _ = try? NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
        }
    }

    private func ensureMainMenu() {
        if NSApp.mainMenu == nil || NSApp.mainMenu?.numberOfItems == 0 {
            MenuBuilder.installMainMenu(appDelegate: self)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {}

    @objc func showPreferences(_: Any?) {
        if preferencesWindow == nil {
            let vc = PreferencesViewController()
            let window = NSWindow(contentViewController: vc)
            window.title = NSLocalizedString("Settings", comment: "Settings")
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.setContentSize(NSSize(width: 760, height: 520))
            window.minSize = NSSize(width: 640, height: 420)
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showDownloadScript(_: Any?) {
        if downloadScriptWindow == nil {
            let vc = DownloadScriptViewController()
            let window = NSWindow(contentViewController: vc)
            window.title = NSLocalizedString("Download Script", comment: "Download Script")
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 640, height: 480))
            window.center()
            downloadScriptWindow = window
        }
        // Window is reused — reload from disk every time so edits/saves stick
        // and the Remove button reflects whether download.sh exists.
        if let vc = downloadScriptWindow?.contentViewController as? DownloadScriptViewController {
            vc.reloadFromDisk()
        }
        downloadScriptWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAboutPanel(_: Any?) {
        if aboutWindow == nil {
            let vc = AboutViewController()
            let window = AboutWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.contentViewController = vc
            window.title = NSLocalizedString("About SYM", comment: "About")
            window.setContentSize(NSSize(width: 360, height: 260))
            window.center()
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showDevices(_: Any?) {
        if deviceWindowController == nil {
            deviceWindowController = DeviceWindowController()
        }
        deviceWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
