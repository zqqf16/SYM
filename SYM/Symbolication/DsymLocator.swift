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
        self.uuids = uuids
        self.isApp = isApp
    }

    static func == (lhs: DsymFile, rhs: DsymFile) -> Bool {
        return lhs.path == rhs.path
    }
}

extension BinaryImage {
    var relativePath: String? {
        guard let path = path else {
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

    static func createCondition(bundleID: String?, binaries: [BinaryImage]?) -> String? {
        var condition = ""
        var hasPrefix = false

        binaries?.forEach { binary in
            if let uuid = binary.uuid {
                if hasPrefix {
                    condition += " || "
                }
                condition += "com_apple_xcode_dsym_uuids = \(uuid)"
                hasPrefix = true
            }
        }

        if let bundleID {
            if hasPrefix {
                condition += " || "
            }
            condition += "kMDItemCFBundleIdentifier = \(bundleID)"
        }

        if condition.isEmpty {
            return nil
        }

        return condition
    }

    static func parseDsymFile(_ item: NSMetadataItem) -> DsymFile? {
        guard let name = item.value(forKey: NSMetadataItemFSNameKey) as? String,
              let path = item.value(forKey: NSMetadataItemPathKey) as? String,
              let dsymPaths = item.value(forKey: "com_apple_xcode_dsym_paths") as? [String],
              let dsymUUIDs = item.value(forKey: "com_apple_xcode_dsym_uuids") as? [String]
        else {
            return nil
        }

        let realPath = "\(path)/\(dsymPaths[0])"
        return DsymFile(name: name, path: path, binaryPath: realPath, uuids: dsymUUIDs)
    }

    static func parseXcarchiveFile(_ item: NSMetadataItem, uuids: [String]) -> [DsymFile]? {
        guard let name = item.value(forKey: NSMetadataItemFSNameKey) as? String,
              let path = item.value(forKey: NSMetadataItemPathKey) as? String,
              let dsymPaths = item.value(forKey: "com_apple_xcode_dsym_paths") as? [String],
              let dsymUUIDs = item.value(forKey: "com_apple_xcode_dsym_uuids") as? [String],
              dsymPaths.count == dsymUUIDs.count
        else {
            return nil
        }

        return zip(dsymUUIDs, dsymPaths).compactMap { dsymUUID, dsymPath -> DsymFile? in
            if !uuids.contains(dsymUUID) {
                return nil
            }

            var displayPath = path
            let realPath = "\(path)/\(dsymPath)"
            let pathComponents = dsymPath.components(separatedBy: "/")
            if pathComponents.count > 2 {
                displayPath += "/\(pathComponents[0])/\(pathComponents[1])"
            } else {
                displayPath = realPath
            }

            return DsymFile(name: name, path: displayPath, binaryPath: realPath, uuids: [dsymUUID])
        }
    }

    static func parseBinary(_ binary: BinaryImage, bundle: Bundle, name: String?) -> DsymFile? {
        guard let path = binary.relativePath,
              let absPath = bundle.path(forResource: path, ofType: nil),
              let uuidMap = SubProcess.dwarfdump([absPath])
        else {
            return nil
        }

        let dsymName = name ?? path
        let uuids = uuidMap.map(\.0)
        for uuid in uuids where uuid == binary.uuid {
            return DsymFile(name: dsymName, path: absPath, binaryPath: absPath, uuids: uuids, isApp: true)
        }

        return nil
    }

    static func parseAppBundle(_ item: NSMetadataItem, binaries: [BinaryImage]) -> [DsymFile]? {
        guard let path = item.value(forKey: NSMetadataItemPathKey) as? String,
              let bundle = Bundle(path: path)
        else {
            return nil
        }

        let name = item.value(forKey: NSMetadataItemFSNameKey) as? String
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
        dsymFiles.forEach { dsym in
            dsym.uuids.forEach { uuid in
                result[uuid] = dsym
            }
        }
        return result
    }
}

class DsymManager {
    @Published
    var binaries: [BinaryImage] = []

    @Published
    var dsymFiles: [String: DsymFile] = [:]

    @Published
    var crash: CrashReport?

    private var uuids: [String] {
        binaries.compactMap(\.uuid)
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
        self.crash = crash
        binaries = crash?.embeddedBinaries ?? []
        if let crash {
            start(crash)
        } else {
            stop()
        }
    }

    func start(_ crash: CrashReport) {
        if let condition = DsymLocator.createCondition(bundleID: crash.bundleID, binaries: crash.embeddedBinaries) {
            monitor.start(withCondition: condition)
        }
    }

    func stop() {
        monitor.stop()
    }

    func dsymFile(withUuid uuid: String) -> DsymFile? {
        dsymFiles[uuid]
    }

    func assign(_ binary: BinaryImage, dsymFileURL: URL) {
        let path = dsymFileURL.path
        let name = dsymFileURL.lastPathComponent
        let uuid = binary.uuid ?? ""
        let binaryPath = DsymLocator.resolveDwarfBinaryPath(from: path) ?? path
        let dsymFile = DsymFile(name: name, path: path, binaryPath: binaryPath, uuids: [uuid])

        DispatchQueue.main.async {
            self.dsymFiles[uuid] = dsymFile
        }
    }

    func dsymFileDidUpdate(_ dsymFiles: [DsymFile] = []) {
        DispatchQueue.main.async {
            self.dsymFiles = DsymLocator.dsymFilesMap(from: dsymFiles)
        }
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
        if result == nil {
            dsymFileDidUpdate()
            return
        }

        var appItems = [NSMetadataItem]()
        var dsyms = [DsymFile]()

        for item in result! {
            let type = item.value(forKey: NSMetadataItemContentTypeKey) as! String
            if type == "com.apple.xcode.dsym" {
                if let dsym = DsymLocator.parseDsymFile(item) {
                    dsyms.append(dsym)
                }
            } else if type == "com.apple.xcode.archive" {
                if let results = DsymLocator.parseXcarchiveFile(item, uuids: uuids) {
                    dsyms.append(contentsOf: results)
                }
            } else if type == "com.apple.application-bundle" {
                appItems.append(item)
            }
        }

        if !dsyms.isEmpty || appItems.isEmpty {
            dsymFileDidUpdate(dsyms)
            return
        }

        operationQueue.async {
            for app in appItems {
                if let dsyms = DsymLocator.parseAppBundle(app, binaries: self.binaries) {
                    self.dsymFileDidUpdate(dsyms)
                    return
                }
            }
        }
    }
}
