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
import MachOKit

/// Spotlight / NSMetadataItem attribute keys used by Xcode's dSYM importer.
enum DsymMetadataKey {
    static let uuids = "com_apple_xcode_dsym_uuids"
    static let paths = "com_apple_xcode_dsym_paths"
}

/// Uniform Type Identifiers returned by Spotlight for dSYM / archive / app results.
enum SpotlightContentType {
    static let dsym = "com.apple.xcode.dsym"
    static let archive = "com.apple.xcode.archive"
    static let applicationBundle = "com.apple.application-bundle"
}

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
            clauses.append("\(DsymMetadataKey.uuids) == \"\(uuid)\"")
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
    ///
    /// Archives are scored by `Info.plist` ApplicationProperties (bundle ID + build) so Debug
    /// builds (DWARF in Products/*.app, empty dSYMs/) are probed before unrelated archives.
    ///
    /// A persistent UUID index short-circuits the walk when previous scans already
    /// mapped the needed UUIDs to dSYMs that are still on disk.
    static func scanKnownDirectories(
        neededUUIDs: Set<String>,
        bundleID: String? = nil,
        appVersion: String? = nil,
        priorityUUIDs: Set<String> = [],
        maxItems: Int = 400,
        index: DsymIndexStore? = DsymIndexStore.shared
    ) -> [DsymFile] {
        guard !neededUUIDs.isEmpty else {
            return []
        }
        let stopUUIDs = priorityUUIDs.isEmpty ? neededUUIDs : priorityUUIDs

        if let index, let cached = index.cachedFiles(neededUUIDs: neededUUIDs, stopUUIDs: stopUUIDs) {
            return cached
        }

        let found = scanKnownDirectoriesOnDisk(
            neededUUIDs: neededUUIDs,
            bundleID: bundleID,
            appVersion: appVersion,
            priorityUUIDs: priorityUUIDs,
            maxItems: maxItems
        )
        if let index, !found.isEmpty {
            index.record(found)
            index.save()
        }
        return found
    }

    private static func scanKnownDirectoriesOnDisk(
        neededUUIDs: Set<String>,
        bundleID: String?,
        appVersion: String?,
        priorityUUIDs: Set<String>,
        maxItems: Int
    ) -> [DsymFile] {
        let stopUUIDs = priorityUUIDs.isEmpty ? neededUUIDs : priorityUUIDs
        let versionHints = versionHints(from: appVersion)
        let roots = [
            (NSHomeDirectory() as NSString).appendingPathComponent("Library/Developer/Xcode/Archives"),
            Config.dsymDownloadDirectory,
        ]

        var dsymURLs: [URL] = []
        var archiveCandidates: [(url: URL, score: Int, modified: Date)] = []

        for root in roots {
            guard FileManager.default.fileExists(atPath: root) else {
                continue
            }
            let url = URL(fileURLWithPath: root, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let itemURL as URL in enumerator {
                let ext = itemURL.pathExtension
                if ext == "dSYM" {
                    enumerator.skipDescendants()
                    dsymURLs.append(itemURL)
                } else if ext == "xcarchive" {
                    enumerator.skipDescendants()
                    let score = archiveMatchScore(
                        at: itemURL.path,
                        bundleID: bundleID,
                        versionHints: versionHints
                    )
                    // Wrong bundle ID → skip expensive Products dwarfdump later (score == -1).
                    if score < 0 {
                        continue
                    }
                    let modified = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate) ?? .distantPast
                    archiveCandidates.append((itemURL, score, modified))
                }
            }
        }

        archiveCandidates.sort {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.modified > $1.modified
        }

        var found: [DsymFile] = []
        var remaining = neededUUIDs
        var visited = 0
        var productsProbes = 0
        let maxProductsProbes = 8

        func ingest(_ matched: [DsymFile]) -> Bool {
            guard !matched.isEmpty else {
                return false
            }
            found.append(contentsOf: matched)
            for file in matched {
                remaining.subtract(file.uuids)
            }
            return covers(stopUUIDs, files: found) || remaining.isEmpty
        }

        for itemURL in dsymURLs {
            if visited >= maxItems {
                return found
            }
            visited += 1
            var matched: [DsymFile] = []
            if let item = NSMetadataItem(url: itemURL) {
                matched = parseDsymFile(item, neededUUIDs: remaining)
            }
            if matched.isEmpty, let probed = probeDsymBundle(at: itemURL.path, neededUUIDs: remaining) {
                matched = [probed]
            }
            if ingest(matched) {
                return found
            }
        }

        for candidate in archiveCandidates {
            if visited >= maxItems {
                return found
            }
            visited += 1
            var matched: [DsymFile] = []
            if let item = NSMetadataItem(url: candidate.url),
               let parsed = parseXcarchiveFile(item, uuids: Array(remaining))
            {
                matched = parsed
            }
            if covers(remaining, files: matched) {
                if ingest(matched) {
                    return found
                }
                continue
            }

            let stillNeeded = remaining.subtracting(Set(matched.flatMap(\.uuids)))
            let needed = stillNeeded.isEmpty ? remaining : stillNeeded
            let dsymsEmpty = archiveDsymsAreEmpty(at: candidate.url.path)
            // Exact build (score >= 100) or empty dSYMs/ Debug archives: look in Products.
            // Same-bundle Release archives with non-matching dSYMs skip Products —
            // spawning dwarfdump on every framework was burning CPU for minutes.
            let exactBuild = candidate.score >= 100
            let includeProducts = exactBuild
                || (dsymsEmpty && productsProbes < maxProductsProbes)
            if includeProducts, !exactBuild, dsymsEmpty {
                productsProbes += 1
            }
            matched.append(contentsOf: probeXcarchive(
                at: candidate.url.path,
                neededUUIDs: needed,
                includeProducts: includeProducts
            ))
            if ingest(matched) {
                return found
            }
        }
        return found
    }

    /// Parse `"6.1.0 (20260804173156)"` / bare build strings into match hints.
    static func versionHints(from appVersion: String?) -> (marketing: String?, build: String?) {
        guard let appVersion, !appVersion.isEmpty else {
            return (nil, nil)
        }
        let trimmed = appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = trimmed.firstIndex(of: "("),
           let close = trimmed.firstIndex(of: ")"),
           open < close
        {
            let marketing = trimmed[..<open].trimmingCharacters(in: .whitespaces)
            let build = trimmed[trimmed.index(after: open) ..< close]
                .trimmingCharacters(in: .whitespaces)
            return (
                marketing.isEmpty ? nil : String(marketing),
                build.isEmpty ? nil : String(build)
            )
        }
        return (trimmed, trimmed)
    }

    /// Higher is better. `-1` means a different bundle ID (skip). `0` means unknown plist.
    private static func archiveMatchScore(
        at path: String,
        bundleID: String?,
        versionHints: (marketing: String?, build: String?)
    ) -> Int {
        let infoPath = (path as NSString).appendingPathComponent("Info.plist")
        guard let plist = NSDictionary(contentsOfFile: infoPath) as? [String: Any],
              let props = plist["ApplicationProperties"] as? [String: Any]
        else {
            return 0
        }

        let archiveBundleID = props["CFBundleIdentifier"] as? String
        if let bundleID, !bundleID.isEmpty, let archiveBundleID, archiveBundleID != bundleID {
            return -1
        }

        var score = 0
        if let bundleID, !bundleID.isEmpty, archiveBundleID == bundleID {
            score += 50
        }
        let archiveBuild = props["CFBundleVersion"] as? String
        let archiveMarketing = props["CFBundleShortVersionString"] as? String
        if let build = versionHints.build, !build.isEmpty, archiveBuild == build {
            score += 100
        } else if let marketing = versionHints.marketing,
                  !marketing.isEmpty,
                  archiveMarketing == marketing
        {
            score += 20
        }
        return score
    }

    static func covers(_ needed: Set<String>, files: [DsymFile]) -> Bool {
        guard !needed.isEmpty else {
            return true
        }
        var matched = Set<String>()
        for file in files {
            matched.formUnion(file.uuids)
        }
        return needed.isSubset(of: matched)
    }

    /// LC_UUID from the Mach-O header — no `dwarfdump` process.
    static func uuidsOfBinary(at path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        guard let loaded = try? MachOKit.loadFromFile(url: url) else {
            return SubProcess.dwarfdump([path])?.compactMap { CrashUUID.normalize($0.0) } ?? []
        }

        func uuid(from machO: MachOFile) -> String? {
            guard let command = machO.loadCommands.info(of: LoadCommand.uuid) else {
                return nil
            }
            return CrashUUID.normalize(command.uuid.uuidString)
        }

        switch loaded {
        case let .machO(file):
            return uuid(from: file).map { [$0] } ?? []
        case let .fat(fat):
            guard let slices = try? fat.machOFiles() else {
                return []
            }
            var seen = Set<String>()
            var result: [String] = []
            for slice in slices {
                guard let value = uuid(from: slice), seen.insert(value).inserted else {
                    continue
                }
                result.append(value)
            }
            return result
        }
    }

    private static func archiveDsymsAreEmpty(at archivePath: String) -> Bool {
        let dsymsDir = (archivePath as NSString).appendingPathComponent("dSYMs")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dsymsDir) else {
            return true
        }
        return !names.contains { $0.hasSuffix(".dSYM") }
    }

    private static func probeDsymBundle(at path: String, neededUUIDs: Set<String>) -> DsymFile? {
        guard let dwarf = resolveDwarfBinaryPath(from: path) else {
            return nil
        }
        let matched = uuidsOfBinary(at: dwarf).filter { neededUUIDs.contains($0) }
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

    /// Probe an xcarchive for matching UUIDs via `dSYMs/*.dSYM`, then optionally
    /// `Products/Applications/*.app` (Debug builds keep DWARF in the binary).
    static func probeXcarchive(
        at path: String,
        neededUUIDs: Set<String>,
        includeProducts: Bool = true
    ) -> [DsymFile] {
        let archiveName = (path as NSString).lastPathComponent
        var found: [DsymFile] = []

        let dsymsDir = (path as NSString).appendingPathComponent("dSYMs")
        if let names = try? FileManager.default.contentsOfDirectory(atPath: dsymsDir) {
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
        }

        if includeProducts, !covers(neededUUIDs, files: found) {
            found.append(contentsOf: probeXcarchiveProducts(
                at: path,
                neededUUIDs: neededUUIDs,
                archiveName: archiveName
            ))
        }
        return found
    }

    /// Debug / no-dSYM archives: match UUID against the app (and embedded frameworks) under Products.
    private static func probeXcarchiveProducts(
        at archivePath: String,
        neededUUIDs: Set<String>,
        archiveName: String
    ) -> [DsymFile] {
        let appsDir = (archivePath as NSString).appendingPathComponent("Products/Applications")
        guard let appNames = try? FileManager.default.contentsOfDirectory(atPath: appsDir) else {
            return []
        }

        var found: [DsymFile] = []
        for appName in appNames where appName.hasSuffix(".app") {
            let appPath = (appsDir as NSString).appendingPathComponent(appName)
            found.append(contentsOf: probeAppBundleBinaries(
                at: appPath,
                neededUUIDs: neededUUIDs,
                displayName: archiveName
            ))
            if covers(neededUUIDs, files: found) {
                break
            }
        }
        return found
    }

    /// dwarfdump the main executable first, then `Frameworks/*.framework` for remaining UUIDs.
    private static func probeAppBundleBinaries(
        at appPath: String,
        neededUUIDs: Set<String>,
        displayName: String
    ) -> [DsymFile] {
        var remaining = neededUUIDs
        guard !remaining.isEmpty else {
            return []
        }

        var candidates: [String] = []
        if let bundle = Bundle(path: appPath), let exe = bundle.executablePath {
            candidates.append(exe)
        }

        let frameworksDir = (appPath as NSString).appendingPathComponent("Frameworks")
        if let frameworkNames = try? FileManager.default.contentsOfDirectory(atPath: frameworksDir) {
            for name in frameworkNames where name.hasSuffix(".framework") {
                let frameworkPath = (frameworksDir as NSString).appendingPathComponent(name)
                if let framework = Bundle(path: frameworkPath), let exe = framework.executablePath {
                    candidates.append(exe)
                    continue
                }
                let bareName = (name as NSString).deletingPathExtension
                let barePath = (frameworkPath as NSString).appendingPathComponent(bareName)
                if FileManager.default.isExecutableFile(atPath: barePath)
                    || FileManager.default.fileExists(atPath: barePath)
                {
                    candidates.append(barePath)
                }
            }
        }

        var found: [DsymFile] = []
        var isMainExecutable = true
        for binaryPath in candidates {
            guard !remaining.isEmpty else {
                break
            }
            let matched = uuidsOfBinary(at: binaryPath).filter { remaining.contains($0) }
            if isMainExecutable {
                isMainExecutable = false
                // Wrong build: this archive's frameworks share the same version.
                if matched.isEmpty {
                    return []
                }
            }
            guard !matched.isEmpty else {
                continue
            }
            remaining.subtract(matched)
            found.append(DsymFile(
                name: displayName,
                path: appPath,
                binaryPath: binaryPath,
                uuids: matched,
                isApp: true
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
              let dsymPaths = metadataStringArray(item, DsymMetadataKey.paths),
              let dsymUUIDs = metadataStringArray(item, DsymMetadataKey.uuids)
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
              let dsymPaths = metadataStringArray(item, DsymMetadataKey.paths),
              let dsymUUIDs = metadataStringArray(item, DsymMetadataKey.uuids),
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
              let expected = CrashUUID.normalize(binary.uuid)
        else {
            return nil
        }

        let dsymName = name ?? path
        let uuids = uuidsOfBinary(at: absPath)
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
        let priority = Set(
            crash.embeddedBinaries
                .filter(\.isExecutable)
                .compactMap { CrashUUID.normalize($0.uuid) }
        )
        let bundleID = crash.bundleID
        let appVersion = crash.appVersion

        operationQueue.async { [weak self] in
            guard let self else { return }
            let local = DsymLocator.scanKnownDirectories(
                neededUUIDs: needed,
                bundleID: bundleID,
                appVersion: appVersion,
                priorityUUIDs: priority
            )
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
    /// Runs on the main thread (NSMetadataQuery delivers on its start run loop).
    /// Metadata-only parsing is fine here; probing archives on disk
    /// (MachO loads / dwarfdump) must be dispatched off the main thread or a
    /// result batch freezes the UI for seconds.
    func mdfindWrapper(_: MdfindWrapper, didFindResult result: [NSMetadataItem]?) {
        let generation = searchGeneration
        guard let result else {
            return
        }

        let needed = neededUUIDs
        var appItems = [NSMetadataItem]()
        var dsyms = [DsymFile]()
        var archiveProbes: [(path: String, neededUUIDs: Set<String>, includeProducts: Bool)] = []

        for item in result {
            guard let type = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String else {
                continue
            }
            if type == SpotlightContentType.dsym {
                dsyms.append(contentsOf: DsymLocator.parseDsymFile(item, neededUUIDs: needed.isEmpty ? nil : needed))
            } else if type == SpotlightContentType.archive {
                let archiveResults = DsymLocator.parseXcarchiveFile(item, uuids: uuids) ?? []
                if !archiveResults.isEmpty {
                    dsyms.append(contentsOf: archiveResults)
                }
                // Metadata misses Debug archives (DWARF lives in Products/*.app).
                // Wrong-version Release archives already listed non-matching UUIDs —
                // skip Products; the main-exe UUID check is cheap if we do probe.
                if !DsymLocator.covers(needed, files: archiveResults),
                   let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
                {
                    archiveProbes.append((path, needed, archiveResults.isEmpty))
                }
            } else if type == SpotlightContentType.applicationBundle {
                appItems.append(item)
            }
        }

        if !dsyms.isEmpty {
            mergeDsymFiles(dsyms)
        }

        guard !archiveProbes.isEmpty || !appItems.isEmpty, !hasCompleteCoverage else {
            return
        }

        let binariesSnapshot = binaries
        operationQueue.async { [weak self] in
            guard let self else { return }
            var probed = [DsymFile]()
            for probe in archiveProbes {
                guard generation == self.searchGeneration else { return }
                probed.append(contentsOf: DsymLocator.probeXcarchive(
                    at: probe.path,
                    neededUUIDs: probe.neededUUIDs,
                    includeProducts: probe.includeProducts
                ))
            }
            for app in appItems {
                guard generation == self.searchGeneration else { return }
                if let found = DsymLocator.parseAppBundle(app, binaries: binariesSnapshot) {
                    probed.append(contentsOf: found)
                    break
                }
            }
            if !probed.isEmpty {
                self.mergeDsymFiles(probed)
            }
        }
    }
}
