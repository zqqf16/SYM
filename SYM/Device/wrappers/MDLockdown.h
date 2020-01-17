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

#import <Foundation/Foundation.h>
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>

NS_ASSUME_NONNULL_BEGIN

@interface MDLockdownService : NSObject

@property (nonatomic, assign, readonly) lockdownd_service_descriptor_t service;

- (void)ping;

@end


@interface MDLockdown : NSObject

@property (nonatomic, assign, readonly) idevice_t device;
@property (nonatomic, assign, readonly) lockdownd_client_t lockdownd;

@property (nonatomic, readonly, nullable) NSString *deviceName;
@property (nonatomic, readonly, nullable) NSString *deviceID;

- (instancetype)initWithUDID:(nullable NSString *)udid NS_DESIGNATED_INITIALIZER;

- (nullable MDLockdownService *)startServiceWithIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
