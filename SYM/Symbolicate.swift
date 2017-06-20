// The MIT License (MIT)
//
// Copyright (c) 2017 zqqf16
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
                     dSym: String,
                     arch: String = "arm64") -> [String]? {
        let cmd = "/usr/bin/atos"
        let args = ["-arch", arch, "-o", dSym, "-l", loadAddress] + addressess
        if let result = execute(cmd: cmd, args: args) {
            return result.components(separatedBy: "\n").filter {
                (content) -> Bool in
                return content.count > 0
            }
        }
        
        return nil
    }
    
    static func atos(_ image: Crash.Image, dSYM: String? = nil) -> [String: String]? {
        guard let loadAddress = image.loadAddress,
              let dsym = dSYM,
              let arch = image.arch,
              let frames = image.frames
        else {
            return nil
        }
        
        let addresses = frames.map { $0.address }
        if let result = SubProcess.atos(loadAddress: loadAddress,
                                        addressess: addresses,
                                        dSym: dsym,
                                        arch: arch) {
            return Dictionary(uniqueKeysWithValues: zip(addresses, result))
        }
        
        return nil
    }
    
    static func symbolicatecrash(crash: String) -> String? {
        let path = FileManager.default.temporaryPath()
        do {
            try crash.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            return nil
        }
        
        let cmd = Bundle.main.path(forResource: "symbolicatecrash", ofType: nil)
        assert(cmd != nil)
        
        let args = [path]
        return execute(cmd: cmd!, args: args)
    }
}

// MARK: - Symbolicate
func symbolicate(crash: Crash, dSYM: String? = nil) -> String {
    if let content = crash.toStandard() {
        return SubProcess.symbolicatecrash(crash: content) ?? content
    } else if let image = crash.binaryImage(), let result = SubProcess.atos(image) {
        return crash.backfill(symbols: result)
    }
    
    return crash.content
}
