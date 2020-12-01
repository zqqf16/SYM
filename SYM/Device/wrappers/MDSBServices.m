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


#import "MDSBServices.h"
#import "MDLockdown.h"
#import <libimobiledevice/sbservices.h>
#import <AppKit/NSImage.h>

@interface MDSBServices ()
@property (nonatomic, strong) MDLockdown *lockdown;
@property (nonatomic, assign) sbservices_client_t client;
@end

@implementation MDSBServices

- (instancetype)initWithLockdown:(nullable MDLockdown *)lockdown {
    if (self = [super init]) {
        _lockdown = lockdown ?: [[MDLockdown alloc] initWithUDID:nil];
        sbservices_error_t err = sbservices_client_start_service(_lockdown.device, &_client, "SYM");
        if (err != SBSERVICES_E_SUCCESS) {
            NSLog(@"ERROR: Could not start service sbservices: %d.", err);
        }
    }
    return self;
}

- (void)dealloc {
    if (_client) {
        sbservices_client_free(_client);
    }
}

- (nullable NSImage *)requestIconImage:(NSString *)bundleID {
    if (!_client || !bundleID) {
        return nil;
    }
    
    const char *bundleIDStr = [bundleID cStringUsingEncoding:NSUTF8StringEncoding];
    char *pngData = NULL;
    uint64_t pngSize = 0;
    sbservices_get_icon_pngdata(_client, bundleIDStr, &pngData, &pngSize);
    if (pngData) {
        NSData *data = [NSData dataWithBytesNoCopy:pngData length:pngSize freeWhenDone:YES];
        return [[NSImage alloc] initWithData:data];
    }
    return nil;
}

//sbservices_error_t sbservices_get_icon_pngdata(sbservices_client_t client, const char *bundleId, char **pngdata, uint64_t *pngsize);


@end
