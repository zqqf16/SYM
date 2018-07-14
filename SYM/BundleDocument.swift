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
/*

import Cocoa


class BundleDocument: CrashDocument {
    var info: [String: Any]?
    
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        if typeName != "com.apple.dt.document.xccrashpoint" {
            return
        }
        
        self.crashFile.children = []

        if let wrapper = fileWrapper.fileWrappers {
            if let info = wrapper["Info.json"] {
                self.readInfo(from: info)
            }
            
            if let logs = wrapper["DistributionInfos"]?.fileWrappers?["all"]?.fileWrappers?["Logs"] {
                self.readCrashes(from: logs)
            }
        }
        
        //self.openCrash(file: self.crashFile)
    }
    
    func readInfo(from fileWrapper: FileWrapper) {
        guard let data = fileWrapper.regularFileContents else {
            return
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            self.info = json
            if let name = json?["DefaultName"] as? String {
                self.crashFile.name = name
            }
        }
    }
    
    func readCrashes(from dirWrapper: FileWrapper) {
        guard let fileWrappers = dirWrapper.fileWrappers else {
            return
        }
        for (_, f) in fileWrappers {
            let cf = CrashFile.init(from: f)
            self.crashFile.children?.append(cf)
        }
    }

    override class var autosavesInPlace: Bool {
        return false
    }
    
    /*
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        return FileWrapper()
    }
    */
}
*/
