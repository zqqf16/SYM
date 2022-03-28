// The MIT License (MIT)
//
// Copyright (c) 2022 zqqf16
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
import SwiftyJSON

protocol Convertor {
    static func match(_ content: String) -> Bool
    func convert(_ content: String) -> String
}

func convertor(for content: String) -> Convertor? {
    if AppleJsonConvertor.match(content) {
        return AppleJsonConvertor()
    }
    if KeepJsonConvertor.match(content) {
        return KeepJsonConvertor()
    }
    return nil
}

extension String {
    func format(_ json: JSON...) -> Self {
        return String(format: self, arguments: json.map({ $0.stringValue }))
    }
}

extension Line {
    func format(_ json: JSON...) -> Self {
        let value = String(format: self.value, arguments: json.map({ $0.stringValue }))
        return Line(value)
    }
}

struct AppleJsonConvertor: Convertor {
    static func match(_ content: String) -> Bool {
        let components = self.split(content)
        guard components.header != nil,
              let payload = components.payload
        else {
            return false
        }
        
        return payload["coalitionName"].string != nil
        || payload["crashReporterKey"].string != nil
    }
    
    private static func split(_ content: String) -> (header: JSON?, payload: JSON?) {
        var header: JSON?
        var payload: JSON?

        var lines = content.components(separatedBy: "\n")
        if let headerData = lines.removeFirst().data(using: .utf8) {
            header = try? JSON(data: headerData)
        }
        if let payloadData = lines.joined(separator: "\n").data(using: .utf8) {
            payload = try? JSON(data: payloadData)
        }
        
        return (header, payload)
    }
    
    struct Frame: ContentComponent {
        var string: String
    
        init(_ frame: JSON, index: Int, binaryImages: JSON) {
            let image = binaryImages[frame["imageIndex"].intValue]
            let address = frame["imageOffset"].intValue + image["base"].intValue
            //0   Foundation                               0x182348144 xxx + 200
            
            self.string = Line {
                String(index).padding(length: 4)
                image["name"].stringValue.padding(length: 39)
                "0x%llx ".format(address)
                if let symbol = frame["symbol"].string, let symbolLocation = frame["symbolLocation"].int {
                    "\(symbol) + \(symbolLocation)"
                } else {
                    "0x%llx + %d".format(image["base"].int64Value, frame["imageOffset"].intValue)
                }
                if let sourceFile = frame["sourceFile"].string, let sourceLine = frame["sourceLine"].int {
                    " (\(sourceFile):\(sourceLine))"
                }
            }.string
        }
    }
    
    struct Thread: ContentComponent {
        var string: String
        init(_ thread: JSON, index: Int, binaryImages: JSON) {
            self.string = String(builder: {
                if thread["name"].string != nil {
                    Line("Thread %d name:  %@").format(index, thread["name"].stringValue)
                } else if thread["queue"].string != nil {
                    Line("Thread %d name:   Dispatch queue: %@")
                        .format(index, thread["queue"].stringValue)
                }
                if thread["triggered"].boolValue {
                    Line("Thread \(index) Crashed:")
                } else {
                    Line("Thread \(index):")
                }
                for (frameIndex, frame) in thread["frames"].arrayValue.enumerated() {
                    Frame(frame, index: frameIndex, binaryImages: binaryImages)
                }
                Line.empty
            })
        }
    }
    
    struct Image: ContentComponent {
        var string: String
        
        init(_ image: JSON) {
            self.string = Line {
                "0x%llx - 0x%llx "
                    .format(image["base"].intValue, image["base"].intValue + image["size"].intValue - 1)
                "%@ %@ "
                    .format(image["name"].stringValue, image["arch"].stringValue)
                "<%@> %@"
                    .format(image["uuid"].stringValue.replacingOccurrences(of: "-", with: ""), image["path"].stringValue)
            }.string
        }
    }
    
    struct Registers: ContentComponent {
        var string: String
        
        init(_ payload: JSON) {
            let threads = payload["threads"].arrayValue
            let triggeredThread = threads.first { thread in
                thread["triggered"].boolValue
            }
            if triggeredThread == nil {
                self.string = ""
                return
            }
            
            let triggeredIndex = payload["faultingThread"].intValue
            let cpu = payload["cpuType"].stringValue
            var content = "Thread \(triggeredIndex) crashed with ARM Thread State (\(cpu)):\n"
            
            let threadState = triggeredThread!["threadState"]
            let x = threadState["x"].arrayValue
            for (index, reg) in x.enumerated() {
                let id = "x\(index)".padding(length: 6, atLeft: true)
                content.append("\(id): 0x%016X".format(reg["value"].int64Value))
                if index % 4 == 3 {
                    content.append("\n")
                }
            }
            var index = x.count % 4
            for name in ["fp", "lr", "sp", "pc", "cpsr", "far", "esr"] {
                let value = threadState[name]["value"].int64Value
                let desc = threadState[name]["description"].stringValue
                let id = "\(name)".padding(length: 6, atLeft: true)
                content.append("\(id): 0x%016X".format(value))
                if desc.count > 0 {
                    content.append(" \(desc)")
                }
                if index % 3 == 2 {
                    content.append("\n")
                }
                index += 1
            }
            content.append("\n")
            self.string = content
        }
    }
    
    func convert(_ content: String) -> String {
        let components = Self.split(content)
        guard let header = components.header,
              let payload = components.payload
        else {
            return content
        }
        
        let _P: (String) -> String = { key in
            return payload[key].stringValue
        }
        
        let _H: (String) -> String = { key in
            return header[key].stringValue
        }
        
        return String(builder: {
            Line("Incident Identifier: %@").format(_H("incident_id"))
            Line("CrashReporter Key:   %@").format(_P("crashReporterKey"))
            Line("Hardware Model:      %@").format(_P("modelCode"))
            Line("Process:             %@ [%@]").format(_P("procName"), _P("pid"))
            Line("Path:                %@").format(_P("procPath"))
            Line("Identifier:          %@").format(_P("coalitionName"))
            Line("Version:             %@ (%@)").format(_H("app_version"), _H("build_version"))
            Line("Code Type:           %@").format(_P("cpuType"))
            Line("Role:                %@").format(_P("procRole"))
            Line("Parent Process:      %@ [%@]").format(_P("parentProc"), _P("parentPid"))
            Line("Coalition:           %@ [%@]").format(_P("coalitionName"), _P("coalitionID"))
            Line.empty
            Line("Date/Time:           %@").format(_P("captureTime"))
            Line("Launch Time:         %@").format(_P("procLaunch"))
            Line("OS Version:          %@").format(_H("os_version"))
            Line("Release Type:        %@").format(payload["osVersion"]["releaseType"].stringValue)
            Line("Baseband Version:    %@").format(_P("basebandVersion"))
            Line("Report Version:      104")
            Line.empty
            Line("Exception Type:  %@ (%@)")
                .format(payload["exception"]["type"].stringValue, payload["exception"]["signal"].stringValue)
            Line("Exception Codes: %@").format(payload["exception"]["codes"].stringValue)
            //"Exception Note:      %@".format()
            Line("Termination Reason: %@ %@")
                .format(payload["termination"]["namespace"].stringValue, payload["termination"]["code"].stringValue)
            Line(payload["termination"]["details"][0].stringValue)
            if payload["vmSummary"].string != nil {
                Line("VM Region Info: \(_P("vmSummary"))")
            }
            Line.empty
            Line("Triggered by Thread:  %@".format(_P("faultingThread")))
            Line.empty
            
            let binaryImages = payload["usedImages"]
            let threads = payload["threads"].arrayValue
            for (index, thread) in threads.enumerated() {
                Thread(thread, index: index, binaryImages: binaryImages)
            }

            Line.empty
            Registers(payload)
            Line.empty
            Line("Binary Images:")
            for image in binaryImages.arrayValue {
                Image(image)
            }
            Line.empty
            Line("EOF")
            Line.empty
        })
    }
}
