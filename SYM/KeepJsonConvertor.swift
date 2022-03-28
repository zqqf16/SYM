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
import Darwin

struct KeepJsonConvertor: Convertor {
    static func match(_ content: String) -> Bool {
        guard let data = content.data(using: .utf8),
              let payload = try? JSON(data: data)
        else {
            return false
        }
        
        return payload["trace"].dictionary != nil
        && payload["app_package_name"].string != nil
        && payload["trace"]["threads"].array != nil
    }
    
    struct Frame: ContentComponent {
        var string: String = ""
        
        init(_ frame: JSON, index: Int) {
            let address = frame["load_address"].int64Value
            self.string = ""
            self.string.append("\(index)".padding(length: 4))
            self.string.append(frame["image_name"].stringValue.padding(length: 38))
            self.string.append("0x%llx ".format(address))
            self.string.append(self.parseSymbol(frame))
            self.string.append("\n")
        }
        
        func parseSymbol(_ frame: JSON) -> String {
            let loadAddress = frame["address"].int64Value
            let offset = frame["address"].intValue
            if let lineShowStr = frame["line_show_str"].string {
                let re = try! Regex("\\d+ \\d+ \\+ \\d+")
                //5417385984 5430273043 + 12887059
                if re.matches(in: lineShowStr) == nil {
                    return lineShowStr
                }
            }
            var symbol: String = ""
            if frame["log_symbol_name"].string != nil {
                if frame["log_symbol_name"].stringValue == "<redacted>" {
                    symbol = "0x%llx + %ld".format(loadAddress, offset)
                } else {
                    symbol = "%@".format(frame["log_symbol_name"])
                }
            } else {
                symbol = "0x%llx + %ld".format(loadAddress, offset)
            }
            if !frame["file_name"].stringValue.isEmpty {
                symbol = "\(symbol) %@: %@".format(frame["file_name"], frame["line_num"])
            }
            return symbol
        }
    }
    
    struct Thread: ContentComponent {
        var string: String
        init(_ thread: JSON) {
            let index = thread["index"].intValue

            self.string = String(builder: {
                if thread["thread_name"].string != nil {
                    Line("Thread \(index) name:  %@").format(thread["name"])
                } else if thread["dispatch_queue"].string != nil {
                    Line("Thread \(index) name:   Dispatch queue: %@")
                        .format(thread["dispatch_queue"])
                }
                
                Line("Thread \(index) \(thread["thread_type"].stringValue):")
                for (frameIndex, frame) in thread["thread_stack"].arrayValue.enumerated() {
                    Frame(frame, index: frameIndex)
                }
                Line.empty
            })
        }
    }
    
    struct Image: ContentComponent {
        var string: String
        
        init(_ image: JSON, arch: String = "arm64") {
            self.string = Line {
                "0x%llx - 0x%llx "
                    .format(image["address"].int64Value, "0xffffffffff") //fake
                "%@ \(arch) "
                    .format(image["image_name"])
                "<%@> "
                    .format(image["uuid"])
                if image["is_key"].boolValue {
                    // fake path
                    "/var/containers/Bundle/Application/%@"
                        .format(image["image_name"])
                } else {
                    "/"
                }
            }.string
        }
    }
    
    func convert(_ content: String) -> String {
        guard let data = content.data(using: .utf8),
              let payload = try? JSON(data: data)
        else {
            return content
        }
        
        let trace = payload["trace"]
        let system = trace["systemMsg"]
        return String(builder: {
            Line("Incident Identifier: %@").format(trace["uuid"])
            Line("Hardware Model:      %@").format(system["machine"])
            Line("Process:             %@").format(system["CFBundleExecutable"])
            //Line("Path:                %@").format(_P("procPath"))
            Line("Identifier:          %@").format(system["CFBundleIdentifier"])
            Line("Version:             %@ (%@)")
                .format(system["CFBundleShortVersionString"], system["CFBundleVersion"])
            Line("Code Type:           %@").format(system["cpu_arch"])
            if system["application_stats"]["application_in_foreground"].boolValue {
                Line("Role:                Foreground")
            } else {
                Line("Role:                Background")
            }
            Line("Coalition:           %@").format(system["CFBundleIdentifier"])
            Line.empty
            Line("Date/Time:           %@").format(system["app_start_time"]) //TODO
            Line("Launch Time:         %@").format(system["boot_time"])
            //iPhone OS 15.2.1 (19C63)
            Line("OS Version:          iPhone OS %@ (%@)")
                .format(system["system_version"], system["os_version"])
            Line("Release Type:        User")
            Line("Baseband Version:    2.23.02")
            Line("Report Version:      104")
            Line.empty
            Line("Exception Type:  %@ (%@)")
                .format(trace["errorMsg"]["mach"]["exception_name"], trace["errorMsg"]["signal"]["name"])
            Line("Exception Codes: %@ %@")
                .format(trace["errorMsg"]["mach"]["code"], trace["errorMsg"]["mach"]["subcode"])
            Line("Termination Reason: %@").format(trace["crash_info_message"])
            Line(trace["diagnosis"].stringValue)
            Line.empty
            if let index = self.parseCrashedThread(from: payload) {
                Line("Triggered by Thread:  \(index)")
            }
            Line.empty
            
            Line("Last Exception Backtrace")
            for (index, frame) in payload["key_stack"].arrayValue.enumerated() {
                Frame(frame, index: index)
            }
            
            Line.empty
            for thread in trace["threads"].arrayValue {
                Thread(thread)
            }
            
            Line("Binary Images:")
            let arch = self.parseArch(from: payload)
            for image in self.parseImages(from: payload) {
                Image(image, arch: arch)
            }
            Line.empty
            Line("EOF")
            Line.empty
        })
    }
    
    private func parseCrashedThread(from payload: JSON) -> String? {
        let threads = payload["trace"]["threads"].arrayValue
        for thread in threads {
            if thread["thread_type"] == "Crashed" {
                return thread["index"].stringValue
            }
        }
        return nil
    }
    
    private func parseImages(from payload: JSON) -> [JSON] {
        let threads = payload["trace"]["threads"].arrayValue
        var map: [String: JSON] = [:]
        for thread in threads {
            for frame in thread["thread_stack"].arrayValue {
                map[frame["image_name"].stringValue] = frame
            }
        }
        return Array(map.values)
    }
    
    private func parseArch(from payload: JSON) -> String {
        let arch = payload["trace"]["systemMsg"]["cpu_arch"].stringValue
        if arch.contains("armv7") {
            return arch
        }
        return "arm64"
    }
}
