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
    private let gutterView = LineNumberGutterView()
    private let infoLabel = NSTextField(labelWithString: "")
    private let bottomBar = NSView()

    private var font: NSFont = Config.editorFont
    private var cancellable: AnyCancellable?

    var document: CrashDocument? {
        didSet {
            cancellable?.cancel()
            guard let document else { return }

            textView.layoutManager?.replaceTextStorage(document.textStorage)
            syncTextViewWidthToClipView(forceLayout: true)
            textView.needsDisplay = true
            gutterView.needsDisplay = true

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
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.automaticallyAdjustsContentInsets = false

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor

        scrollView.documentView = textView

        view.addSubview(gutterView)
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
        gutterView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
            make.width.equalTo(LineNumberGutterView.defaultWidth)
        }
        scrollView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.leading.equalTo(gutterView.snp.trailing)
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

    override func viewDidLayout() {
        super.viewDidLayout()
        syncTextViewWidthToClipView()
        gutterView.needsDisplay = true
    }

    private func toggleBottomBar(_ show: Bool) {
        bottomBar.isHidden = !show
    }

    private func setupTextView() {
        textView.font = font
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.importsGraphics = false
        textView.textContainerInset = CGSize(width: 5, height: 4)
        textView.allowsUndo = true
        textView.delegate = self
        textView.layoutManager?.allowsNonContiguousLayout = false
        textView.usesFindBar = true
        gutterView.attach(textView: textView, scrollView: scrollView)
        syncTextViewWidthToClipView(forceLayout: true)
    }

    /// Keep the text container wrapped to the clip-view width.
    private func syncTextViewWidthToClipView(forceLayout: Bool = false) {
        let clipView = scrollView.contentView
        let width = max(clipView.bounds.width, 1)

        var frame = textView.frame
        var frameChanged = false
        if abs(frame.width - width) > 0.5 {
            frame.size.width = width
            frameChanged = true
        }
        if frame.origin.x != 0 {
            frame.origin.x = 0
            frameChanged = true
        }
        if frameChanged {
            textView.frame = frame
        }

        let container = textView.textContainer
        let widthChanged = container?.containerSize.width != width
        if widthChanged {
            container?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
        if (forceLayout || widthChanged), let container {
            textView.layoutManager?.ensureLayout(for: container)
        }

        if clipView.bounds.origin.x != 0 {
            clipView.scroll(to: NSPoint(x: 0, y: clipView.bounds.origin.y))
            scrollView.reflectScrolledClipView(clipView)
        }
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
        gutterView.needsDisplay = true
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
