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


#import "MDHouseArrest.h"
#import "MDLockdown.h"

@interface MDHouseArrest ()
@property (nonatomic, strong) NSString *appID;
@end

@implementation MDHouseArrest

- (instancetype)initWithLockdown:(MDLockdown *)lockdown appID:(nonnull NSString *)appID {
    if (self = [super init]) {
        _appID = appID;
        _lockdown = lockdown ?: [[MDLockdown alloc] initWithUDID:nil];
        _service = [_lockdown startServiceWithIdentifier:@(HOUSE_ARREST_SERVICE_NAME)];
        house_arrest_error_t err = house_arrest_client_new(_lockdown.device, _service.service, &_houseArrest);
        if (err == HOUSE_ARREST_E_SUCCESS) {
            [self prepare];
        } else {
            NSLog(@"ERROR: Could not start service house arrest: %d.", err);
        }
    }
    
    return self;
}

- (void)dealloc {
    if (_houseArrest) {
        house_arrest_client_free(_houseArrest);
    }
}

- (void)prepare {
    const char * appid = [self.appID cStringUsingEncoding:NSUTF8StringEncoding];
    house_arrest_error_t err = HOUSE_ARREST_E_UNKNOWN_ERROR;
    err = house_arrest_send_command(_houseArrest, "VendContainer", appid);
    if (err != HOUSE_ARREST_E_SUCCESS) {
        NSLog(@"Could not send house_arrest command: %d", err);
        return;
    }
    
    plist_t dict = NULL;
    err = house_arrest_get_result(_houseArrest, &dict);
    if (err != HOUSE_ARREST_E_SUCCESS) {
        NSLog(@"Could not get result from document sharing service: %d", err);
        return;
    }
    plist_t node = plist_dict_get_item(dict, "Error");
    if (node) {
        char *str = NULL;
        plist_get_string_val(node, &str);
        NSLog(@"ERROR: %s", str);
        if (str && !strcmp(str, "InstallationLookupFailed")) {
            NSLog(@"The App '%s' is either not present on the device, or the 'UIFileSharingEnabled' key is not set in its Info.plist. Starting with iOS 8.3 this key is mandatory to allow access to an app's Documents folder.", appid);
        }
        free(str);
    }
    plist_free(dict);
}

@end
