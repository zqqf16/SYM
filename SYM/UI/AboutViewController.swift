import Cocoa
import SnapKit

class AboutWindow: BaseWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        titlebarAppearsTransparent = true
        titleVisibility = .visible
    }
}

class AboutViewController: NSViewController {
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "SYM")
    private let versionField = NSTextField(labelWithString: "")
    private let copyrightField = NSTextField(wrappingLabelWithString: "")

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 280))

        nameField.font = .boldSystemFont(ofSize: 18)
        nameField.alignment = .center
        versionField.alignment = .center
        copyrightField.alignment = .center
        copyrightField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let websiteButton = NSButton(title: "Website", target: self, action: #selector(gotoWebsite(sender:)))
        websiteButton.bezelStyle = .rounded
        let githubButton = NSButton(title: "GitHub", target: self, action: #selector(gotoGithub(_:)))
        githubButton.bezelStyle = .rounded

        view.addSubview(iconView)
        view.addSubview(nameField)
        view.addSubview(versionField)
        view.addSubview(copyrightField)
        view.addSubview(websiteButton)
        view.addSubview(githubButton)

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(64)
        }
        nameField.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        versionField.snp.makeConstraints { make in
            make.top.equalTo(nameField.snp.bottom).offset(4)
            make.leading.trailing.equalTo(nameField)
        }
        copyrightField.snp.makeConstraints { make in
            make.top.equalTo(versionField.snp.bottom).offset(8)
            make.leading.trailing.equalTo(nameField)
        }
        websiteButton.snp.makeConstraints { make in
            make.top.equalTo(copyrightField.snp.bottom).offset(16)
            make.trailing.equalTo(view.snp.centerX).offset(-6)
        }
        githubButton.snp.makeConstraints { make in
            make.centerY.equalTo(websiteButton)
            make.leading.equalTo(view.snp.centerX).offset(6)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        iconView.image = NSApp.applicationIconImage
        if let infoDict = Bundle.main.infoDictionary {
            let shortVersion = infoDict["CFBundleShortVersionString"] as? String ?? ""
            let buildVersion = infoDict["CFBundleVersion"] as? String ?? ""
            versionField.stringValue = "\(shortVersion) (\(buildVersion))"
            copyrightField.stringValue = infoDict["NSHumanReadableCopyright"] as? String ?? ""
        }
    }

    @objc func gotoWebsite(sender _: AnyObject) {
        if let url = URL(string: "https://zorro.im?utm_source=sym&utm_medium=referral") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func gotoGithub(_: AnyObject) {
        if let url = URL(string: "https://github.com/zqqf16/SYM") {
            NSWorkspace.shared.open(url)
        }
    }
}
