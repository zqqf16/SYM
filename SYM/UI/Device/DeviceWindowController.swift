import Cocoa

class DeviceWindowController: NSWindowController {
    init() {
        let homeVC = DeviceHomeViewController()
        let window = NSWindow(contentViewController: homeVC)
        window.title = NSLocalizedString("Devices", comment: "Devices")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 600))
        window.center()
        super.init(window: window)
        windowFrameAutosaveName = "DeviceWindow"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
