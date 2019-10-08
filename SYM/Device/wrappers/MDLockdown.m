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

#import "MDLockdown.h"

#import <libimobiledevice/syslog_relay.h>
#import <libimobiledevice/service.h>
#import "MDUtil.h"

@interface MDLockdownService ()
@property (nonatomic, strong) MDLockdown *lockdown;
@end

@implementation MDLockdownService
- (instancetype)initWithLockdown:(MDLockdown *)lockdown service:(lockdownd_service_descriptor_t)service {
    if (self = [super init]) {
        _lockdown = lockdown;
        _service = service;
    }
    return self;
}

- (void)dealloc {
    if (_service) {
        lockdownd_service_descriptor_free(_service);
    }
}

- (void)ping {
    service_client_t serviceClient = NULL;
    service_error_t err = service_client_new(self.lockdown.device, self.service, &serviceClient);
    if (err != SERVICE_E_SUCCESS) {
        NSLog(@"ERROR: Failed to create service client: %d", err);
        return;
    }

    /* read "ping" message which indicates the crash logs have been moved to a safe harbor */
    char *ping = malloc(4);
    memset(ping, '\0', 4);
    int attempts = 0;
    while ((strncmp(ping, "ping", 4) != 0) && (attempts < 10)) {
        uint32_t bytes = 0;
        err = service_receive_with_timeout(serviceClient, ping, 4, &bytes, 2000);
        if (err == SERVICE_E_SUCCESS || err == SERVICE_E_TIMEOUT) {
            attempts++;
            continue;
        } else {
            NSLog(@"ERROR: Connection interrupted (%d).\n", err);
            break;
        }
    }
    err = service_client_free(serviceClient);
    free(ping);

    if (attempts > 10) {
        NSLog(@"ERROR: Failed to receive ping message from service.");
        return;
    }
}
@end


@interface MDLockdown ()
@property (nonatomic, strong) NSString *udid;
@property (nonatomic, assign) lockdownd_error_t error;
@property (nonatomic, strong) NSDictionary *deviceInfo;

@end

@implementation MDLockdown

- (instancetype)init {
    return [self initWithUDID:nil];
}

- (instancetype)initWithUDID:(NSString *)udid {
    self = [super init];
    if (self) {
        _udid = udid;
        int ret = idevice_new(&_device, [udid cStringUsingEncoding:NSUTF8StringEncoding]);
        if (ret == IDEVICE_E_SUCCESS) {
            _error = lockdownd_client_new_with_handshake(_device, &_lockdownd, "MDLockdown");
            if (_error == LOCKDOWN_E_SUCCESS) {
                [self fetchDeviceInfo];
            } else {
                NSLog(@"ERROR: Failed to create lockdownd: %d", _error);
            }
        } else {
            NSLog(@"ERROR: Failed to create device.");
        }
    }
    return self;
}

- (void)dealloc {
    if (_lockdownd) {
        lockdownd_client_free(_lockdownd);
    }
    if (_device) {
        idevice_free(_device);
    }
}

- (void)fetchDeviceInfo {
    plist_t root = NULL;
    lockdownd_get_value(_lockdownd, NULL, NULL, &root);
    if (!root) {
        return;
    }
    
    self.deviceInfo = plist_to_nsobject(root);
    free(root);
}

- (MDLockdownService *)startServiceWithIdentifier:(NSString *)identifier {
    lockdownd_service_descriptor_t service = NULL;
    const char * serviceId = [identifier cStringUsingEncoding:NSUTF8StringEncoding];
    lockdownd_error_t lockdownd_error = lockdownd_start_service(_lockdownd, serviceId, &service);
    if (lockdownd_error != LOCKDOWN_E_SUCCESS) {
        NSLog(@"ERROR: Failed to start service: %d", lockdownd_error);
        return nil;
    }
    
    return [[MDLockdownService alloc] initWithLockdown:self service:service];
}

#pragma mark - Properities

- (NSString *)deviceName {
    return self.deviceInfo[@"DeviceName"];
}

- (NSString *)deviceID {
    return self.deviceInfo[@"UniqueDeviceID"];
}

@end
