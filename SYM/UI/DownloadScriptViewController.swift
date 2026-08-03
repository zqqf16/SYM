import Cocoa
import SnapKit

class DownloadScriptViewController: NSViewController {
    private let textView = NSTextView()
    private let scrollView = NSScrollView()

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
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView

        let doneButton = NSButton(title: NSLocalizedString("Done", comment: ""), target: self, action: #selector(didClickDoneButton(_:)))
        doneButton.bezelStyle = .rounded
        let cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(close(_:)))
        cancelButton.bezelStyle = .rounded

        view.addSubview(scrollView)
        view.addSubview(doneButton)
        view.addSubview(cancelButton)

        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(doneButton.snp.top).offset(-12)
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
        textView.font = NSFont(name: "Menlo", size: 11)!
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = CGSize(width: 10, height: 10)
        Config.prepareDsymDownloadDirectory()
        loadContent()
    }

    @objc func didClickDoneButton(_ sender: Any) {
        var script = textView.string
        if script.lengthOfBytes(using: .utf8) > 0, !script.hasPrefix("#!") {
            script = "#!/bin/bash\n" + script
        }
        do {
            try script.write(to: Config.downloadScriptURL, atomically: true, encoding: .utf8)
        } catch {}
        close(sender)
    }

    @objc func close(_: Any) {
        view.window?.close()
    }

    func loadContent() {
        if let userImportedScript = try? String(contentsOf: Config.downloadScriptURL, encoding: .utf8),
           userImportedScript.lengthOfBytes(using: .utf8) > 0
        {
            textView.string = userImportedScript
            return
        }
        if let url = Bundle.main.url(forResource: "template", withExtension: "sh"),
           let template = try? String(contentsOf: url, encoding: .utf8)
        {
            textView.string = template
        }
    }
}
