// The MIT License (MIT)
//
// Copyright (c) 2017 - present zqqf16
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


#import "MDInstProxy.h"
#import "MDLockdown.h"
#import "MDUtil.h"
#import <libimobiledevice/installation_proxy.h>

@interface MDAppInfo ()
@property (nonatomic, strong) NSDictionary *rawInfo;
@end

@implementation MDAppInfo

- (instancetype)initWithInfo:(NSDictionary *)info {
    if (self = [super init]) {
        _rawInfo = info;
    }
    return self;
}

- (NSString *)name {
    return self.rawInfo[@"CFBundleDisplayName"];
}

- (NSString *)identifier {
    return self.rawInfo[@"CFBundleIdentifier"];
}

- (BOOL)isDeveloping {
    NSString *signer = self.rawInfo[@"SignerIdentity"];
    return (![signer hasPrefix:@"Apple"] && [signer containsString:@"Developer"]) // Xcode 10
            || [signer containsString:@"Apple Development"]; // Xcode 11
}

- (NSString *)container {
    return self.rawInfo[@"Container"];
}

@end

@interface MDInstProxy ()
@property (nonatomic, strong) MDLockdown *lockdown;
@property (nonatomic, strong) MDLockdownService *service;
@property (nonatomic, assign) instproxy_client_t instproxy;
@end

@implementation MDInstProxy

- (instancetype)initWithLockdown:(nullable MDLockdown *)lockdown {
    if (self = [super init]) {
        _lockdown = lockdown ?: [[MDLockdown alloc] initWithUDID:nil];
        _service = [lockdown startServiceWithIdentifier:@(INSTPROXY_SERVICE_NAME)];
        instproxy_error_t err = instproxy_client_new(_lockdown.device, _service.service, &_instproxy);
        if (err != INSTPROXY_E_SUCCESS) {
            NSLog(@"ERROR: Could not start service instrpoxy: %d.", err);
        }
    }
    return self;
}

- (void)dealloc {
    if (_instproxy) {
        instproxy_client_free(_instproxy);
    }
}

- (NSArray *)listApps {
    plist_t result = NULL;
    plist_t filter = plist_new_dict();
    plist_dict_set_item(filter, "ApplicationType", plist_new_string("User"));
    instproxy_error_t err = instproxy_browse(_instproxy, filter, &result);
    plist_free(filter);

    if (err != INSTPROXY_E_SUCCESS) {
        NSLog(@"ERROR: Failed to browse apps.");
        return @[];
    }

    NSArray *list = plist_to_nsobject(result);
    plist_free(result);
    
    NSMutableArray *apps = [NSMutableArray array];
    for (NSDictionary *info in list) {
        [apps addObject:[[MDAppInfo alloc] initWithInfo:info]];
    }
    return [apps copy];
}

@end
