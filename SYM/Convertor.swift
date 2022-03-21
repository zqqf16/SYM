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

@resultBuilder
struct CrashContentBuilder {
    static func buildBlock(_ components: String...) -> String {
        return components.joined(separator: "\n")
    }
    static func buildArray(_ components: [String]) -> String {
        return components.joined(separator: "\n")
    }
    static func buildEither(first component: String) -> String {
        component
    }
    static func buildEither(second component: String) -> String {
        component
    }
    static func buildOptional(_ component: String?) -> String {
        return component ?? ""
    }
}

@resultBuilder
struct CrashInlineBuilder {
    static func buildBlock(_ components: String...) -> String {
        return components.joined(separator: "")
    }
    static func buildArray(_ components: [String]) -> String {
        return components.joined(separator: "")
    }
    static func buildEither(first component: String) -> String {
        component
    }
    static func buildEither(second component: String) -> String {
        component
    }
    static func buildOptional(_ component: String?) -> String {
        return component ?? ""
    }
}


struct AppleJsonConvertor: Convertor {
    static func match(_ content: String) -> Bool {
        let components = self.split(content)
        return components.header != nil && components.payload != nil
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
        
        return self.buildCrash {
            "Incident Identifier: %@".format(_H("incident_id"))
            "CrashReporter Key:   %@".format(_P("crashReporterKey"))
            "Hardware Model:      %@".format(_P("modelCode"))
            "Process:             %@ [%@]".format(_P("procName"), _P("pid"))
            "Path:                %@".format(_P("procPath"))
            "Identifier:          %@".format(_P("coalitionName"))
            "Version:             %@ (%@)".format(_H("app_version"), _H("build_version"))
            "Code Type:           %@".format(_P("cpuType"))
            "Role:                %@".format(_P("procRole"))
            "Parent Process:      %@ [%@]".format(_P("parentProc"), _P("parentPid"))
            "Coalition:           %@ [%@]".format(_P("coalitionName"), _P("coalitionID"))
            ""
            "Date/Time:           %@".format(_P("captureTime"))
            "Launch Time:         %@".format(_P("procLaunch"))
            "OS Version:          %@".format(_H("os_version"))
            "Release Type:        %@".format(payload["osVersion"]["releaseType"].stringValue)
            "Baseband Version:    %@".format(_P("basebandVersion"))
            "Report Version:      104"
            ""
            "Exception Type:  %@ (%@)".format(payload["exception"]["type"].stringValue, payload["exception"]["signal"].stringValue)
            "Exception Codes: %@".format(payload["exception"]["codes"].stringValue)
            //"Exception Note:      %@".format()
            "Termination Reason: %@ %@".format(payload["termination"]["namespace"].stringValue, payload["termination"]["code"].stringValue)
            payload["termination"]["details"][0].stringValue
            if payload["vmSummary"].string != nil {
                "VM Region Info: \(payload["vmSummary"].stringValue)"
            }
            ""
            "Triggered by Thread:  %@".format(_P("faultingThread"))
            ""
            self.buildThreads(payload)
            ""
            self.buildRegisters(payload)
            ""
            self.buildImage(payload)
            ""
            "EOF"
            ""
        }
    }
    
    private func buildCrash(@CrashContentBuilder builder: ()->String) -> String {
        builder()
    }
    
    private func buildLine(@CrashInlineBuilder builder: ()->String) -> String {
        builder()
    }
    
    private func buildThreads(_ payload: JSON) -> String {
        let binaryImages = payload["usedImages"]
        let threads = payload["threads"].arrayValue
        return self.buildCrash {
            for (index, thread) in threads.enumerated() {
                if thread["name"].string != nil {
                    "Thread %d name:  %@".format(index, thread["name"].stringValue)
                } else if thread["queue"].string != nil {
                    "Thread %d name:   Dispatch queue: %@".format(index, thread["queue"].stringValue)
                }
                if thread["triggered"].boolValue {
                    "Thread \(index) Crashed:"
                } else {
                    "Thread \(index):"
                }
                for (frameIndex, frame) in thread["frames"].arrayValue.enumerated() {
                    self.build(frame: frame, index: frameIndex, binaryImages: binaryImages)
                }
                ""
            }
        }
    }
    
    private func build(frame: JSON, index: Int, binaryImages: JSON) -> String {
        let image = binaryImages[frame["imageIndex"].intValue]
        let address = frame["imageOffset"].intValue + image["base"].intValue
        //0   Foundation                               0x182348144 NSKeyValueWillChangeWithPerThreadPendingNotifications + 200
        return self.buildLine {
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
        }
    }
    
    private func buildRegisters(_ payload: JSON) -> String {
        let threads = payload["threads"].arrayValue
        let triggeredThread = threads.first { thread in
            thread["triggered"].boolValue
        }
        if triggeredThread == nil {
            return ""
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
        
        return content
    }
    
    private func buildImage(_ payload: JSON) -> String {
        /*
         Binary Images:
         0x18232f000 -        0x182635fff Foundation arm64e  <9618b2f2a4c23e07b7eed8d9e1bdeaec> /System/Library/Frameworks/Foundation.framework/Foundation
         */
        let binaryImages = payload["usedImages"].arrayValue
        return self.buildCrash {
            "Binary Images:"
            for image in binaryImages {
                self.buildLine {
                    "0x%llx - 0x%llx ".format(image["base"].intValue, image["base"].intValue + image["size"].intValue - 1)
                    "%@ %@ ".format(image["name"].stringValue, image["arch"].stringValue)
                    "<%@> %@".format(image["uuid"].stringValue.replacingOccurrences(of: "-", with: ""), image["path"].stringValue)
                }
            }
        }
    }
}
