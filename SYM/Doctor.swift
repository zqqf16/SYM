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

extension Frame {
    func fixed(withLoadAddress loadAddress: String) -> Frame {
        guard self.address.hexaToDecimal == loadAddress.hexaToDecimal,
            self.symbol != nil,
            self.symbol!.hasPrefix("+")
            else {
                return self
        }
        
        let list = self.symbol!.components(separatedBy: " ")
        if list.count < 2 {
            return self
        }
        
        guard let offset = Int(list[1]) else {
            return self
        }
        
        var newFrame = self
        let newAddress = String(self.address.hexaToDecimal + offset, radix: 16)
        newFrame.address = "0x" + newAddress.leftPadding(toLength: 16, withPad: "0")
        newFrame.symbol = "+ 0"
        
        return newFrame
    }
}

extension Binary {
    func fix() {
        guard let loadAddress = self.loadAddress, let backtrace = self.backtrace else {
            return
        }
        
        var newBacktrace: [Frame] = []
        for frame in backtrace {
            let newFrame = frame.fixed(withLoadAddress: loadAddress)
            newBacktrace.append(newFrame)
        }

        self.backtrace = newBacktrace
    }
}
