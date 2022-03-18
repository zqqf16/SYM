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

// MARK: - SubProcess
extension SubProcess {
    static func atos(loadAddress: String,
                     addressess: [String],
                     dsym: String,
                     arch: String = "arm64") -> [String]? {
        let cmd = "/usr/bin/atos"
        let args = ["-arch", arch, "-o", dsym, "-l", loadAddress] + addressess
        let process = SubProcess(cmd: cmd, args: args)
        process.run()
        let result = process.output
        if result.count > 0 {
            return result.components(separatedBy: "\n").filter {
                (content) -> Bool in
                return content.count > 0
            }
        }
        return nil
    }
    
    static func atos(_ image: Binary, dsym: String? = nil) -> [String: String]? {
        guard let loadAddress = image.loadAddress,
              let dsym = dsym,
              let arch = image.arch,
              let frames = image.backtrace
        else {
            return nil
        }
        
        let addresses = frames.map { $0.address }
        if let result = SubProcess.atos(loadAddress: loadAddress,
                                        addressess: addresses,
                                        dsym: dsym,
                                        arch: arch) {
            return Dictionary(uniqueKeysWithValues: zip(addresses, result))
        }
        
        return nil
    }
    
    static func symbolicatecrash(crash: String, dsyms: [String]?) -> String? {
        let path = FileManager.default.temporaryPath()
        do {
            try crash.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            return nil
        }
        
        let cmd = Bundle.main.path(forResource: "symbolicatecrash", ofType: nil)
        if cmd == nil {
            return nil
        }
        
        var args = [path]
        dsyms?.forEach({ (dsymPath) in
            args.append(contentsOf: ["-d", dsymPath])
        })
        let process = SubProcess(cmd: cmd!, args: args)
        process.run()
        return process.output
    }
}


protocol Symbolicator {
    func symbolicate(crash: Crash, dsymPaths: [String]?) -> String
}

struct SymbolicateCrash: Symbolicator {
    func symbolicate(crash: Crash, dsymPaths: [String]?) -> String {
        if let content = SubProcess.symbolicatecrash(crash: crash.content, dsyms: dsymPaths), content.count > 0 {
            return content
        }
        
        return crash.content
    }
}

struct Atos: Symbolicator {
    func symbolicate(crash: Crash, dsymPaths: [String]?) -> String {
        //TODO: Only support the first binary image now
        
        guard let image = crash.binaryImages.first, image.isValid else {
            return crash.content
        }
        
        image.fix()
        guard let result = SubProcess.atos(image, dsym: dsymPaths?.first) else {
            return crash.content
        }
        
        var newContent = crash.content
        for frame in image.backtrace! {
            if let symbol = result[frame.address] {
                var newFrame = frame
                newFrame.symbol = symbol
                newContent = newContent.replacingOccurrences(of: frame.raw, with: newFrame.description)
            }
        }
        
        return newContent
    }
}

extension Crash {
    func symbolicate(dsymPaths: [String]?) -> String {
        let symbolicator: Symbolicator = self.symbolicateMethod == .atos ? Atos() : SymbolicateCrash()
        return symbolicator.symbolicate(crash: self, dsymPaths: dsymPaths)
    }
}
