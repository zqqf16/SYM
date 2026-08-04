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

import Combine
import Foundation

class DsymFile: Hashable {
    let name: String
    let path: String
    let uuids: [String]
    let binaryPath: String
    let isApp: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    init(name: String, path: String, binaryPath: String, uuids: [String], isApp: Bool = false) {
        self.name = name
        self.path = path
        self.binaryPath = binaryPath
        self.uuids = uuids.compactMap { CrashUUID.normalize($0) ?? $0.uppercased() }
        self.isApp = isApp
    }

    static func == (lhs: DsymFile, rhs: DsymFile) -> Bool {
        lhs.path == rhs.path
    }
}

extension BinaryImage {
    var relativePath: String? {
        guard let path else {
            return nil
        }

        var components: [String] = []
        for dir in path.components(separatedBy: "/").reversed() {
            if dir.hasSuffix(".app") {
                break
            }
            components.append(dir)
        }
        return components.reversed().joined(separator: "/")
    }

    var isValid: Bool {
        uuid != nil && loadAddress != nil
    }
}

enum DsymLocator {
    static func resolveDwarfBinaryPath(from dsymOrBinaryPath: String) -> String? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: dsymOrBinaryPath, isDirectory: &isDirectory) else {
            return nil
        }

        if dsymOrBinaryPath.hasSuffix(".dSYM") || isDirectory.boolValue {
            let dwarfDirectory = (dsymOrBinaryPath as NSString)
                .appendingPathComponent("Contents/Resources/DWARF")
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dwarfDirectory),
                  let dwarfName = contents.first
            else {
                return nil
            }
            return (dwarfDirectory as NSString).appendingPathComponent(dwarfName)
        }

        return dsymOrBinaryPath
    }

    /// Executable UUID first, then frameworks — keeps Spotlight predicates focused.
    static func orderedUUIDs(from binaries: [BinaryImage]?) -> [String] {
        guard let binaries else {
            return []
        }
        var seen = Set<String>()
        var ordered: [String] = []
        let prioritized = binaries.filter(\.isExecutable) + binaries.filter { !$0.isExecutable }
        for binary in prioritized {
            guard let normalized = CrashUUID.normalize(binary.uuid), !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            ordered.append(normalized)
        }
        return ordered
    }

    /// Spotlight condition for dSYM UUIDs (quoted). Bundle ID is optional and last —
    /// useful for `.app` fallback but noisy for version matching.
    static func createCondition(bundleID: String?, binaries: [BinaryImage]?, includeBundleID: Bool = true) -> String? {
        var clauses: [String] = []
        for uuid in orderedUUIDs(from: binaries) {
            clauses.append("com_apple_xcode_dsym_uuids == \"\(uuid)\"")
        }
        if includeBundleID, let bundleID, !bundleID.isEmpty {
            let escaped = bundleID.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            clauses.append("kMDItemCFBundleIdentifier == \"\(escaped)\"")
        }
        guard !clauses.isEmpty else {
            return nil
        }
        return clauses.joined(separator: " || ")
    }

    static func preferredSearchScopes() -> [Any] {
        var scopes: [Any] = [NSMetadataQueryUserHomeScope]
        let archives = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Developer/Xcode/Archives")
        if FileManager.default.fileExists(atPath: archives) {
            scopes.append(archives)
        }
        let download = Config.dsymDownloadDirectory
        if FileManager.default.fileExists(atPath: download) {
            scopes.append(download)
        }
        return scopes
    }

    /// Fast path: walk known dirs and read metadata / dwarfdump without waiting for Spotlight.
    static func scanKnownDirectories(neededUUIDs: Set<String>, maxItems: Int = 400) -> [DsymFile] {
        guard !neededUUIDs.isEmpty else {
            return []
        }
        let roots = [
            (NSHomeDirectory() as NSString).appendingPathComponent("Library/Developer/Xcode/Archives"),
            Config.dsymDownloadDirectory,
        ]
        var found: [DsymFile] = []
        var visited = 0

        for root in roots {
            guard FileManager.default.fileExists(atPath: root) else {
                continue
            }
            let url = URL(fileURLWithPath: root, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let itemURL as URL in enumerator {
                if visited >= maxItems {
                    return found
                }
                let ext = itemURL.pathExtension
                if ext == "dSYM" {
                    visited += 1
                    enumerator.skipDescendants()
                    var matched: [DsymFile] = []
                    if let item = NSMetadataItem(url: itemURL) {
                        matched = parseDsymFile(item, neededUUIDs: neededUUIDs)
                    }
                    // init(url:) often lacks Xcode Spotlight importer attrs — probe DWARF.
                    if matched.isEmpty, let probed = probeDsymBundle(at: itemURL.path, neededUUIDs: neededUUIDs) {
                        matched = [probed]
                    }
                    found.append(contentsOf: matched)
                    if covers(neededUUIDs, files: found) {
                        return found
                    }
                } else if ext == "xcarchive" {
                    visited += 1
                    enumerator.skipDescendants()
                    var matched: [DsymFile] = []
                    if let item = NSMetadataItem(url: itemURL),
                       let parsed = parseXcarchiveFile(item, uuids: Array(neededUUIDs))
                    {
                        matched = parsed
                    }
                    if matched.isEmpty {
                        matched = probeXcarchive(at: itemURL.path, neededUUIDs: neededUUIDs)
                    }
                    found.append(contentsOf: matched)
                    if covers(neededUUIDs, files: found) {
                        return found
                    }
                }
            }
        }
        return found
    }

    private static func covers(_ needed: Set<String>, files: [DsymFile]) -> Bool {
        var matched = Set<String>()
        for file in files {
            matched.formUnion(file.uuids)
        }
        return needed.isSubset(of: matched)
    }

    private static func probeDsymBundle(at path: String, neededUUIDs: Set<String>) -> DsymFile? {
        guard let dwarf = resolveDwarfBinaryPath(from: path),
              let pairs = SubProcess.dwarfdump([dwarf])
        else {
            return nil
        }
        let matched = pairs.compactMap { CrashUUID.normalize($0.0) }.filter { neededUUIDs.contains($0) }
        guard !matched.isEmpty else {
            return nil
        }
        return DsymFile(
            name: (path as NSString).lastPathComponent,
            path: path,
            binaryPath: dwarf,
            uuids: matched
        )
    }

    /// Walk `*.xcarchive/dSYMs/*.dSYM` when Spotlight Xcode attrs are missing.
    private static func probeXcarchive(at path: String, neededUUIDs: Set<String>) -> [DsymFile] {
        let dsymsDir = (path as NSString).appendingPathComponent("dSYMs")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dsymsDir) else {
            return []
        }
        let archiveName = (path as NSString).lastPathComponent
        var found: [DsymFile] = []
        for name in names where name.hasSuffix(".dSYM") {
            let dsymPath = (dsymsDir as NSString).appendingPathComponent(name)
            guard let probed = probeDsymBundle(at: dsymPath, neededUUIDs: neededUUIDs) else {
                continue
            }
            found.append(DsymFile(
                name: archiveName,
                path: dsymPath,
                binaryPath: probed.binaryPath,
                uuids: probed.uuids
            ))
        }
        return found
    }

    /// Prefer `value(forAttribute:)` — KVC `value(forKey:)` throws NSUnknownKeyException
    /// when `NSMetadataItem(url:)` lacks Xcode importer attributes.
    private static func metadataString(_ item: NSMetadataItem, _ key: String) -> String? {
        item.value(forAttribute: key) as? String
    }

    private static func metadataStringArray(_ item: NSMetadataItem, _ key: String) -> [String]? {
        item.value(forAttribute: key) as? [String]
    }

    static func parseDsymFile(_ item: NSMetadataItem, neededUUIDs: Set<String>? = nil) -> [DsymFile] {
        guard let name = metadataString(item, NSMetadataItemFSNameKey),
              let path = metadataString(item, NSMetadataItemPathKey),
              let dsymPaths = metadataStringArray(item, "com_apple_xcode_dsym_paths"),
              let dsymUUIDs = metadataStringArray(item, "com_apple_xcode_dsym_uuids")
        else {
            return []
        }

        if dsymPaths.count == dsymUUIDs.count {
            return zip(dsymUUIDs, dsymPaths).compactMap { rawUUID, relativePath -> DsymFile? in
                guard let uuid = CrashUUID.normalize(rawUUID) else {
                    return nil
                }
                if let neededUUIDs, !neededUUIDs.contains(uuid) {
                    return nil
                }
                let realPath = (path as NSString).appendingPathComponent(relativePath)
                return DsymFile(name: name, path: path, binaryPath: realPath, uuids: [uuid])
            }
        }

        // Uneven metadata: keep only matching UUIDs, point at the first DWARF path.
        let realPath = (path as NSString).appendingPathComponent(dsymPaths[0])
        let matched = dsymUUIDs.compactMap { CrashUUID.normalize($0) }.filter { uuid in
            neededUUIDs?.contains(uuid) ?? true
        }
        guard !matched.isEmpty else {
            return []
        }
        return [DsymFile(name: name, path: path, binaryPath: realPath, uuids: matched)]
    }

    static func parseXcarchiveFile(_ item: NSMetadataItem, uuids: [String]) -> [DsymFile]? {
        guard let name = metadataString(item, NSMetadataItemFSNameKey),
              let path = metadataString(item, NSMetadataItemPathKey),
              let dsymPaths = metadataStringArray(item, "com_apple_xcode_dsym_paths"),
              let dsymUUIDs = metadataStringArray(item, "com_apple_xcode_dsym_uuids"),
              dsymPaths.count == dsymUUIDs.count
        else {
            return nil
        }

        let needed = Set(uuids.compactMap { CrashUUID.normalize($0) })
        return zip(dsymUUIDs, dsymPaths).compactMap { dsymUUID, dsymPath -> DsymFile? in
            guard let uuid = CrashUUID.normalize(dsymUUID), needed.contains(uuid) else {
                return nil
            }

            var displayPath = path
            let realPath = (path as NSString).appendingPathComponent(dsymPath)
            let pathComponents = dsymPath.components(separatedBy: "/")
            if pathComponents.count > 2 {
                displayPath += "/\(pathComponents[0])/\(pathComponents[1])"
            } else {
                displayPath = realPath
            }

            return DsymFile(name: name, path: displayPath, binaryPath: realPath, uuids: [uuid])
        }
    }

    static func parseBinary(_ binary: BinaryImage, bundle: Bundle, name: String?) -> DsymFile? {
        guard let path = binary.relativePath,
              let absPath = bundle.path(forResource: path, ofType: nil),
              let uuidMap = SubProcess.dwarfdump([absPath]),
              let expected = CrashUUID.normalize(binary.uuid)
        else {
            return nil
        }

        let dsymName = name ?? path
        let uuids = uuidMap.compactMap { CrashUUID.normalize($0.0) }
        guard uuids.contains(expected) else {
            return nil
        }
        return DsymFile(name: dsymName, path: absPath, binaryPath: absPath, uuids: uuids, isApp: true)
    }

    static func parseAppBundle(_ item: NSMetadataItem, binaries: [BinaryImage]) -> [DsymFile]? {
        guard let path = metadataString(item, NSMetadataItemPathKey),
              let bundle = Bundle(path: path)
        else {
            return nil
        }

        let name = metadataString(item, NSMetadataItemFSNameKey)
        guard let executable = binaries.first(where: \.isExecutable),
              let mainDsym = parseBinary(executable, bundle: bundle, name: name)
        else {
            return nil
        }

        var dsyms = [mainDsym]
        for framework in binaries where !framework.isExecutable {
            if let dsym = parseBinary(framework, bundle: bundle, name: name) {
                dsyms.append(dsym)
            }
        }
        return dsyms
    }

    static func dsymFilesMap(from dsymFiles: [DsymFile]) -> [String: DsymFile] {
        var result = [String: DsymFile]()
        for dsym in dsymFiles {
            for uuid in dsym.uuids {
                if let key = CrashUUID.normalize(uuid) {
                    result[key] = dsym
                }
            }
        }
        return result
    }
}

class DsymManager {
    @Published
    var binaries: [BinaryImage] = []

    /// Keys are always `CrashUUID.normalize`'d.
    @Published
    var dsymFiles: [String: DsymFile] = [:]

    @Published
    var crash: CrashReport?

    private var manualUUIDs = Set<String>()
    private var searchGeneration = 0

    private var neededUUIDs: Set<String> {
        Set(DsymLocator.orderedUUIDs(from: binaries))
    }

    private var uuids: [String] {
        Array(neededUUIDs)
    }

    private let operationQueue = DispatchQueue(label: "dsym.manager")
    private lazy var monitor: MdfindWrapper = {
        let mdfind = MdfindWrapper()
        mdfind.delegate = self
        return mdfind
    }()

    deinit {
        monitor.stop()
    }

    func update(_ crash: CrashReport?) {
        searchGeneration += 1
        let generation = searchGeneration
        self.crash = crash
        binaries = crash?.embeddedBinaries ?? []
        manualUUIDs.removeAll()
        dsymFiles = [:]
        monitor.stop()

        guard let crash else {
            return
        }
        start(crash, generation: generation)
    }

    private func start(_ crash: CrashReport, generation: Int) {
        let needed = neededUUIDs

        operationQueue.async { [weak self] in
            guard let self else { return }
            let local = DsymLocator.scanKnownDirectories(neededUUIDs: needed)
            DispatchQueue.main.async {
                guard generation == self.searchGeneration else { return }
                if !local.isEmpty {
                    self.mergeDsymFiles(local)
                }
                if self.hasCompleteCoverage {
                    return
                }
                self.startSpotlight(for: crash)
            }
        }
    }

    private func startSpotlight(for crash: CrashReport) {
        // UUID-only first (precise). Bundle ID is included so `.app` fallback still works,
        // but results are filtered to needed UUIDs before merging.
        guard let condition = DsymLocator.createCondition(
            bundleID: crash.bundleID,
            binaries: crash.embeddedBinaries,
            includeBundleID: true
        ) else {
            return
        }
        monitor.start(withCondition: condition, scopes: DsymLocator.preferredSearchScopes())
    }

    func stop() {
        monitor.stop()
    }

    func dsymFile(withUuid uuid: String) -> DsymFile? {
        guard let key = CrashUUID.normalize(uuid) else {
            return nil
        }
        return dsymFiles[key]
    }

    var hasCompleteCoverage: Bool {
        let needed = neededUUIDs
        guard !needed.isEmpty else {
            return false
        }
        return needed.allSatisfy { dsymFiles[$0] != nil }
    }

    func assign(_ binary: BinaryImage, dsymFileURL: URL) {
        let path = dsymFileURL.path
        let name = dsymFileURL.lastPathComponent
        guard let uuid = CrashUUID.normalize(binary.uuid) else {
            return
        }
        let binaryPath = DsymLocator.resolveDwarfBinaryPath(from: path) ?? path
        let dsymFile = DsymFile(name: name, path: path, binaryPath: binaryPath, uuids: [uuid])

        DispatchQueue.main.async {
            self.manualUUIDs.insert(uuid)
            self.dsymFiles[uuid] = dsymFile
        }
    }

    /// Merge discovered dSYMs without wiping manual imports or unrelated keys.
    func mergeDsymFiles(_ files: [DsymFile]) {
        let generation = searchGeneration
        let apply = { [weak self] in
            guard let self, generation == self.searchGeneration else { return }
            var merged = self.dsymFiles
            let needed = self.neededUUIDs
            for file in files {
                for uuid in file.uuids {
                    guard let key = CrashUUID.normalize(uuid) else { continue }
                    if !needed.isEmpty, !needed.contains(key) {
                        continue
                    }
                    if self.manualUUIDs.contains(key) {
                        continue
                    }
                    merged[key] = file
                }
            }
            self.dsymFiles = merged
            if self.hasCompleteCoverage {
                self.monitor.stop()
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// Back-compat for download / callers that used to replace the whole map.
    func dsymFileDidUpdate(_ dsymFiles: [DsymFile] = []) {
        if dsymFiles.isEmpty {
            return
        }
        mergeDsymFiles(dsymFiles)
    }

    var dsymPathMap: [String: String] {
        var map = [String: String]()
        for (uuid, dsymFile) in dsymFiles {
            if let normalized = CrashUUID.normalize(uuid) {
                map[normalized] = dsymFile.binaryPath
            }
        }
        return map
    }
}

extension DsymManager: MdfindWrapperDelegate {
    func mdfindWrapper(_: MdfindWrapper, didFindResult result: [NSMetadataItem]?) {
        let generation = searchGeneration
        guard let result else {
            return
        }

        let needed = neededUUIDs
        var appItems = [NSMetadataItem]()
        var dsyms = [DsymFile]()

        for item in result {
            guard let type = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String else {
                continue
            }
            if type == "com.apple.xcode.dsym" {
                dsyms.append(contentsOf: DsymLocator.parseDsymFile(item, neededUUIDs: needed.isEmpty ? nil : needed))
            } else if type == "com.apple.xcode.archive" {
                if let results = DsymLocator.parseXcarchiveFile(item, uuids: uuids) {
                    dsyms.append(contentsOf: results)
                }
            } else if type == "com.apple.application-bundle" {
                appItems.append(item)
            }
        }

        let binariesSnapshot = binaries
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.searchGeneration else { return }
            if !dsyms.isEmpty {
                self.mergeDsymFiles(dsyms)
            }
            if self.hasCompleteCoverage || appItems.isEmpty {
                return
            }

            self.operationQueue.async { [weak self] in
                guard let self else { return }
                for app in appItems {
                    guard generation == self.searchGeneration else { return }
                    if let found = DsymLocator.parseAppBundle(app, binaries: binariesSnapshot) {
                        self.mergeDsymFiles(found)
                        return
                    }
                }
            }
        }
    }
}
