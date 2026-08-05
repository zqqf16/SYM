import Cocoa
import SnapKit

class DownloadScriptViewController: NSViewController {
    private let textView = NSTextView()
    private let scrollView = NSScrollView()
    private let removeButton = NSButton()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.isRichText = false
        textView.allowsUndo = true
        scrollView.documentView = textView

        removeButton.title = NSLocalizedString("Remove Script", comment: "Delete configured download.sh")
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(didClickRemoveButton(_:))

        let doneButton = NSButton(
            title: NSLocalizedString("Done", comment: ""),
            target: self,
            action: #selector(didClickDoneButton(_:))
        )
        doneButton.bezelStyle = .rounded
        let cancelButton = NSButton(
            title: NSLocalizedString("Cancel", comment: ""),
            target: self,
            action: #selector(close(_:))
        )
        cancelButton.bezelStyle = .rounded

        view.addSubview(scrollView)
        view.addSubview(removeButton)
        view.addSubview(doneButton)
        view.addSubview(cancelButton)

        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(doneButton.snp.top).offset(-12)
        }
        removeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
        doneButton.snp.makeConstraints { make in
            make.trailing.equalTo(cancelButton.snp.leading).offset(-8)
            make.centerY.equalTo(cancelButton)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.font = NSFont(name: "Menlo", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = CGSize(width: 10, height: 10)
        Config.prepareDsymDownloadDirectory()
        reloadFromDisk()
    }

    /// Called every time the (cached) window is shown.
    func reloadFromDisk() {
        Config.sanitizeDownloadScriptFile()
        loadContent()
        updateRemoveButtonState()
    }

    @objc func didClickDoneButton(_ sender: Any) {
        let script = textView.string
        if Config.isDownloadScriptEmpty(script) {
            Config.removeDownloadScript()
            updateRemoveButtonState()
            close(sender)
            return
        }

        var toSave = script
        if !toSave.hasPrefix("#!") {
            toSave = "#!/bin/bash\n" + toSave
        }

        let url = Config.downloadScriptURL
        let directory = url.deletingLastPathComponent().path
        guard FileManager.default.createDirectory(directory) else {
            presentSaveError(NSLocalizedString(
                "Could not create the Application Support folder for download.sh.",
                comment: "Download script save error"
            ))
            return
        }

        do {
            try toSave.write(to: url, atomically: true, encoding: .utf8)
            _ = FileManager.default.chmod(url.path, permissions: 0o700)
            updateRemoveButtonState()
            close(sender)
        } catch {
            presentSaveError(error.localizedDescription)
        }
    }

    @objc func didClickRemoveButton(_: Any) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(
            "Remove Download Script?",
            comment: "Confirm deleting download.sh"
        )
        alert.informativeText = NSLocalizedString(
            "This deletes the configured download.sh. You can paste a new script later.",
            comment: "Confirm deleting download.sh detail"
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Remove Script", comment: "Delete configured download.sh"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        Config.removeDownloadScript()
        if let template = Self.localizedTemplateScript() {
            textView.string = template
        } else {
            textView.string = ""
        }
        updateRemoveButtonState()
    }

    @objc func close(_: Any) {
        view.window?.close()
    }

    func loadContent() {
        if let userImportedScript = try? String(contentsOf: Config.downloadScriptURL, encoding: .utf8),
           !Config.isDownloadScriptEmpty(userImportedScript)
        {
            textView.string = userImportedScript
            return
        }
        if let template = Self.localizedTemplateScript() {
            textView.string = template
        } else {
            textView.string = "#!/bin/bash\n\nexit 1\n"
        }
    }

    private func updateRemoveButtonState() {
        // Only enable when a real (non-stub) script is configured.
        removeButton.isEnabled = Config.isDownloadScriptConfigured()
    }

    private func presentSaveError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Could Not Save Script", comment: "Download script save failed")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    /// Prefer zh-Hans template when the app UI language is Chinese.
    private static func localizedTemplateScript() -> String? {
        let prefersChinese = Bundle.main.preferredLocalizations.contains { $0.hasPrefix("zh") }
        if prefersChinese,
           let url = Bundle.main.url(forResource: "template.zh-Hans", withExtension: "sh"),
           let text = try? String(contentsOf: url, encoding: .utf8),
           !text.isEmpty
        {
            return text
        }
        if let url = Bundle.main.url(forResource: "template", withExtension: "sh"),
           let text = try? String(contentsOf: url, encoding: .utf8),
           !text.isEmpty
        {
            return text
        }
        return nil
    }
}
