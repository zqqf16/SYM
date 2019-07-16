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

#import "MDAfcClient.h"
#import "MDLockdown.h"
#import "MDLockdown.h"
#import <libimobiledevice/afc.h>
#import <libimobiledevice/house_arrest.h>

@interface MDAfcClient ()
@property (nonatomic, assign) afc_client_t afc;
@property (nonatomic, strong) MDLockdownService *service;
@property (nonatomic, strong) MDLockdown *lockdown;
@property (nonatomic, strong) MDHouseArrest *houseArrest;
@end

@implementation MDAfcClient

- (instancetype)initWithLockdown:(MDLockdown *)lockdown afc:(afc_client_t)afc {
    if (self = [super init]) {
        _lockdown = lockdown ?: [[MDLockdown alloc] initWithUDID:nil];
        _afc = afc;
    }
    return self;
}

- (instancetype)initWithLockdown:(MDLockdown *)lockdown serviceName:(NSString *)serviceName {
    if (self = [super init]) {
        _lockdown = lockdown ?: [[MDLockdown alloc] initWithUDID:nil];
        _service = [lockdown startServiceWithIdentifier:serviceName];
        afc_error_t err = afc_client_new(_lockdown.device, _service.service, &_afc);
        if (err != AFC_E_SUCCESS) {
            NSLog(@"ERROR: Failed to create afc client: %d", err);
        }
    }
    return self;
}

- (void)dealloc {
    if (_afc) {
        afc_client_free(_afc);
    }
}

- (nullable NSData *)read:(NSString *)path {
    const char *cPath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    if (!_afc || !path) {
        return nil;
    }
    
    uint64_t handle;
    afc_error_t afc_error = afc_file_open(_afc, cPath, AFC_FOPEN_RDONLY, &handle);
    if (afc_error != AFC_E_SUCCESS) {
        NSLog(@"ERROR: Unable to open device file '%s' (%d)", cPath, afc_error);
        return nil;
    }
    
    uint32_t bytes_read = 0;
    uint32_t bytes_total = 0;
    unsigned char data[0x10000] = {0};
    NSMutableData *result = [NSMutableData data];
    
    afc_error = afc_file_read(_afc, handle, (char*)data, 0x10000, &bytes_read);
    while(afc_error == AFC_E_SUCCESS && bytes_read > 0) {
        [result appendBytes:data length:bytes_read];
        bytes_total += bytes_read;
        memset(data, 0, sizeof(data));
        afc_error = afc_file_read(_afc, handle, (char*)data, 0x10000, &bytes_read);
    }
    afc_file_close(_afc, handle);
    
    return [result copy];
}

- (nullable NSString *)readString:(NSString *)path encoding:(NSStringEncoding)encoding {
    NSData *data = [self read:path];
    if (!data) {
        return nil;
    }
    
    return [[NSString alloc] initWithData:data encoding:encoding];
}

- (nullable NSString *)readUTF8String:(NSString *)path {
    return [self readString:path encoding:NSUTF8StringEncoding];
}

- (NSArray<MDDeviceFile *> *)listDirectory:(NSString *)path
{
    if (!_afc || !path) {
        return nil;
    }
    
    NSMutableArray *fileList = [NSMutableArray array];
    
    afc_error_t afc_error;
    int k;
    char source_filename[512];
    const char *device_directory = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    char** list = NULL;
    afc_error = afc_read_directory(_afc, device_directory, &list);
    if (afc_error != AFC_E_SUCCESS) {
        NSLog(@"ERROR: Could not read device directory");
        return nil;
    }
    
    /* ensure we have a trailing slash */
    strcpy(source_filename, device_directory);
    if (source_filename[strlen(source_filename)-1] != '/') {
        strcat(source_filename, "/");
    }
    unsigned long device_directory_length = strlen(source_filename);
    
    /* loop over file entries */
    for (k = 0; list[k]; k++) {
        if (!strcmp(list[k], ".") || !strcmp(list[k], "..")) {
            continue;
        }
        
        char **fileinfo = NULL;
        struct stat stbuf;
        stbuf.st_size = 0;
        MDDeviceFile *file = [[MDDeviceFile alloc] initWithAfcClient:self];
        
        /* assemble absolute source filename */
        strcpy(((char*)source_filename) + device_directory_length, list[k]);
        file.path = [NSString stringWithUTF8String:source_filename];
        if ([file.path hasSuffix:@".com.apple.mobile_container_manager.metadata.plist"]) {
            continue;
        }
        /* get file information */
        afc_get_file_info(_afc, source_filename, &fileinfo);
        if (!fileinfo) {
            NSLog(@"WARN: Failed to read information for '%s'. Skipping...", source_filename);
            continue;
        }
        
        /* parse file information */
        int i;
        for (i = 0; fileinfo[i]; i+=2) {
            if (!strcmp(fileinfo[i], "st_size")) {
                stbuf.st_size = atoll(fileinfo[i+1]);
                file.size = stbuf.st_size;
            } else if (!strcmp(fileinfo[i], "st_ifmt")) {
                if (!strcmp(fileinfo[i+1], "S_IFREG")) {
                    stbuf.st_mode = S_IFREG;
                } else if (!strcmp(fileinfo[i+1], "S_IFDIR")) {
                    stbuf.st_mode = S_IFDIR;
                    file.isDirectory = YES;
                } else if (!strcmp(fileinfo[i+1], "S_IFLNK")) {
                    stbuf.st_mode = S_IFLNK;
                } else if (!strcmp(fileinfo[i+1], "S_IFBLK")) {
                    stbuf.st_mode = S_IFBLK;
                } else if (!strcmp(fileinfo[i+1], "S_IFCHR")) {
                    stbuf.st_mode = S_IFCHR;
                } else if (!strcmp(fileinfo[i+1], "S_IFIFO")) {
                    stbuf.st_mode = S_IFIFO;
                } else if (!strcmp(fileinfo[i+1], "S_IFSOCK")) {
                    stbuf.st_mode = S_IFSOCK;
                }
            } else if (!strcmp(fileinfo[i], "st_nlink")) {
                stbuf.st_nlink = atoi(fileinfo[i+1]);
            } else if (!strcmp(fileinfo[i], "st_mtime")) {
                stbuf.st_mtime = (time_t)(atoll(fileinfo[i+1]) / 1000000000);
                file.date = [NSDate dateWithTimeIntervalSince1970:stbuf.st_mtime];
            } else if (!strcmp(fileinfo[i], "LinkTarget")) {
                /*
                 if (!keep_crash_reports)
                 afc_remove_path(afc, source_filename);
                 */
            }
        }
        
        /* free file information */
        afc_dictionary_free(fileinfo);
        [fileList addObject:file];
    }
    afc_dictionary_free(list);
    return fileList;
}

@end

@implementation MDAfcClient (Crash)

+ (instancetype)crashClientWithLockdown:(MDLockdown *)lockdown {
    lockdown = lockdown ?: [[MDLockdown alloc] initWithUDID:nil];
    MDLockdownService *service = [lockdown startServiceWithIdentifier:@"com.apple.crashreportmover"];
    [service ping];
    return [[self alloc] initWithLockdown:lockdown serviceName:@"com.apple.crashreportcopymobile"];
}

- (nullable NSArray<MDDeviceFile *> *)crashFiles {
    if (!_afc) {
        return nil;
    }
    
    NSMutableArray *results = [[self listDirectory:@"."] mutableCopy];
    NSArray *retired = nil;
    for (MDDeviceFile *file in results) {
        if (file.isDirectory && [file.path isEqualToString:@"./Retired"]) {
            retired = [self listDirectory:@"./Retired"];
        }
    }
    if (retired) {
        [results addObjectsFromArray:retired];
    }
    
    return [results copy];
}

@end

@implementation MDAfcClient (HouseArrest)

+ (instancetype)fileClientWithHouseArrest:(MDHouseArrest *)houseArrest {
    afc_client_t afc = NULL;
    afc_client_new_from_house_arrest_client(houseArrest.houseArrest, &afc);
    if (!afc) {
        NSLog(@"Failed to create afc");
    }
    
    MDAfcClient *afcClient = [[self alloc] initWithLockdown:houseArrest.lockdown afc:afc];
    afcClient.houseArrest = houseArrest;
    return afcClient;
}

@end
