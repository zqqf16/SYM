import AppKit
import SwiftUI

/// Thin AppKit host for the SwiftUI settings UI.
/// (The app still uses NSApplicationMain / AppDelegate, so we embed SwiftUI
/// instead of declaring a SwiftUI `Settings` scene.)
final class PreferencesViewController: NSViewController {
    private let hostingController = NSHostingController(rootView: SYMSettingsRootView())

    init() {
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Settings", comment: "Settings")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 520))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.toolbar = nil
        view.window?.titleVisibility = .visible
        view.window?.title = NSLocalizedString("Settings", comment: "Settings")
    }
}

// MARK: - SwiftUI settings (system Form layout)

private enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general
    case editor
    case downloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return NSLocalizedString("General", comment: "Settings pane")
        case .editor: return NSLocalizedString("Editor", comment: "Settings pane")
        case .downloads: return NSLocalizedString("Downloads", comment: "Settings pane")
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .editor: return "textformat"
        case .downloads: return "arrow.down.circle"
        }
    }
}

struct SYMSettingsRootView: View {
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:
                    GeneralSettingsPane()
                case .editor:
                    EditorSettingsPane()
                case .downloads:
                    DownloadsSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 700, minHeight: 480)
    }
}

// MARK: - Panes

private struct GeneralSettingsPane: View {
    @State private var modelEntryCount = HardwareModelStore.shared.entryCount
    @State private var modelLastUpdated = HardwareModelStore.shared.lastUpdated
    @State private var isCheckingModels = false
    @State private var modelUpdateMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent(NSLocalizedString("Open Recent", comment: "")) {
                    Button(NSLocalizedString("Clear Menu", comment: "Clear recent documents")) {
                        NSDocumentController.shared.clearRecentDocuments(nil)
                    }
                }
                Text(NSLocalizedString("Remove all items from the Open Recent menu.", comment: "Settings help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(NSLocalizedString("Documents", comment: "Settings section"))
            }

            Section {
                LabeledContent(NSLocalizedString("Database", comment: "Hardware models database")) {
                    Text(modelDatabaseSummary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent(NSLocalizedString("Update", comment: "Hardware models update")) {
                    Button(NSLocalizedString("Check for Updates", comment: "Hardware models")) {
                        checkHardwareModels()
                    }
                    .disabled(isCheckingModels)
                }
                Text(NSLocalizedString("Download the latest Apple device identifier → name mapping used in the crash summary.", comment: "Settings help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isCheckingModels {
                    ProgressView()
                        .controlSize(.small)
                } else if let modelUpdateMessage {
                    Text(modelUpdateMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(NSLocalizedString("Hardware Models", comment: "Settings section"))
            }

            Section {
                LabeledContent("SYM") {
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(NSLocalizedString("About", comment: "Settings section"))
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .navigationTitle(SettingsPane.general.title)
        .onReceive(NotificationCenter.default.publisher(for: .hardwareModelsDidUpdate)) { _ in
            refreshModelStatus()
        }
    }

    private var modelDatabaseSummary: String {
        let count = String(format: NSLocalizedString("%lld models", comment: "Hardware model count"), Int64(modelEntryCount))
        if let modelLastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let date = formatter.string(from: modelLastUpdated)
            return String(format: NSLocalizedString("%@ · Updated %@", comment: "Hardware models status"), count, date)
        }
        return String(format: NSLocalizedString("%@ · Bundled", comment: "Hardware models using app bundle"), count)
    }

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return String(format: NSLocalizedString("Version %@ (%@)", comment: "App version"), version, build)
    }

    private func refreshModelStatus() {
        modelEntryCount = HardwareModelStore.shared.entryCount
        modelLastUpdated = HardwareModelStore.shared.lastUpdated
    }

    private func checkHardwareModels() {
        isCheckingModels = true
        modelUpdateMessage = nil
        Task {
            do {
                let outcome = try await HardwareModelStore.shared.checkForUpdates()
                await MainActor.run {
                    refreshModelStatus()
                    switch outcome {
                    case .updated(let count):
                        modelUpdateMessage = String(
                            format: NSLocalizedString("Updated to %lld models.", comment: "Hardware models update success"),
                            Int64(count)
                        )
                    case .unchanged(let count):
                        modelUpdateMessage = String(
                            format: NSLocalizedString("Already up to date (%lld models).", comment: "Hardware models unchanged"),
                            Int64(count)
                        )
                    }
                    isCheckingModels = false
                }
            } catch {
                await MainActor.run {
                    modelUpdateMessage = error.localizedDescription
                    isCheckingModels = false
                }
            }
        }
    }
}

private struct EditorSettingsPane: View {
    @AppStorage(String.showLineNumbersKey) private var showLineNumbers = true
    @AppStorage(String.showCrashSummaryKey) private var showCrashSummary = true
    @AppStorage(String.editorHighlightColorKey) private var highlightColor = Config.highlightColors[0]
    @AppStorage(String.editorFontNameKey) private var fontName = ""
    @AppStorage(String.editorFontSizeKey) private var fontSize = 12

    var body: some View {
        Form {
            Section {
                LabeledContent(NSLocalizedString("Font", comment: "")) {
                    Button(fontDisplayName) {
                        openFontPanel()
                    }
                }
                Text(NSLocalizedString("Font used for crash logs.", comment: "Settings help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent(NSLocalizedString("Size", comment: "Font size")) {
                    HStack(spacing: 8) {
                        Text("\(resolvedFontSize)")
                            .monospacedDigit()
                            .frame(minWidth: 24, alignment: .trailing)
                        Stepper("", value: fontSizeBinding, in: 10 ... 24)
                            .labelsHidden()
                    }
                }
                Text(NSLocalizedString("Point size of the editor font.", comment: "Settings help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent(NSLocalizedString("Highlight Color", comment: "")) {
                    Picker("", selection: highlightBinding) {
                        ForEach(Config.highlightColors, id: \.self) { code in
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(nsColor: NSColor(hexString: code) ?? .red))
                                    .frame(width: 28, height: 12)
                            }
                            .tag(code)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 72)
                }
                Text(NSLocalizedString("Color for app frames in the backtrace.", comment: "Settings help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(NSLocalizedString("Appearance", comment: "Settings section"))
            }

            Section {
                Toggle(NSLocalizedString("Show line numbers", comment: "Settings"), isOn: lineNumbersBinding)
                Toggle(NSLocalizedString("Show crash summary bar", comment: "Settings"), isOn: crashSummaryBinding)
            } header: {
                Text(NSLocalizedString("Display", comment: "Settings section"))
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .navigationTitle(SettingsPane.editor.title)
        .onAppear {
            // Seed AppStorage from Config defaults when keys are missing.
            if fontName.isEmpty {
                fontName = Config.editorFont.fontName
            }
            if fontSize <= 0 {
                fontSize = Int(Config.editorFont.pointSize)
            }
            if highlightColor.isEmpty {
                highlightColor = Config.highlightColor
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .configFontChanged)) { _ in
            fontName = Config.editorFont.fontName
            fontSize = Int(Config.editorFont.pointSize)
        }
    }

    private var resolvedFontSize: Int {
        fontSize > 0 ? fontSize : Int(Config.editorFont.pointSize)
    }

    private var fontDisplayName: String {
        let name = fontName.isEmpty ? Config.editorFont.fontName : fontName
        return NSFont(name: name, size: CGFloat(resolvedFontSize))?.displayName ?? name
    }

    private var fontSizeBinding: Binding<Int> {
        Binding(
            get: { resolvedFontSize },
            set: { newValue in
                fontSize = newValue
                let name = fontName.isEmpty ? Config.editorFont.fontName : fontName
                if let font = NSFont(name: name, size: CGFloat(newValue)) {
                    Config.editorFont = font
                } else {
                    Config.editorFont = .monospacedSystemFont(ofSize: CGFloat(newValue), weight: .regular)
                }
            }
        )
    }

    private var highlightBinding: Binding<String> {
        Binding(
            get: { highlightColor.isEmpty ? Config.highlightColor : highlightColor },
            set: { newValue in
                highlightColor = newValue
                Config.highlightColor = newValue
            }
        )
    }

    private var lineNumbersBinding: Binding<Bool> {
        Binding(
            get: { showLineNumbers },
            set: { newValue in
                showLineNumbers = newValue
                Config.showLineNumbers = newValue
            }
        )
    }

    private var crashSummaryBinding: Binding<Bool> {
        Binding(
            get: { showCrashSummary },
            set: { newValue in
                showCrashSummary = newValue
                Config.showCrashSummary = newValue
            }
        )
    }

    private func openFontPanel() {
        let manager = NSFontManager.shared
        manager.setSelectedFont(Config.editorFont, isMultiple: false)
        let panel = manager.fontPanel(true)
        panel?.setPanelFont(Config.editorFont, isMultiple: false)
        panel?.makeKeyAndOrderFront(nil)
        // Ensure font changes apply through Config.
        NSApp.sendAction(#selector(NSFontManager.orderFrontFontPanel(_:)), to: manager, from: nil)
        PreferencesFontChangeRelay.shared.installIfNeeded()
    }
}

private struct DownloadsSettingsPane: View {
    @State private var folderPath = Config.dsymDownloadDirectory

    var body: some View {
        Form {
            Section {
                LabeledContent(NSLocalizedString("Folder", comment: "Download folder")) {
                    HStack(spacing: 8) {
                        Text(folderPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 260, alignment: .trailing)
                        Button(NSLocalizedString("Choose…", comment: "Choose folder")) {
                            chooseFolder()
                        }
                    }
                }
                Text(NSLocalizedString("Where downloaded dSYM archives are stored.", comment: "Settings help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent(NSLocalizedString("Script", comment: "Download script")) {
                    Button(NSLocalizedString("Edit Download Script…", comment: "Settings")) {
                        (NSApp.delegate as? AppDelegate)?.showDownloadScript(nil)
                    }
                }
                Text(NSLocalizedString("Custom shell script used to fetch dSYMs.", comment: "Settings help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(NSLocalizedString("dSYM Downloads", comment: "Settings section"))
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .navigationTitle(SettingsPane.downloads.title)
        .onAppear {
            folderPath = Config.dsymDownloadDirectory
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: folderPath)
        if panel.runModal() == .OK, let url = panel.url {
            Config.dsymDownloadDirectory = url.path
            folderPath = url.path
        }
    }
}

// MARK: - Font panel → Config bridge

/// Receives NSFontManager changeFont: while the font panel is open.
private final class PreferencesFontChangeRelay: NSObject, NSFontChanging {
    static let shared = PreferencesFontChangeRelay()
    private var installed = false

    func installIfNeeded() {
        guard !installed else { return }
        installed = true
        // Keep a strong ref via shared; become font manager target when panel opens.
        NSFontManager.shared.target = self
    }

    func changeFont(_ sender: NSFontManager?) {
        guard let sender else { return }
        Config.editorFont = sender.convert(Config.editorFont)
    }
}
