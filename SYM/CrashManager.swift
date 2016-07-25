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

let CMOpenCrashFilesNotification = "CMOpenCrashFilesNotification"
let CMDidOpenCrashFilesNotification = "CMDidOpenCrashFilesNotification"


@objc class CrashManager: NSObject {
    
    static let sharedInstance = CrashManager()
    
    var crashes = [Crash]()
    var parsers: [Parser] = [FrameParser(), UmentMetaParser(), AppleParser()]
    var batchParsers: [BatchParser] = [CSVParser()]
    
    
    override init() {
        super.init()
        self.registerNotifications()
    }
    
    func registerNotifications() {
        let nt = NSNotificationCenter.defaultCenter()
        nt.addObserver(self, selector: #selector(open), name: CMOpenCrashFilesNotification, object: nil)
    }

    
    // MARK: - New File
    
    func new(crash: Crash? = nil) {
        let newCrash = crash ?? Crash(content: nil)
        self.crashes.insert(newCrash, atIndex: 0)
        NSNotificationCenter.defaultCenter().postNotificationName(CMDidOpenCrashFilesNotification, object: crash)
    }

    // MARK: - Open File
    
    func open(files: [String]) {
        for path in files {
            guard let type = typeOfFile(path) else {
                continue
            }

            switch type {
            case .Crash:
                self.openCrash(path)
            case .CSV:
                self.openCSV(path)
            default:
                continue
            }
        }
    }

    func parseCrash(content: String?) -> Crash {
        let crash = Crash(content: content)
        self.parseCrash(crash)
        return crash
    }
    
    func parseCrash(origin: Crash) {
        for parser in self.parsers {
            parser.parse(origin)
            if origin.isValid() {
                break
            }
        }
    }

    func openCrash(file: String) {
        asyncGlobal {
            let raw: String
            do {
                raw = try String(contentsOfFile: file)
            } catch {
                return
            }
            let crash = self.parseCrash(raw)
            crash.filePath = file

            asyncMain {
                self.crashes.insert(crash, atIndex: 0)
                NSNotificationCenter.defaultCenter().postNotificationName(CMDidOpenCrashFilesNotification, object: crash)
            }
        }
    }

    func openCSV(file: String) {
        asyncGlobal {
            let raw: String
            do {
                raw = try String(contentsOfFile: file)
            } catch {
                return
            }
            
            var crashes: [Crash]?
            for parser in self.batchParsers {
                crashes = parser.parse(raw)
                if crashes != nil && crashes!.count > 0 {
                    break
                }
            }
            
            if crashes == nil || crashes!.count == 0 {
                return
            }
            
            for crash in crashes! {
                self.parseCrash(crash)
                crash.filePath = file
            }
            
            asyncMain({
                self.crashes = crashes! + self.crashes
                NSNotificationCenter.defaultCenter().postNotificationName(CMDidOpenCrashFilesNotification, object: crashes)
            })
        }
    }
}


// MARK: - Symbolicate

extension CrashManager {
    func symbolicate(crash: Crash, withDsym dsym: String, complation:(Crash->Void)) {
        if crash.backtrace.count == 0 {
            complation(crash)
            return
        }
        
        var indexes = [Int]()
        var addresses = [String]()
        
        for (index, bt) in crash.backtrace {
            if bt.image == crash.binary! {
                indexes.append(index)
                addresses.append(bt.address)
            }
        }
        
        if addresses.count == 0 {
            complation(crash)
            return
        }
        
        let task = SubProcess(loadAddress: crash.loadAddress!,
                              addressess: addresses,
                              dsym: dsym,
                              binary: crash.binary!,
                              arch: crash.arch)
        task.completionBlock = {
            defer {
                complation(crash)
            }
            
            if task.cancelled {
                return
            }
            
            guard let result = task.atosResult() else {
                return
            }
            
            if result.count != addresses.count {
                return
            }
            
            for (index, symbol) in result.enumerate() {
                if index >= indexes.count {
                    break
                }
                let btIndex = indexes[index]
                let bt = crash.backtrace[btIndex]!
                bt.symbol = symbol
            }
        }
        
        globalTaskQueue.addOperation(task)
    }
}


class CrashFileManagerOld {
    
    // Shared instance
    static let sharedInstance = CrashFileManagerOld()
    
    class func defaultManager() -> CrashFileManagerOld {
        return self.sharedInstance
    }
    
    // All opened crashes
    var crashes = [Crash]()

    // MARK: Private properties
    private var observers = [AnyObject]()
    private lazy var operationQueue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    
    private var notifications = []
    
    // MARK: Init and deinit

    
    deinit {
        let nc = NSNotificationCenter.defaultCenter()
        for observer in observers {
            nc.removeObserver(observer)
        }
    }
    
    // MARK: Notification Handler
    func handleNotifications(notification: NSNotification) {
        guard let files = notification.object as? [String] else {
            return
        }

        switch notification.name {
        case CMOpenCrashFilesNotification:
            self.open(files)
        default:
            break
        }
    }
    
    func isCSVFile(path: String) -> Bool {
        let ext = NSURL(fileURLWithPath: path).pathExtension
        if ext == "csv" {
            return true
        }
        return false
    }
    
    private func trimCSVCrashInfo(origin: String) -> String {
        return origin.stringByReplacingOccurrencesOfString("\"\"", withString: "").stringByReplacingOccurrencesOfString(",", withString: "\n").stringByReplacingOccurrencesOfString("\\t", withString: "\t").stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "[]"))
    }

    func readCSVFile(raw: String) -> [Crash]? {
        //24
        let csv = CSwiftV(string: raw)
        if csv.headers.count != 24 {
            return nil
        }
        
        var result = [Crash]()
        
        for row in csv.rows {
            guard let str: String? = row[6] else {
                continue
            }
            
            let crash = Crash(content: trimCSVCrashInfo(str!))
            result.append(crash)
        }
        
        if result.count > 0 {
            return result
        }
        
        return nil
    }

    func open(files: [String]) {
        if files.count == 0 {
            return
        }
        
        var crashes = [Crash]()
        for path in files {
            let raw: String
            do {
                raw = try String(contentsOfFile: path)
            } catch {
                continue
            }

            if self.isCSVFile(path) {
                if let result = self.readCSVFile(raw) {
                    crashes = result + crashes
                }
                continue
            }
            
            let crash = Crash(content: raw)
            crash.filePath = path
            crashes.append(crash)
        }
        
        if crashes.count == 0 {
            return
        }
        
        for crash in crashes {
            self.crashes.insert(crash, atIndex: 0)
        }

        dispatch_async(dispatch_get_main_queue()) {
            NSNotificationCenter.defaultCenter().postNotificationName(CMOpenCrashFilesNotification, object: crashes)
        }
    }
}