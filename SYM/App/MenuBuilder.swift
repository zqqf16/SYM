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

enum MenuBuilder {
    private static func L(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    @discardableResult
    static func installMainMenu(appDelegate: AppDelegate) -> NSMenu {
        let mainMenu = NSMenu()

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SYM"
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let about = appMenu.addItem(
            withTitle: String(format: L("About %@"), appName),
            action: #selector(AppDelegate.showAboutPanel(_:)),
            keyEquivalent: ""
        )
        about.target = appDelegate

        appMenu.addItem(.separator())

        let preferences = appMenu.addItem(
            withTitle: L("Settings…"),
            action: #selector(AppDelegate.showPreferences(_:)),
            keyEquivalent: ","
        )
        preferences.target = appDelegate

        appMenu.addItem(.separator())

        let servicesItem = appMenu.addItem(withTitle: L("Services"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: L("Services"))
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())

        let hide = appMenu.addItem(
            withTitle: String(format: L("Hide %@"), appName),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hide.target = NSApp

        let hideOthers = appMenu.addItem(
            withTitle: L("Hide Others"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        hideOthers.target = NSApp

        let showAll = appMenu.addItem(
            withTitle: L("Show All"),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAll.target = NSApp

        appMenu.addItem(.separator())

        let quit = appMenu.addItem(
            withTitle: String(format: L("Quit %@"), appName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp

        let fileMenuItem = NSMenuItem(title: L("File"), action: nil, keyEquivalent: "")
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: L("File"))
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: L("New"), action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: L("Open…"), action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")

        let openRecentItem = fileMenu.addItem(withTitle: L("Open Recent"), action: nil, keyEquivalent: "")
        let openRecentMenu = NSMenu(title: L("Open Recent"))
        openRecentItem.submenu = openRecentMenu
        openRecentMenu.addItem(
            withTitle: L("Clear Menu"),
            action: #selector(NSDocumentController.clearRecentDocuments(_:)),
            keyEquivalent: ""
        )
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: L("Save…"), action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: L("Save As…"), action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        fileMenu.addItem(withTitle: L("Revert to Saved"), action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")

        let editMenuItem = NSMenuItem(title: L("Edit"), action: nil, keyEquivalent: "")
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: L("Edit"))
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: L("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("Delete"), action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: L("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())

        let findItem = editMenu.addItem(withTitle: L("Find"), action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: L("Find"))
        findItem.submenu = findMenu

        func addFinderItem(title: String, action: NSTextFinder.Action, key: String, modifiers: NSEvent.ModifierFlags = .command) {
            let item = findMenu.addItem(
                withTitle: title,
                action: #selector(NSResponder.performTextFinderAction(_:)),
                keyEquivalent: key
            )
            item.tag = action.rawValue
            item.keyEquivalentModifierMask = modifiers
        }

        addFinderItem(title: L("Find…"), action: .showFindInterface, key: "f")
        addFinderItem(title: L("Find and Replace…"), action: .showReplaceInterface, key: "f", modifiers: [.command, .option])
        addFinderItem(title: L("Find Next"), action: .nextMatch, key: "g")
        addFinderItem(title: L("Find Previous"), action: .previousMatch, key: "G")
        addFinderItem(title: L("Use Selection for Find"), action: .setSearchString, key: "e")
        findMenu.addItem(
            withTitle: L("Jump to Selection"),
            action: #selector(NSResponder.centerSelectionInVisibleArea(_:)),
            keyEquivalent: "j"
        )

        let symbolMenuItem = NSMenuItem(title: L("Symbol"), action: nil, keyEquivalent: "")
        mainMenu.addItem(symbolMenuItem)
        let symbolMenu = NSMenu(title: L("Symbol"))
        symbolMenuItem.submenu = symbolMenu
        symbolMenu.addItem(withTitle: L("Symbolicate"), action: #selector(MainWindowController.symbolicate(_:)), keyEquivalent: "r")
        symbolMenu.addItem(.separator())
        let downloadScript = symbolMenu.addItem(
            withTitle: L("Download Script…"),
            action: #selector(AppDelegate.showDownloadScript(_:)),
            keyEquivalent: ""
        )
        downloadScript.target = appDelegate

        let viewMenuItem = NSMenuItem(title: L("View"), action: nil, keyEquivalent: "")
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: L("View"))
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: L("Zoom In"), action: #selector(ContentViewController.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: L("Zoom Out"), action: #selector(ContentViewController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: L("Scroll to Crashed Thread"), action: #selector(ContentViewController.scrollToTarget(_:)), keyEquivalent: "")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: L("Show Toolbar"), action: #selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: L("Customize Toolbar…"), action: #selector(NSWindow.runToolbarCustomizationPalette(_:)), keyEquivalent: "")

        let windowMenuItem = NSMenuItem(title: L("Window"), action: nil, keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: L("Window"))
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: L("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: L("Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        let devices = windowMenu.addItem(
            withTitle: L("Devices"),
            action: #selector(AppDelegate.showDevices(_:)),
            keyEquivalent: "d"
        )
        devices.target = appDelegate
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L("Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        let helpMenuItem = NSMenuItem(title: L("Help"), action: nil, keyEquivalent: "")
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: L("Help"))
        helpMenuItem.submenu = helpMenu
        helpMenu.addItem(
            withTitle: String(format: L("%@ Help"), appName),
            action: #selector(NSApplication.showHelp(_:)),
            keyEquivalent: "?"
        )
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
        return mainMenu
    }
}
