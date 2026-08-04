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
    private let githubButton = NSButton(title: "GitHub", target: nil, action: nil)

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 260))

        nameField.font = .boldSystemFont(ofSize: 18)
        nameField.alignment = .center
        versionField.alignment = .center
        copyrightField.alignment = .center
        copyrightField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        githubButton.target = self
        githubButton.action = #selector(gotoGithub(_:))
        githubButton.bezelStyle = .rounded

        let content = NSView()
        view.addSubview(content)
        content.addSubview(iconView)
        content.addSubview(nameField)
        content.addSubview(versionField)
        content.addSubview(copyrightField)
        content.addSubview(githubButton)

        content.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview()
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
        githubButton.snp.makeConstraints { make in
            make.top.equalTo(copyrightField.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
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

    @objc func gotoGithub(_: AnyObject) {
        if let url = URL(string: "https://github.com/zqqf16/SYM") {
            NSWorkspace.shared.open(url)
        }
    }
}
