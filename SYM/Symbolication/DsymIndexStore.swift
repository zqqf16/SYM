// The MIT License (MIT)
//
// Copyright (c) 2026 zqqf16
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

import Foundation

/// Persistent UUID → dSYM map under Application Support.
///
/// `DsymLocator.scanKnownDirectories` walks the whole Archives tree and probes
/// Mach-O headers on every open; the index lets repeat opens of the same crash
/// (or any crash whose UUIDs were already seen) skip that walk entirely.
///
/// Entries are only a shortcut, never a source of truth: symbolication engines
/// verify the UUID again when loading the binary, so a stale entry (moved /
/// rebuilt dSYM at the same path) fails safe instead of mis-symbolicating.
final class DsymIndexStore {
    struct Entry: Codable, Equatable {
        let name: String
        let path: String
        let binaryPath: String
        let isApp: Bool
    }

    static let shared = DsymIndexStore()

    private let fileURL: URL
    private let lock = NSLock()
    private var entries: [String: Entry]
    private var isDirty = false

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        fileURL = dir.appendingPathComponent("dsym-index.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        {
            entries = decoded
        } else {
            entries = [:]
        }
    }

    private static func defaultDirectory() -> URL {
        let support = FileManager.default.appSupportDirectory()
            ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: support, withIntermediateDirectories: true)
        return URL(fileURLWithPath: support, isDirectory: true)
    }

    /// Cached files for `neededUUIDs`, or nil when the index cannot serve the
    /// request as completely as a directory scan would (same stop condition:
    /// either the priority UUIDs or all needed UUIDs must be covered, and every
    /// hit path must still exist).
    func cachedFiles(neededUUIDs: Set<String>, stopUUIDs: Set<String>) -> [DsymFile]? {
        guard !neededUUIDs.isEmpty else {
            return nil
        }
        let stop = stopUUIDs.isEmpty ? neededUUIDs : stopUUIDs
        let fileManager = FileManager.default

        lock.lock()
        var files = [DsymFile]()
        var covered = Set<String>()
        for uuid in neededUUIDs {
            guard let entry = entries[uuid],
                  fileManager.fileExists(atPath: entry.path)
            else {
                continue
            }
            covered.insert(uuid)
            files.append(DsymFile(
                name: entry.name,
                path: entry.path,
                binaryPath: entry.binaryPath,
                uuids: [uuid],
                isApp: entry.isApp
            ))
        }
        lock.unlock()

        guard !files.isEmpty, stop.isSubset(of: covered) else {
            return nil
        }
        return files
    }

    func record(_ files: [DsymFile]) {
        guard !files.isEmpty else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        for file in files {
            let entry = Entry(
                name: file.name,
                path: file.path,
                binaryPath: file.binaryPath,
                isApp: file.isApp
            )
            for uuid in file.uuids {
                guard let key = CrashUUID.normalize(uuid) else {
                    continue
                }
                if entries[key] != entry {
                    entries[key] = entry
                    isDirty = true
                }
            }
        }
    }

    /// Prune entries whose bundle no longer exists, then persist atomically.
    func save() {
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        let before = entries.count
        entries = entries.filter { fileManager.fileExists(atPath: $0.value.path) }
        if entries.count != before {
            isDirty = true
        }
        guard isDirty, let data = try? JSONEncoder().encode(entries) else {
            return
        }
        isDirty = false
        try? data.write(to: fileURL, options: .atomic)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
