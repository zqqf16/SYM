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

#import "MDScreenShotr.h"
#import "MDLockdown.h"
#import <libimobiledevice/screenshotr.h>
#import <AppKit/NSImage.h>
#import "MDScreenShotr.h"

@interface MDScreenShotr ()
@property (nonatomic, strong) MDLockdown *lockdown;
@property (nonatomic, assign) screenshotr_client_t client;
@end

@implementation MDScreenShotr

- (instancetype)initWithLockdown:(nullable MDLockdown *)lockdown {
    if (self = [super init]) {
        _lockdown = lockdown ?: [[MDLockdown alloc] initWithUDID:nil];
        screenshotr_error_t err = screenshotr_client_start_service(_lockdown.device, &_client, "SYM");
        if (err != SCREENSHOTR_E_SUCCESS) {
            NSLog(@"ERROR: Could not start service screenshotr: %d.", err);
        }
    }
    return self;
}

- (void)dealloc {
    if (_client) {
        screenshotr_client_free(_client);
    }
}

- (nullable NSImage *)takeScreenShot {
    if (!_client) {
        return nil;
    }
    
    char *imgData;
    uint64_t imgSize = 0;
    screenshotr_take_screenshot(_client, &imgData, &imgSize);
    if (!imgData) {
        return nil;
    }

    NSData *data = [NSData dataWithBytesNoCopy:imgData length:imgSize freeWhenDone:YES];
    return [[NSImage alloc] initWithData:data];
}

@end
