import Cocoa

class DeviceWindowController: NSWindowController, NSToolbarDelegate, FileBrowserNavigationDelegate {
    private static let toolbarIdentifier = NSToolbar.Identifier("DeviceWindowToolbar")

    private weak var fileBrowser: FileBrowserViewController?

    init() {
        let homeVC = DeviceHomeViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = homeVC
        window.title = NSLocalizedString("Devices", comment: "Devices")
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 960, height: 640))
        window.minSize = NSSize(width: 720, height: 420)
        window.center()
        super.init(window: window)

        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        windowFrameAutosaveName = "DeviceWindow"

        homeVC.onFileBrowserVisibilityChange = { [weak self] browser in
            self?.setFileBrowser(browser)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setFileBrowser(_ browser: FileBrowserViewController?) {
        fileBrowser?.navigationDelegate = nil
        fileBrowser = browser
        browser?.navigationDelegate = self
        rebuildToolbar()
        window?.toolbar?.validateVisibleItems()
    }

    func fileBrowserNavigationDidChange(_: FileBrowserViewController) {
        window?.toolbar?.validateVisibleItems()
    }

    private func rebuildToolbar() {
        guard let toolbar = window?.toolbar else { return }
        for index in stride(from: toolbar.items.count - 1, through: 0, by: -1) {
            toolbar.removeItem(at: index)
        }
        for (index, identifier) in currentItemIdentifiers.enumerated() {
            toolbar.insertItem(withItemIdentifier: identifier, at: index)
        }
        toolbar.validateVisibleItems()
    }

    private var currentItemIdentifiers: [NSToolbarItem.Identifier] {
        if fileBrowser != nil {
            return [
                .sidebarTrackingSeparator,
                .deviceFileBack,
                .deviceFileForward,
                .flexibleSpace,
            ]
        }
        return [.sidebarTrackingSeparator, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .sidebarTrackingSeparator,
            .deviceFileBack,
            .deviceFileForward,
            .flexibleSpace,
            .space,
        ]
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator, .flexibleSpace]
    }

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .deviceFileBack:
            let item = NSToolbarItem.systemSymbolItem(
                identifier: .deviceFileBack,
                symbolName: "chevron.backward",
                label: NSLocalizedString("Back", comment: ""),
                toolTip: NSLocalizedString("Back", comment: ""),
                target: fileBrowser,
                action: #selector(FileBrowserViewController.goBack(_:))
            )
            item.autovalidates = true
            return item
        case .deviceFileForward:
            let item = NSToolbarItem.systemSymbolItem(
                identifier: .deviceFileForward,
                symbolName: "chevron.forward",
                label: NSLocalizedString("Forward", comment: ""),
                toolTip: NSLocalizedString("Forward", comment: ""),
                target: fileBrowser,
                action: #selector(FileBrowserViewController.goForward(_:))
            )
            item.autovalidates = true
            return item
        default:
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }
}

extension NSToolbarItem.Identifier {
    static let deviceFileBack = NSToolbarItem.Identifier("DeviceFileBack")
    static let deviceFileForward = NSToolbarItem.Identifier("DeviceFileForward")
}
