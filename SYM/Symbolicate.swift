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


protocol SymDelegate: class {
    func dsym(forUuid uuid: String) -> String?
    func didFinish(_ crash: Crash)
}

protocol Sym {
    weak var delegate: SymDelegate? { get set }
    init(delegate: SymDelegate)
    func symbolicate(_ crash: Crash)
}


class Atos: Sym {
    
    static let queue: OperationQueue = OperationQueue().then {
        $0.maxConcurrentOperationCount = 4
    }
    
    weak var delegate: SymDelegate?
    var crash: Crash?
    
    var numberOfTask: Int = 0
    
    required init(delegate: SymDelegate) {
        self.delegate = delegate
    }
    
    func symbolicate(_ crash: Crash) {
        guard crash.images != nil && crash.images!.count != 0 else {
            self.delegate?.didFinish(crash)
            return
        }
        
        self.crash = crash
        
        var operations = [Operation]()
        for image in crash.images!.values {
            if let task = self.symbolicate(image) {
                operations.append(task)
            }
        }
        
        self.numberOfTask = operations.count
        
        Atos.queue.addOperations(operations, waitUntilFinished: false)
    }
    
    func taskCompleted() {
        self.numberOfTask -= 1
        if self.numberOfTask <= 0 {
            asyncMain {
                self.delegate?.didFinish(self.crash!)
            }
        }
    }
    
    func symbolicate(_ image: Image) -> SubProcess? {
        guard (image.backtrace != nil && image.backtrace!.count > 0) else {
            return nil
        }
        guard let binary = image.name else {
            return nil
        }
        guard let uuid = image.uuid else {
            return nil
        }
        guard let dsym = self.delegate?.dsym(forUuid: uuid) else {
            return nil
        }
        guard let load = image.loadAddress else {
            return nil
        }

        var addresses = [String]()
        for frame in image.backtrace! {
            addresses.append(frame.address)
        }
        
        if addresses.count == 0 {
            return nil
        }
        
        let task = SubProcess(loadAddress: load,
                              addressess: addresses,
                              dsym: dsym,
                              binary: binary,
                              arch: self.crash!.arch)
        
        task.completionBlock = {
            if task.isCancelled {
                return
            }
            
            guard let result = task.atosResult() else {
                return
            }
            
            asyncMain {
                for (index, symbol) in result.enumerated() {
                    image.backtrace![index].symbol = symbol
                }
                self.taskCompleted()
            }
        }
        
        return task
    }
}


class AppleTool: Sym {
    weak var delegate: SymDelegate?

    required init(delegate: SymDelegate) {
        self.delegate = delegate
    }
    
    func symbolicate(_ crash: Crash) {
        let path = FileManager.default.temporaryPath()
        do {
            try crash.content.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            return
        }
        
        let task = SubProcess(crashPath: path)
        task.completionBlock = {
            if task.result != nil {
                let newCrash = Parser.parse(task.result!) ?? crash
                self.delegate?.didFinish(newCrash)
            } else {
                self.delegate?.didFinish(crash)
            }
        }
        
        globalTaskQueue.addOperation(task)
    }
}
