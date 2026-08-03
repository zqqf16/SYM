import Cocoa
import SnapKit

class PreferencesViewController: NSViewController {
    private let fontNameButton = NSButton(title: "", target: nil, action: nil)
    private let colorButton = NSPopUpButton()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))

        let fontLabel = NSTextField(labelWithString: NSLocalizedString("Font", comment: ""))
        let colorLabel = NSTextField(labelWithString: NSLocalizedString("Highlight Color", comment: ""))

        fontNameButton.bezelStyle = .rounded
        fontNameButton.target = self
        fontNameButton.action = #selector(showFontPanel(_:))

        colorButton.target = self
        colorButton.action = #selector(colorDidChanged(_:))

        view.addSubview(fontLabel)
        view.addSubview(fontNameButton)
        view.addSubview(colorLabel)
        view.addSubview(colorButton)

        fontLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(20)
        }
        fontNameButton.snp.makeConstraints { make in
            make.leading.equalTo(fontLabel.snp.trailing).offset(12)
            make.centerY.equalTo(fontLabel)
            make.width.greaterThanOrEqualTo(200)
        }
        colorLabel.snp.makeConstraints { make in
            make.top.equalTo(fontLabel.snp.bottom).offset(24)
            make.leading.equalTo(fontLabel)
        }
        colorButton.snp.makeConstraints { make in
            make.leading.equalTo(colorLabel.snp.trailing).offset(12)
            make.centerY.equalTo(colorLabel)
            make.width.equalTo(120)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let font = Config.editorFont
        fontNameButton.title = "\(font.fontName) \(Int(font.pointSize))"
        NotificationCenter.default.addObserver(self, selector: #selector(fontDidChanged(_:)), name: .configFontChanged, object: nil)
        setupColors()
    }

    private func setupColors() {
        colorButton.removeAllItems()
        let currentColor = Config.highlightColor
        for colorCode in Config.highlightColors {
            guard let color = NSColor(hexString: colorCode) else { continue }
            let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            menuItem.image = NSImage(color: color, size: NSSize(width: 20, height: 10))
            menuItem.toolTip = colorCode
            colorButton.menu?.addItem(menuItem)
            if colorCode == currentColor {
                colorButton.select(menuItem)
            }
        }
    }

    @objc func showFontPanel(_: AnyObject?) {
        let fontManager = NSFontManager.shared
        fontManager.setSelectedFont(Config.editorFont, isMultiple: false)
        let panel = fontManager.fontPanel(true)
        panel?.setPanelFont(Config.editorFont, isMultiple: false)
        panel?.reloadDefaultFontFamilies()
        panel?.makeKeyAndOrderFront(self)
    }

    @objc func fontDidChanged(_: Notification?) {
        let font = Config.editorFont
        fontNameButton.title = "\(font.fontName) \(Int(font.pointSize))"
    }

    @objc func colorDidChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
              let index = sender.menu?.index(of: selectedItem)
        else { return }
        Config.highlightColor = Config.highlightColors[index]
    }
}

extension PreferencesViewController: NSFontChanging {
    func changeFont(_ sender: NSFontManager?) {
        if let font = sender?.convert(Config.editorFont) {
            Config.editorFont = font
        }
    }
}
