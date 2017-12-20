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

extension Crash.Frame {
    func fixed(withLoadAddress loadAddress: String) -> Crash.Frame {
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

extension Crash {
    func fixed() -> Crash {
        guard let image = self.binaryImage(),
              let loadAddress = image.loadAddress
        else {
            return self
        }
        
        let lines = self.content.components(separatedBy: "\n")
        var newLines: [String] = []
        for line in lines {
            if var frame = Frame.parse(fromLine: line) {
                if frame.image == image.name {
                    frame = frame.fixed(withLoadAddress: loadAddress)
                }
                newLines.append(frame.description)
            } else {
                newLines.append(line)
            }
        }
        
        let newContent = newLines.joined(separator: "\n")
        return Crash.parse(fromContent: newContent)
    }
}
