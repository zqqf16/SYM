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

protocol Event {
    static var identifier: String { get }
}

extension Event {
    static var identifier: String {
        return "\(Self.self)"
    }
}

class EventHandler<E> {
    typealias Block = (E) -> Void
    
    weak var target: AnyObject?
    
    var block: Block?
    var queue: DispatchQueue?
    
    init(target: AnyObject) {
        self.target = target
    }
    
    func async(_ queue: DispatchQueue = DispatchQueue.main, _ block: @escaping Block) {
        self.queue = queue
        self.block = block
    }
    
    func sync(_ block: @escaping Block) {
        self.block = block
    }
    
    func handle(_ event: E) -> Bool {
        guard let block = self.block, self.target != nil else {
            return false
        }
        
        if let queue = self.queue {
            queue.async {
                block(event)
            }
        } else {
            block(event)
        }
        
        return true
    }
}

class EventBus {
    static let shared = EventBus()
    
    private var handlers: [String: [Any]] = [:]
    
    private let syncKey = 0
    private func synchronized(_ closure: ()->Void) {
        objc_sync_enter(self.syncKey)
        closure()
        objc_sync_exit(self.syncKey)
    }
    
    func sub<E:Event>(_ target: AnyObject, for eventType: E.Type) -> EventHandler<E> {
        let handler = EventHandler<E>(target: target)
        self.synchronized {
            var handlers = self.handlers[eventType.identifier] ?? []
            handlers.append(handler)
            self.handlers[eventType.identifier] = handlers
        }
        return handler
    }
    
    func post<E:Event>(_ event: E) {
        self.synchronized {
            if var handlers = self.handlers[E.identifier] {
                handlers.removeAll { (h) -> Bool in
                    if let handler = h as? EventHandler<E> {
                        return !handler.handle(event)
                    }
                    return false
                }
                self.handlers[E.identifier] = handlers
            }
        }
    }
}
