import Cocoa
import Combine
import SnapKit

extension NSViewController {
    func windowController() -> MainWindowController? {
        view.window?.windowController as? MainWindowController
    }
}

class ContentViewController: NSViewController {
    private let textView = TextView()
    private let scrollView = NSScrollView()
    private let infoLabel = NSTextField(labelWithString: "")
    private let bottomBar = NSView()

    private var font: NSFont = Config.editorFont
    private var cancellable: AnyCancellable?

    var document: CrashDocument? {
        didSet {
            cancellable?.cancel()
            guard let document else { return }

            textView.layoutManager?.replaceTextStorage(document.textStorage)
            cancellable = document.$crashInfo
                .receive(on: DispatchQueue.main)
                .sink { [weak self] crashInfo in
                    self?.update(crashInfo: crashInfo)
                }
            update(crashInfo: document.crashInfo)
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        bottomBar.wantsLayer = true
        infoLabel.lineBreakMode = .byTruncatingTail
        infoLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        bottomBar.addSubview(infoLabel)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        view.addSubview(scrollView)
        view.addSubview(bottomBar)

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(24)
        }
        infoLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        toggleBottomBar(false)
        setupTextView()
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configFontChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configColorChanged, object: nil)
    }

    private func toggleBottomBar(_ show: Bool) {
        bottomBar.isHidden = !show
    }

    private func setupTextView() {
        textView.font = font
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.textContainerInset = CGSize(width: 0, height: 4)
        textView.allowsUndo = true
        textView.delegate = self
        textView.lnv_setUpLineNumberView()
        textView.layoutManager?.allowsNonContiguousLayout = false
    }

    private func infoString(fromCrash crash: CrashReport) -> String {
        var info = ""
        var divider = ""
        if let device = crash.device {
            info += "🏷 " + modelToName(device)
            divider = " - "
        }
        if let osVersion = crash.osVersion {
            info += "\(divider)\(osVersion)"
        }
        if let appVersion = crash.appVersion {
            info += "\(divider)\(appVersion)"
        }
        return info
    }

    func update(crashInfo: CrashReport?) {
        updateHighlighting(crashInfo)
        updateSummary(crashInfo)
    }

    private func updateHighlighting(_ crashInfo: CrashReport?) {
        guard let textStorage = textView.textStorage,
              let ranges = crashInfo?.appBacktraceRanges
        else {
            return
        }
        textStorage.beginEditing()
        textStorage.font = font
        textStorage.highlight(at: ranges)
        textStorage.endEditing()
    }

    private func updateSummary(_ crashInfo: CrashReport?) {
        guard let info = crashInfo else {
            toggleBottomBar(false)
            return
        }
        infoLabel.stringValue = infoString(fromCrash: info)
        toggleBottomBar(true)
    }

    @objc func configFontDidChanged(_: Notification) {
        font = Config.editorFont
        update(crashInfo: document?.crashInfo)
    }

    @objc func symbolicate(_ sender: AnyObject?) {
        windowController()?.symbolicate(sender)
    }

    @IBAction func scrollToTarget(_: AnyObject?) {
        guard let crashInfo = document?.crashInfo, let range = crashInfo.crashedThreadRange else {
            return
        }
        textView.scrollRangeToVisible(range)
        textView.highlight(range)
    }

    @IBAction func zoomIn(_: AnyObject?) {
        let size = min(font.pointSize + 1, 20.0)
        font = NSFont(name: font.fontName, size: size)!
        update(crashInfo: document?.crashInfo)
    }

    @IBAction func zoomOut(_: AnyObject?) {
        let size = max(font.pointSize - 1, 10.0)
        font = NSFont(name: font.fontName, size: size)!
        update(crashInfo: document?.crashInfo)
    }
}

extension ContentViewController: NSTextViewDelegate {
    func textView(_: NSTextView, menu _: NSMenu, for _: NSEvent, at _: Int) -> NSMenu? {
        let menu = NSMenu(title: "dSYM")
        let showItem = NSMenuItem(title: "Symbolicate", action: #selector(symbolicate(_:)), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.allowsContextMenuPlugIns = true
        return menu
    }
}
