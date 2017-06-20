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


/*
protocol Doctor {
    func fix(_ crash: CrashInfo) -> CrashInfo
}

class AddressDoctor: Doctor {
    func fix(_ crash: CrashInfo) -> CrashInfo {
        for (_, image) in crash.images {
            if let loadAddress = image.loadAddress {
                for frame in image.backtrace {
                    self.fix(frame: frame, loadAddress: loadAddress)
                }
            }
        }
        
        return crash
    }
    
    func fix(frame: CrashInfo.Frame, loadAddress: String) {
        guard frame.address.hexaToDecimal == loadAddress.hexaToDecimal,
            frame.symbol != nil,
            frame.symbol!.hasPrefix("+")
            else {
                return
        }
        
        let list = frame.symbol!.components(separatedBy: " ")
        if list.count < 2 {
            return
        }
        
        guard let offset = Int(list[1]) else {
            return
        }
        let newAddress = String(frame.address.hexaToDecimal + offset, radix: 16)
        frame.address = "0x" + newAddress.leftPadding(toLength: 16, withPad: "0")
        frame.symbol = "+ 0"
    }
}
 
*/
 
