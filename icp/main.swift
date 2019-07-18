// The MIT License (MIT)
//
// Copyright (c) 2017 - 2019 zqqf16
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

//file:///private/var/mobile/Containers/Data/Application/F53C16D2-5D61-4028-A606-8C6D9DEB44F4/tmp/5fbd0d34068e78cb3042a0676dc44d5e-846930886.zip

let arguments = CommandLine.arguments
if arguments.count < 4 {
    print("Usage: icp app.id file:///path/to/file destnation");
    exit(1)
}

let path = arguments[2]
var srcPath: String
let components = path.split(separator: "/")
if path.starts(with: "file://") {
    var index = 0
    for c in components {
        if c == "Application" {
            index += 2
            break
        }
        index += 1
    }
    if index >= components.count {
        print("Invalid file path \(path)")
        exit(2)
    }
    srcPath = components[index...].joined(separator: "/")
} else {
    srcPath = path
}

let currentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let destURL = URL(fileURLWithPath: "\(arguments[3])/\(components.last!)", relativeTo: currentURL)

let lockdown = MDLockdown(udid: nil)
let houseArrest = MDHouseArrest(lockdown: lockdown, appID: arguments[1])
let afc = MDAfcClient.fileClient(with: houseArrest)
guard let data = afc.read(srcPath) else {
    print("Cannot read file: \(path)")
    exit(4)
}

try data.write(to: destURL)
