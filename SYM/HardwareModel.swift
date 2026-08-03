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

import Foundation

extension Notification.Name {
    static let hardwareModelsDidUpdate = Notification.Name("sym.hardwareModels.didUpdate")
}

extension String {
    static let hardwareModelsLastUpdatedKey = "hardwareModelsLastUpdated"
}

/// Resolves Apple machine identifiers (e.g. `iPhone9,2`) to marketing names.
/// Uses a bundled JSON database, optionally replaced by a runtime download into
/// Application Support (Settings → Check for Updates).
final class HardwareModelStore {
    static let shared = HardwareModelStore()

    /// DeviceNameKit publishes stable raw JSON (not HTML). Same sources as `scripts/update-hardware-models.sh`.
    private static let remoteBaseURL = URL(string: "https://raw.githubusercontent.com/kimdaehee0824/DeviceNameKit/main/DeviceName")!
    private static let remoteFiles = ["iOS.json", "watchOS.json", "tvOS.json", "visionOS.json"]
    private static let cacheFileName = "hardware-models.json"
    private static let bundledResourceName = "hardware-models"

    private let lock = NSLock()
    private var map: [String: String]

    private init() {
        map = Self.loadInitialMap()
    }

    var entryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return map.count
    }

    var lastUpdated: Date? {
        if let interval = UserDefaults.standard.object(forKey: .hardwareModelsLastUpdatedKey) as? TimeInterval {
            return Date(timeIntervalSince1970: interval)
        }
        if FileManager.default.fileExists(atPath: Self.cachedFileURL.path) {
            return (try? FileManager.default.attributesOfItem(atPath: Self.cachedFileURL.path)[.modificationDate]) as? Date
        }
        return nil
    }

    func name(for model: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return map[model] ?? model
    }

    enum UpdateOutcome: Equatable {
        case updated(count: Int)
        case unchanged(count: Int)
    }

    enum UpdateError: LocalizedError {
        case invalidRemoteData
        case emptyRemoteData
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .invalidRemoteData:
                return NSLocalizedString("Could not parse the hardware model database.", comment: "Hardware models update error")
            case .emptyRemoteData:
                return NSLocalizedString("The remote hardware model database was empty.", comment: "Hardware models update error")
            case .writeFailed:
                return NSLocalizedString("Could not save the hardware model database.", comment: "Hardware models update error")
            }
        }
    }

    /// Downloads platform JSON files, merges them, and replaces the Application Support cache when changed.
    @discardableResult
    func checkForUpdates() async throws -> UpdateOutcome {
        var merged: [String: String] = [:]
        for file in Self.remoteFiles {
            let url = Self.remoteBaseURL.appendingPathComponent(file)
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            guard let chunk = try? JSONDecoder().decode([String: String].self, from: data) else {
                throw UpdateError.invalidRemoteData
            }
            merged.merge(chunk) { _, new in new }
        }

        merged["i386"] = merged["i386"] ?? "Simulator"
        merged["x86_64"] = merged["x86_64"] ?? "Simulator"
        merged["arm64"] = merged["arm64"] ?? "Simulator"

        guard !merged.isEmpty else {
            throw UpdateError.emptyRemoteData
        }

        let ordered = Dictionary(uniqueKeysWithValues: merged.keys.sorted().map { ($0, merged[$0]!) })

        lock.lock()
        let previous = map
        lock.unlock()

        if previous == ordered {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: .hardwareModelsLastUpdatedKey)
            return .unchanged(count: ordered.count)
        }

        do {
            let payload = try JSONSerialization.data(withJSONObject: ordered, options: [.prettyPrinted, .sortedKeys])
            try payload.write(to: Self.cachedFileURL, options: .atomic)
        } catch {
            throw UpdateError.writeFailed
        }

        lock.lock()
        map = ordered
        lock.unlock()

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: .hardwareModelsLastUpdatedKey)
        NotificationCenter.default.post(name: .hardwareModelsDidUpdate, object: nil)
        return .updated(count: ordered.count)
    }

    // MARK: - Loading

    private static var cachedFileURL: URL {
        let dir = FileManager.default.appSupportDirectory() ?? NSTemporaryDirectory()
        return URL(fileURLWithPath: dir).appendingPathComponent(cacheFileName)
    }

    private static func loadInitialMap() -> [String: String] {
        if let cached = loadMap(from: cachedFileURL), !cached.isEmpty {
            return cached
        }
        if let bundled = Bundle.main.url(forResource: bundledResourceName, withExtension: "json"),
           let map = loadMap(from: bundled), !map.isEmpty {
            return map
        }
        return [:]
    }

    private static func loadMap(from url: URL) -> [String: String]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }
}

func modelToName(_ model: String) -> String {
    HardwareModelStore.shared.name(for: model)
}
