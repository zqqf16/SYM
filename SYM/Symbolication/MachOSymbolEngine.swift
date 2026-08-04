// The MIT License (MIT)
//
// Copyright (c) 2022 zqqf16
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
import MachOKit

struct MachOSymbolEngine: SymbolEngine {
    func symbolicate(_ report: CrashReport, dsymPaths: [String: String]) async -> CrashReport {
        var updated = report
        let imagesByUUID = Dictionary(
            uniqueKeysWithValues: report.binaryImages.compactMap { image -> (String, BinaryImage)? in
                guard let uuid = CrashUUID.normalize(image.uuid) else {
                    return nil
                }
                return (uuid, image)
            }
        )

        var machOCache = [String: MachOFile]()

        updated.updateFrames { frame in
            guard !frame.isSymbolicated,
                  let frameUUID = CrashUUID.normalize(frame.imageUUID),
                  let dsymPath = dsymPaths[frameUUID],
                  let image = imagesByUUID[frameUUID],
                  let loadAddress = image.loadAddress ?? frame.loadAddress
            else {
                return frame
            }

            let dwarfPath = DsymLocator.resolveDwarfBinaryPath(from: dsymPath) ?? dsymPath
            guard let machO = machOCache[frameUUID] ?? loadMachO(
                path: dwarfPath,
                expectedUUID: frameUUID,
                arch: image.arch ?? report.arch
            ) else {
                return frame
            }
            machOCache[frameUUID] = machO

            let fileOffset = frame.imageOffset ?? (frame.address &- loadAddress)
            guard fileOffset <= Int.max else {
                return frame
            }

            guard let symbol = machO.closestSymbol(at: Int(fileOffset)) else {
                return frame
            }

            var resolved = frame
            resolved.symbol = symbol.name
            resolved.symbolLocation = Int(fileOffset) - symbol.offset
            return resolved
        }

        return updated
    }

    private func loadMachO(path: String, expectedUUID: String, arch: String?) -> MachOFile? {
        let url = URL(fileURLWithPath: path)
        guard let loaded = try? MachOKit.loadFromFile(url: url) else {
            return nil
        }

        switch loaded {
        case let .machO(machOFile):
            guard uuidMatches(path: path, expectedUUID: expectedUUID) else {
                return nil
            }
            return machOFile
        case let .fat(fatFile):
            guard let machOFiles = try? fatFile.machOFiles() else {
                return nil
            }
            if let arch, let matched = machOFiles.first(where: { matchesArch($0, arch: arch) && uuidMatches(path: path, expectedUUID: expectedUUID) }) {
                return matched
            }
            return machOFiles.first { _ in uuidMatches(path: path, expectedUUID: expectedUUID) }
        }
    }

    private func uuidMatches(path: String, expectedUUID: String) -> Bool {
        guard let expected = CrashUUID.normalize(expectedUUID),
              let pairs = SubProcess.dwarfdump([path])
        else {
            return false
        }
        return pairs.contains { CrashUUID.normalize($0.0) == expected }
    }

    private func matchesArch(_ machO: MachOFile, arch: String) -> Bool {
        let normalized = CrashArch.normalize(arch)?.lowercased() ?? arch.lowercased()
        let cpuType = machO.header.cpuType
        switch normalized {
        case "arm64", "arm64e":
            return cpuType == .arm64
        case "arm", "armv7", "armv7s", "armv6":
            return cpuType == .arm
        case "x86_64":
            return cpuType == .x86_64
        case "i386":
            return cpuType == .i386
        default:
            return String(describing: cpuType).lowercased().contains(normalized)
        }
    }
}
