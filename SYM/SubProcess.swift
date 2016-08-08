// The MIT License (MIT)
//
// Copyright (c) 2016 zqqf16
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


// MARK: - Global task queue

let globalTaskQueue = NSOperationQueue().then {
    $0.maxConcurrentOperationCount = 4
}


// MARK: - Sub process task operation

class SubProcess: NSOperation {
    
    var cmd: String
    var arguments: [String]?
    var result: String?

    init(cmd: String, arguments: [String]?) {
        self.cmd = cmd
        self.arguments = arguments
        super.init()
    }

    override func main() {
        if self.cancelled {
            return
        }

        let pipe = NSPipe()

        let task = NSTask().then {
            $0.launchPath = cmd
            $0.arguments = arguments
            $0.standardOutput = pipe
        }

        task.launch()
        
        let output = pipe.fileHandleForReading
        let data = output.readDataToEndOfFile()
        self.result = String(data: data, encoding: NSUTF8StringEncoding)
    }
}


// MARK: atos

extension SubProcess {
    convenience init(loadAddress: String, addressess: [String], dsym: String,
         binary: String, arch: String = "arm64") {
        let cmd = "/usr/bin/atos"
        let arguments = ["-arch", arch, "-o", dsym, "-l", loadAddress] + addressess
        
        self.init(cmd: cmd, arguments: arguments)
    }
    
    func atosResult() -> [String]? {
        guard let result = self.result else {
            return nil
        }

        let lines = result.componentsSeparatedByString("\n").filter {
            (content) -> Bool in
            return content.characters.count > 0
        }

        return lines
    }
}


// MARK: dwarfdump

extension SubProcess {
    convenience init(dsymPath: String) {
        let cmd = "/usr/bin/dwarfdump"
        let arguments = ["--uuid", dsymPath]
        self.init(cmd: cmd, arguments: arguments)
    }
    
    func dwarfResult() -> [String]? {
        guard let result = self.result else {
            return nil
        }
        
        let lines = result.componentsSeparatedByString("\n").filter {
            (content) -> Bool in
            if content.characters.count == 0 {
                return false
            }
            
            return content.hasPrefix("UUID: ")
        }
        
        return lines.map({ (line) -> String in
            return line.componentsSeparatedByString(" ")[1]
        })
    }
}


// MARK: symbolicatecrash

extension SubProcess {
    convenience init(crashPath: String) {
        let cmd = NSBundle.mainBundle().pathForResource("symbolicatecrash", ofType: nil)
        assert(cmd != nil)

        let arguments = [crashPath]
        self.init(cmd: cmd!, arguments: arguments)
    }
}

// MARK: - GCD

func asyncGlobal(block: dispatch_block_t) {
    dispatch_async(dispatch_get_global_queue(0, 0), block)
}

func asyncMain(block: dispatch_block_t) {
    dispatch_async(dispatch_get_main_queue(), block)
}
