// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Cocoa
import Combine

class MainWindowController: NSWindowController, NSToolbarDelegate {
    private let dsymButton = DsymToolbarButton()
    private let downloadItem: DownloadToolbarItem
    private var deviceToolbarItem: NSToolbarItem?
    private let indicator = NSProgressIndicator()
    private let toolbar = NSToolbar(identifier: "MainToolbar")
    private var didConfigure = false

    var isSymbolicating: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.isSymbolicating {
                    self.indicator.startAnimation(nil)
                    self.indicator.isHidden = false
                } else {
                    self.indicator.stopAnimation(nil)
                    self.indicator.isHidden = true
                }
            }
        }
    }

    private var crashCancellable = Set<AnyCancellable>()
    private var dsymManager = DsymManager()
    private weak var dsymViewController: DsymViewController?
    private var downloaderCancellable: AnyCancellable?
    private var downloadTask: DsymDownloadTask?
    private weak var downloadStatusViewController: DownloadStatusViewController?

    var crashContentViewController: ContentViewController? {
        contentViewController as? ContentViewController
    }

    var crashDocument: CrashDocument? {
        document as? CrashDocument
    }

    init() {
        downloadItem = DownloadToolbarItem(itemIdentifier: .download)

        let contentVC = ContentViewController()
        let window = NSWindow(contentViewController: contentVC)
        window.title = "SYM"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 960, height: 680))
        window.minSize = NSSize(width: 560, height: 360)
        window.center()
        window.toolbarStyle = .unified
        // Same identifier for all crash-document windows so AppKit can tab them
        // together according to System Settings → Prefer tabs when opening documents.
        window.tabbingIdentifier = Self.documentTabbingIdentifier
        window.tabbingMode = .automatic

        super.init(window: window)

        // Programmatic windows do not call windowDidLoad — configure here.
        configureToolbar()
        configureBindings()
    }

    /// Shared by every main crash editor window.
    static let documentTabbingIdentifier = "im.zorro.SYM.CrashDocument"

    /// Tab-bar "+" creates another untitled document (respects user tabbing preference).
    @objc
    override func newWindowForTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureToolbar() {
        guard !didConfigure else { return }
        didConfigure = true

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window?.toolbar = toolbar
    }

    private func configureBindings() {
        windowFrameAutosaveName = "MainWindow"
        dsymButton.dsymManager = dsymManager

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDeviceButton(_:)),
            name: NSNotification.Name.MDDeviceMonitor,
            object: nil
        )
        updateDeviceEnabled(MDDeviceMonitor.shared().deviceConnected)

        downloaderCancellable = DsymDownloader.shared.$tasks
            .receive(on: DispatchQueue.main)
            .map { [weak self] tasks -> DsymDownloadTask? in
                if let uuid = self?.crashDocument?.crashInfo?.uuid {
                    return tasks[uuid]
                }
                return nil
            }
            .sink { [weak self] task in
                self?.bind(task: task)
            }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var document: AnyObject? {
        didSet {
            crashCancellable.forEach { $0.cancel() }
            crashCancellable.removeAll()

            guard let document = document as? CrashDocument else {
                crashContentViewController?.document = nil
                return
            }
            crashContentViewController?.document = document

            document.$crashInfo
                .receive(on: DispatchQueue.main)
                .sink { [weak self] crashInfo in
                    if let crash = crashInfo {
                        self?.dsymManager.update(crash)
                    } else {
                        self?.dsymManager.update(nil)
                    }
                }
                .store(in: &crashCancellable)

            document.$isSymbolicating
                .receive(on: DispatchQueue.main)
                .assign(to: \.isSymbolicating, on: self)
                .store(in: &crashCancellable)
        }
    }

    @objc func updateDeviceButton(_: Notification) {
        updateDeviceEnabled(MDDeviceMonitor.shared().deviceConnected)
    }

    private func updateDeviceEnabled(_ enabled: Bool) {
        deviceToolbarItem?.isEnabled = enabled
    }

    @objc func symbolicate(_: AnyObject?) {
        let content = crashDocument?.textStorage.string ?? ""
        if content.strip().isEmpty {
            return
        }
        isSymbolicating = true
        crashDocument?.symbolicate(withDsymPaths: dsymManager.dsymPathMap)
    }

    @objc func showDsymInfo(_: Any?) {
        guard dsymManager.crash != nil else { return }
        let vc = DsymViewController()
        vc.dsymManager = dsymManager
        vc.bind(task: downloadTask)
        dsymViewController = vc
        contentViewController?.presentAsSheet(vc)
    }

    @objc func showDevices(_: Any?) {
        (NSApp.delegate as? AppDelegate)?.showDevices(nil)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .symbolicate:
            return .systemSymbolItem(
                identifier: itemIdentifier,
                symbolName: "wand.and.stars",
                label: "Symbolicate",
                toolTip: NSLocalizedString("Symbolicate crash log", comment: ""),
                target: self,
                action: #selector(symbolicate(_:))
            )

        case .dsym:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "dSYM"
            item.paletteLabel = "dSYM"
            item.toolTip = NSLocalizedString("dSYM files", comment: "")
            item.isBordered = true
            dsymButton.target = self
            dsymButton.action = #selector(showDsymInfo(_:))
            item.view = dsymButton
            return item

        case .download:
            downloadItem.target = self
            downloadItem.action = #selector(toggleDownloadPopover(_:))
            return downloadItem

        case .device:
            let item = NSToolbarItem.systemSymbolItem(
                identifier: itemIdentifier,
                symbolName: "iphone",
                label: "Device",
                toolTip: NSLocalizedString("Connected devices", comment: ""),
                target: self,
                action: #selector(showDevices(_:))
            )
            item.isEnabled = MDDeviceMonitor.shared().deviceConnected
            deviceToolbarItem = item
            return item

        case .progress:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Progress"
            item.paletteLabel = "Progress"
            indicator.style = .spinning
            indicator.controlSize = .small
            indicator.isDisplayedWhenStopped = false
            indicator.isHidden = true
            item.view = indicator
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.symbolicate, .flexibleSpace, .dsym, .download, .device, .progress]
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.symbolicate, .dsym, .download, .device, .progress, .flexibleSpace, .space]
    }

    @objc private func toggleDownloadPopover(_ sender: Any?) {
        let shouldStart: Bool = {
            guard let status = downloadTask?.status else { return true }
            switch status {
            case .canceled, .failed, .success:
                return true
            case .waiting, .running:
                return false
            }
        }()
        if shouldStart {
            startDownloading()
        }

        if downloadStatusViewController == nil {
            let vc = DownloadStatusViewController()
            vc.delegate = self
            downloadStatusViewController = vc
        }
        guard let vc = downloadStatusViewController else { return }
        vc.bind(task: downloadTask)

        let anchorView: NSView?
        if let button = sender as? NSView {
            anchorView = button
        } else if let item = sender as? NSToolbarItem {
            anchorView = item.view
        } else {
            anchorView = downloadItem.view
        }

        if let view = anchorView {
            contentViewController?.present(
                vc,
                asPopoverRelativeTo: view.bounds,
                of: view,
                preferredEdge: .maxY,
                behavior: .transient
            )
        }
    }
}

extension MainWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .symbolicate:
            let content = crashDocument?.textStorage.string ?? ""
            return !content.strip().isEmpty
        case .dsym:
            return dsymManager.crash != nil
        case .download:
            return dsymManager.crash != nil
        case .device:
            return MDDeviceMonitor.shared().deviceConnected
        default:
            return true
        }
    }
}

extension MainWindowController: DownloadStatusViewControllerDelegate {
    func bind(task: DsymDownloadTask?) {
        downloadTask = task
        downloadStatusViewController?.bind(task: task)
        downloadItem.bind(task: task)
        dsymViewController?.bind(task: task)
        if let files = task?.dsymFiles {
            dsymManager.dsymFileDidUpdate(files)
        }
    }

    func startDownloading() {
        if let crash = dsymManager.crash {
            DsymDownloader.shared.download(crashInfo: crash, fileURL: nil)
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    func currentDownloadTask() -> DsymDownloadTask? {
        downloadTask
    }
}
