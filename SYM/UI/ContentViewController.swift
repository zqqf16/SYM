import Cocoa
import Combine
import SnapKit

extension NSViewController {
    func windowController() -> MainWindowController? {
        view.window?.windowController as? MainWindowController
    }
}

class ContentViewController: NSViewController {
    private enum JumpPillPlacement: Equatable {
        case hidden
        case above
        case below
    }

    private let textView = TextView()
    private let scrollView = NSScrollView()
    private let gutterView = LineNumberGutterView()
    private let infoLabel = NSTextField(labelWithString: "")
    private let revealButton = NSButton(title: "", target: nil, action: nil)
    private let bottomBar = NSView()
    private let jumpPillButton = NSButton(title: "", target: nil, action: nil)

    private var font: NSFont = Config.editorFont
    private var cancellable: AnyCancellable?
    private var gutterWidthConstraint: Constraint?
    private var bottomBarHeightConstraint: Constraint?
    private var didAutoRevealCrashedThread = false
    private var jumpPillPlacement: JumpPillPlacement = .hidden

    var document: CrashDocument? {
        didSet {
            cancellable?.cancel()
            didAutoRevealCrashedThread = false
            jumpPillPlacement = .hidden
            jumpPillButton.isHidden = true
            guard let document else {
                updateJumpPillVisibility()
                return
            }

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

        configureRevealButton()
        configureJumpPillButton()

        bottomBar.addSubview(infoLabel)
        bottomBar.addSubview(revealButton)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentView.postsBoundsChangedNotifications = true

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
        view.addSubview(jumpPillButton)

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            bottomBarHeightConstraint = make.height.equalTo(0).constraint
        }
        revealButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
        }
        infoLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.lessThanOrEqualTo(revealButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        gutterView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
            gutterWidthConstraint = make.width.equalTo(LineNumberGutterView.defaultWidth).constraint
        }
        scrollView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.leading.equalTo(gutterView.snp.trailing)
            make.bottom.equalTo(bottomBar.snp.top)
        }
        jumpPillButton.snp.makeConstraints { make in
            make.centerX.equalTo(scrollView)
            make.top.equalTo(scrollView).offset(10)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        toggleBottomBar(false)
        setupTextView()
        applyLineNumbersPreference()
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configFontChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configFontDidChanged(_:)), name: .configColorChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(lineNumbersPreferenceDidChange(_:)), name: .configLineNumbersChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(crashSummaryPreferenceDidChange(_:)), name: .configCrashSummaryChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hardwareModelsDidUpdate(_:)), name: .hardwareModelsDidUpdate, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        syncTextViewWidthToClipView()
        gutterView.needsDisplay = true
        updateJumpPillVisibility()
    }

    private func configureRevealButton() {
        revealButton.title = NSLocalizedString("Crashed Thread", comment: "Summary bar jump control")
        revealButton.bezelStyle = .inline
        revealButton.controlSize = .small
        revealButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        revealButton.target = self
        revealButton.action = #selector(scrollToTarget(_:))
        revealButton.isHidden = true
        revealButton.toolTip = NSLocalizedString("Jump to the crashed thread", comment: "Summary bar tooltip")
    }

    private func configureJumpPillButton() {
        jumpPillButton.bezelStyle = .rounded
        jumpPillButton.controlSize = .small
        jumpPillButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        jumpPillButton.target = self
        jumpPillButton.action = #selector(scrollToTarget(_:))
        jumpPillButton.isHidden = true
        jumpPillButton.toolTip = NSLocalizedString("Jump to the crashed thread", comment: "Jump pill tooltip")
    }

    private func toggleBottomBar(_ show: Bool) {
        bottomBar.isHidden = !show
        bottomBarHeightConstraint?.update(offset: show ? 24 : 0)
        view.layoutSubtreeIfNeeded()
        syncTextViewWidthToClipView()
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
        let willAutoReveal = !didAutoRevealCrashedThread && crashInfo?.crashedThreadRange != nil
        maybeAutoRevealCrashedThread(crashInfo)
        if !willAutoReveal {
            updateJumpPillVisibility()
        }
    }

    private func updateHighlighting(_ crashInfo: CrashReport?) {
        guard let textStorage = textView.textStorage else {
            return
        }
        textStorage.beginEditing()
        textStorage.applyStyle(textFont: font)
        // Highlight ranges are computed against formattedContent; skip when the
        // editor still shows raw JSON (IPS / Keep) to avoid wrong offsets.
        let rangesMatchEditor = crashInfo.map { textView.string == $0.formattedContent } ?? false
        if rangesMatchEditor, let range = crashInfo?.crashedThreadRange {
            textStorage.highlightCrashedThread(at: range)
        }
        if rangesMatchEditor, let ranges = crashInfo?.appBacktraceRanges, !ranges.isEmpty {
            textStorage.highlight(at: ranges)
        }
        textStorage.endEditing()
    }

    private func updateSummary(_ crashInfo: CrashReport?) {
        guard Config.showCrashSummary, let info = crashInfo else {
            revealButton.isHidden = true
            toggleBottomBar(false)
            return
        }
        infoLabel.stringValue = infoString(fromCrash: info)
        let hasCrashedThread = info.crashedThreadRange != nil
        revealButton.isHidden = !hasCrashedThread
        infoLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            if hasCrashedThread {
                make.trailing.lessThanOrEqualTo(revealButton.snp.leading).offset(-8)
            } else {
                make.trailing.equalToSuperview().offset(-8)
            }
        }
        toggleBottomBar(true)
    }

    private func applyLineNumbersPreference() {
        let show = Config.showLineNumbers
        gutterView.isHidden = !show
        gutterWidthConstraint?.update(offset: show ? LineNumberGutterView.defaultWidth : 0)
        view.layoutSubtreeIfNeeded()
        syncTextViewWidthToClipView(forceLayout: true)
        gutterView.needsDisplay = true
    }

    private func maybeAutoRevealCrashedThread(_ crashInfo: CrashReport?) {
        guard !didAutoRevealCrashedThread,
              crashInfo?.crashedThreadRange != nil
        else {
            return
        }
        didAutoRevealCrashedThread = true
        DispatchQueue.main.async { [weak self] in
            self?.revealCrashedThread(animated: true)
        }
    }

    /// Scroll so the crashed thread sits near the top of the viewport (with a little context above).
    private func revealCrashedThread(animated: Bool) {
        guard let range = validCrashedThreadRange() else {
            return
        }

        syncTextViewWidthToClipView(forceLayout: true)
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect = rect.offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)

        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height
        let padding = min(48, max(16, visibleHeight * 0.12))
        let targetY = max(0, rect.minY - padding)
        let maxY = max(0, textView.bounds.height - visibleHeight)
        let origin = NSPoint(x: 0, y: min(targetY, maxY))

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.allowsImplicitAnimation = true
                clipView.animator().setBoundsOrigin(origin)
                scrollView.reflectScrolledClipView(clipView)
            } completionHandler: { [weak self] in
                self?.updateJumpPillVisibility()
            }
        } else {
            clipView.setBoundsOrigin(origin)
            scrollView.reflectScrolledClipView(clipView)
            updateJumpPillVisibility()
        }
    }

    private func validCrashedThreadRange() -> NSRange? {
        guard let crashInfo = document?.crashInfo,
              textView.string == crashInfo.formattedContent,
              let range = crashInfo.crashedThreadRange,
              range.location != NSNotFound,
              range.length > 0,
              NSMaxRange(range) <= (textView.string as NSString).length
        else {
            return nil
        }
        return range
    }

    private func crashedThreadDocumentRect() -> NSRect? {
        guard let range = validCrashedThreadRange(),
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return nil
        }
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect = rect.offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)
        return rect
    }

    private func updateJumpPillVisibility() {
        guard let rect = crashedThreadDocumentRect() else {
            setJumpPillPlacement(.hidden)
            return
        }

        let visible = textView.visibleRect.insetBy(dx: 0, dy: 8)
        if visible.intersects(rect) {
            setJumpPillPlacement(.hidden)
            return
        }

        if rect.maxY <= visible.minY {
            setJumpPillPlacement(.above)
        } else {
            setJumpPillPlacement(.below)
        }
    }

    private func setJumpPillPlacement(_ placement: JumpPillPlacement) {
        guard jumpPillPlacement != placement else {
            if placement != .hidden {
                refreshJumpPillTitle(for: placement)
            }
            return
        }
        jumpPillPlacement = placement

        switch placement {
        case .hidden:
            jumpPillButton.isHidden = true
        case .above, .below:
            refreshJumpPillTitle(for: placement)
            jumpPillButton.isHidden = false
            jumpPillButton.snp.remakeConstraints { make in
                make.centerX.equalTo(scrollView)
                if placement == .above {
                    make.top.equalTo(scrollView).offset(10)
                } else {
                    make.bottom.equalTo(scrollView).offset(-10)
                }
            }
        }
    }

    private func refreshJumpPillTitle(for placement: JumpPillPlacement) {
        switch placement {
        case .above:
            jumpPillButton.title = NSLocalizedString("↑ Crashed Thread", comment: "Jump pill when crash is above viewport")
        case .below:
            jumpPillButton.title = NSLocalizedString("↓ Crashed Thread", comment: "Jump pill when crash is below viewport")
        case .hidden:
            break
        }
    }

    @objc private func scrollViewDidScroll(_: Notification) {
        updateJumpPillVisibility()
    }

    @objc private func lineNumbersPreferenceDidChange(_: Notification) {
        applyLineNumbersPreference()
    }

    @objc private func crashSummaryPreferenceDidChange(_: Notification) {
        updateSummary(document?.crashInfo)
    }

    @objc private func hardwareModelsDidUpdate(_: Notification) {
        updateSummary(document?.crashInfo)
    }

    @objc func configFontDidChanged(_: Notification) {
        font = Config.editorFont
        update(crashInfo: document?.crashInfo)
    }

    @objc func symbolicate(_ sender: AnyObject?) {
        windowController()?.symbolicate(sender)
    }

    @IBAction func scrollToTarget(_: AnyObject?) {
        revealCrashedThread(animated: true)
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

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(scrollToTarget(_:)) {
            return validCrashedThreadRange() != nil
        }
        return true
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
