// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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

func modelToName(_ model: String) -> String {
    let modelMap: [String: String] = [
        "i386"      : "Simulator",
        "x86_64"    : "Simulator",
        "iPod1,1"   : "iPod 1",
        "iPod2,1"   : "iPod 2",
        "iPod3,1"   : "iPod 3",
        "iPod4,1"   : "iPod 4",
        "iPod5,1"   : "iPod 5",
        "iPad2,1"   : "iPad 2",
        "iPad2,2"   : "iPad 2",
        "iPad2,3"   : "iPad 2",
        "iPad2,4"   : "iPad 2",
        "iPad2,5"   : "iPad Mini 1",
        "iPad2,6"   : "iPad Mini 1",
        "iPad2,7"   : "iPad Mini 1",
        "iPhone3,1" : "iPhone 4",
        "iPhone3,2" : "iPhone 4",
        "iPhone3,3" : "iPhone 4",
        "iPhone4,1" : "iPhone 4S",
        "iPhone5,1" : "iPhone 5",
        "iPhone5,2" : "iPhone 5",
        "iPhone5,3" : "iPhone 5C",
        "iPhone5,4" : "iPhone 5C",
        "iPad3,1"   : "iPad 3",
        "iPad3,2"   : "iPad 3",
        "iPad3,3"   : "iPad 3",
        "iPad3,4"   : "iPad 4",
        "iPad3,5"   : "iPad 4",
        "iPad3,6"   : "iPad 4",
        "iPhone6,1" : "iPhone 5S",
        "iPhone6,2" : "iPhone 5S",
        "iPad4,2"   : "iPad Air 1",
        "iPad5,4"   : "iPad Air 2",
        "iPad4,4"   : "iPad Mini 2",
        "iPad4,5"   : "iPad Mini 2",
        "iPad4,6"   : "iPad Mini 2",
        "iPad4,7"   : "iPad Mini 3",
        "iPad4,8"   : "iPad Mini 3",
        "iPad4,9"   : "iPad Mini 3",
        "iPad6,3"   : "iPad Pro 9.7",
        "iPad6,4"   : "iPad Pro 9.7 cellular",
        "iPad6,12"  : "iPad 5",
        "iPad6,7"   : "iPad Pro 12.9",
        "iPad6,8"   : "iPad Pro 12.9 cellular",
        "iPad7,1"   : "iPad Pro 12.9",
        "iPad7,2"   : "iPad Pro 12.9 cellular",
        "iPhone7,1" : "iPhone 6 Plus",
        "iPhone7,2" : "iPhone 6",
        "iPhone8,1" : "iPhone 6S",
        "iPhone8,2" : "iPhone 6S Plus",
        "iPhone8,4" : "iPhone SE",
        "iPhone9,1" : "iPhone 7",
        "iPhone9,2" : "iPhone 7plus",
        "iPhone9,3" : "iPhone 7",
        "iPhone9,4" : "iPhone 7 Plus",
        "iPhone10,1" : "iPhone 8",
        "iPhone10,2" : "iPhone 8 Plus",
        "iPhone10,3" : "iPhone X",
        "iPhone10,4" : "iPhone 8",
        "iPhone10,5" : "iPhone 8 Plus",
        "iPhone10,6" : "iPhone X",
    ]
    if let name = modelMap[model] {
        return name
    }
    
    return model
}
