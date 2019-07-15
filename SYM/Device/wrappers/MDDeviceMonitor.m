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

#import "MDDeviceMonitor.h"
#import <libimobiledevice/libimobiledevice.h>
#import <usbmuxd/usbmuxd-proto.h>
#import <usbmuxd/usbmuxd.h>

NSString * const MDDeviceMonitorNotification = @"sym.deviceMonitoring";

@interface MDDeviceMonitor ()
@property (nonatomic, strong) dispatch_queue_t operationQueue;

- (void)updateDeviceStatus;
@end

static void usbmux_event_cb(const usbmuxd_event_t *event, void *user_data)
{
    if (event->event == IDEVICE_DEVICE_ADD) {
        NSLog(@"INFO: Device connected");
    } else if (event->event == IDEVICE_DEVICE_REMOVE) {
        NSLog(@"INFO: Device disconnected");
    }
    
    [[MDDeviceMonitor sharedMonitor] updateDeviceStatus];
}

@implementation MDDeviceMonitor

+ (instancetype)sharedMonitor
{
    static MDDeviceMonitor *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MDDeviceMonitor alloc] init];
        sharedInstance.operationQueue = dispatch_queue_create("sym.device.monitoring", NULL);
    });
    
    return sharedInstance;
}

- (void)updateDeviceStatus
{
    dispatch_async(self.operationQueue, ^{
        int num = 0;
        char **devices = NULL;
        idevice_get_device_list(&devices, &num);
        
        NSMutableArray *deviceList = [NSMutableArray array];
        if (num > 0) {
            for (int i = 0; i < num; i++) {
                NSString *udid = [NSString stringWithFormat:@"%s", devices[i]];
                [deviceList addObject:udid];
            }
        }
        self.deviceConnected = (num > 0);
        self.connectedDevices = [deviceList copy];
        idevice_device_list_free(devices);
    });
}

- (void)setDeviceConnected:(BOOL)deviceConnected
{
    _deviceConnected = deviceConnected;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MDDeviceMonitorNotification object:nil];
    });
}

- (void)start
{
    int res = usbmuxd_subscribe(usbmux_event_cb, NULL);
    if (res != 0) {
        NSLog(@"ERROR: start device monitor");
    }
    
    [self updateDeviceStatus];
}

@end
