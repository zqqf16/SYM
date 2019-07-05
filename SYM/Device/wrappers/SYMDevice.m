// The MIT License (MIT)
//
// Copyright (c) 2017 - 2018 zqqf16
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

#import "SYMDevice.h"
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>
#import <libimobiledevice/afc.h>
#import <libimobiledevice/syslog_relay.h>

// copy from https://github.com/libimobiledevice/libimobiledevice/blob/master/tools/idevicecrashreport.c

static void syslog_callback(char c, void *user_data);

@interface SYMDeviceFile()
@end

@implementation SYMDeviceFile

- (NSString *)name {
    return [self.path lastPathComponent];
}

@end

#pragma mark - C Struct Wrappers

@interface SYMAfcClient : NSObject
@property (nonatomic, assign) idevice_t device;
@property (nonatomic, assign) afc_client_t afc;
@end

@implementation SYMAfcClient

- (instancetype)initWithDevice:(idevice_t)device afc:(afc_client_t)afc {
    if (self = [super init]) {
        _device = device;
        _afc = afc;
    }
    
    return self;
}

- (void)dealloc {
    if (_afc) {
        afc_client_free(_afc);
        _afc = NULL;
    }
}

- (NSArray *)listDirectory:(NSString *)directory
{
    if (!_afc || !directory) {
        return nil;
    }
    
    NSMutableArray *fileList = [NSMutableArray array];
    
    afc_error_t afc_error;
    int k;
    char source_filename[512];
    const char *device_directory = [directory cStringUsingEncoding:NSUTF8StringEncoding];
    
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
        SYMDeviceFile *file = [[SYMDeviceFile alloc] init];
        
        /* assemble absolute source filename */
        strcpy(((char*)source_filename) + device_directory_length, list[k]);
        file.path = [NSString stringWithUTF8String:source_filename];
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

- (NSArray *)crashList {
    if (!_afc) {
        return nil;
    }
    
    NSMutableArray *results = [[self listDirectory:@"."] mutableCopy];
    NSArray *retired = nil;
    for (SYMDeviceFile *file in results) {
        if (file.isDirectory && [file.path isEqualToString:@"./Retired"]) {
            retired = [self listDirectory:@"./Retired"];
        }
    }
    if (retired) {
        [results addObjectsFromArray:retired];
    }
    
    return [results copy];
}

- (NSString *)readFile:(NSString *)path {
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
    
    return [NSString stringWithUTF8String:result.bytes] ?: [[NSString alloc] initWithData:result encoding:NSASCIIStringEncoding];
}

@end

@interface SYMSyslogClient : NSObject
@property (nonatomic, assign) idevice_t device;
@property (nonatomic, assign) syslog_relay_client_t syslog;
@property (nonatomic, copy) void (^loggingCallback)(NSString *);
@property (nonatomic, strong) NSMutableData *logCache;
@end

@implementation SYMSyslogClient

- (instancetype)initWithDevice:(idevice_t)device syslog:(syslog_relay_client_t)syslog {
    if (self = [super init]) {
        _device = device;
        _syslog = syslog;
    }
    
    return self;
}

- (void)dealloc {
    if (_syslog) {
        syslog_relay_stop_capture(_syslog);
        syslog_relay_client_free(_syslog);
    }
}

- (void)startLoggingWithCallback:(void (^)(NSString * _Nonnull))callback
{
    if (!_syslog) {
        return;
    }
    self.logCache = [NSMutableData data];
    self.loggingCallback = callback;

    syslog_relay_error_t serr = syslog_relay_start_capture(_syslog, syslog_callback, (__bridge void *)self);
    if (serr != SYSLOG_RELAY_E_SUCCESS) {
        NSLog(@"ERROR: Unable tot start capturing syslog.");
        return;
    }
}

- (void)didReceiveLog:(char)c
{
    if (c == '\n') {
        self.loggingCallback([NSString stringWithUTF8String:self.logCache.bytes]);
        self.logCache = [NSMutableData data];
        return;
    }
    [self.logCache appendBytes:&c length:sizeof(char)];
}

- (void)stopLogging
{
    if (_syslog) {
        syslog_relay_stop_capture(_syslog);
        syslog_relay_client_free(_syslog);
        _syslog = NULL;
    }
}

@end

static void syslog_callback(char c, void *user_data)
{
    SYMSyslogClient *syslog = (__bridge SYMSyslogClient *)user_data;
    [syslog didReceiveLog:c];
}

@interface SYMLockdowndService : NSObject
@property (nonatomic, assign) idevice_t device;
@property (nonatomic, assign) lockdownd_service_descriptor_t service;
@end

@implementation SYMLockdowndService

- (instancetype)initWithDevice:(idevice_t)device service:(lockdownd_service_descriptor_t)service {
    if (self = [super init]) {
        _device = device;
        _service = service;
    }
    
    return self;
}

- (void)dealloc {
    if (_service) {
        lockdownd_service_descriptor_free(_service);
        _service = NULL;
    }
}

- (SYMAfcClient *)afc {
    if (!_service || !_device) {
        return nil;
    }

    afc_client_t afc = NULL;
    afc_error_t aerr = afc_client_new(_device, _service, &afc);
    if (aerr != AFC_E_SUCCESS) {
        NSLog(@"ERROR: Failed to create afc.");
        return nil;
    }
    
    return [[SYMAfcClient alloc] initWithDevice:_device afc:afc];
}

- (SYMSyslogClient *)syslog {
    if (!_service || !_device) {
        return nil;
    }
    
    syslog_relay_client_t syslog = NULL;
    syslog_relay_error_t serr = SYSLOG_RELAY_E_UNKNOWN_ERROR;
    serr = syslog_relay_client_new(_device, _service, &syslog);
    if (serr != SYSLOG_RELAY_E_SUCCESS) {
        NSLog(@"ERROR: Could not start service com.apple.syslog_relay.");
        return nil;
    }
    
    return [[SYMSyslogClient alloc] initWithDevice:_device syslog:syslog];
}

@end

@interface SYMLockdownd : NSObject
@property (nonatomic, assign) idevice_t device;
@property (nonatomic, assign) lockdownd_client_t lockdownd;
@end

@implementation SYMLockdownd

- (instancetype)initWithDevice:(idevice_t)device lockdownd:(lockdownd_client_t)lockdownd {
    if (self = [super init]) {
        _device = device;
        _lockdownd = lockdownd;
    }
    
    return self;
}

- (void)dealloc {
    if (_lockdownd) {
        lockdownd_client_free(_lockdownd);
        _lockdownd = NULL;
    }
}

- (NSString *)udid {
    if (!_lockdownd) {
        return nil;
    }
    char *udid = NULL;
    NSString *result;
    lockdownd_get_device_udid(_lockdownd, &udid);
    if (udid) {
        result = [NSString stringWithUTF8String:udid];
        free(udid);
    }
    return result;
}

- (NSString *)deviceName {
    if (!_lockdownd) {
        return nil;
    }
    
    char *name = NULL;
    NSString *result = nil;
    lockdownd_get_device_name(_lockdownd, &name);
    if (name) {
        result = [NSString stringWithUTF8String:name];
        free(name);
    }
    return result;
}

- (SYMLockdowndService *)serviceWithIdentifier:(NSString *)identifier {
    if (!_lockdownd) {
        return nil;
    }
    lockdownd_service_descriptor_t service = NULL;
    const char * serviceId = [identifier cStringUsingEncoding:NSUTF8StringEncoding];
    /* start crash log mover service */
    lockdownd_error_t lockdownd_error = lockdownd_start_service(_lockdownd, serviceId, &service);
    if (lockdownd_error != LOCKDOWN_E_SUCCESS) {
        return nil;
    }
    
    return [[SYMLockdowndService alloc] initWithDevice:_device service:service];
}

- (SYMLockdowndService *)crashService {
    if (!_lockdownd) {
        return nil;
    }
    
    SYMLockdowndService *service = [self serviceWithIdentifier:@"com.apple.crashreportmover"];
    if (!service) {
        return nil;
    }
    
    /* trigger move operation on device */
    idevice_connection_t connection = NULL;
    idevice_error_t device_error = idevice_connect(_device, service.service->port, &connection);
    if(device_error != IDEVICE_E_SUCCESS) {
        return nil;
    }
    
    /* read "ping" message which indicates the crash logs have been moved to a safe harbor */
    char *ping = malloc(4);
    memset(ping, '\0', 4);
    int attempts = 0;
    while ((strncmp(ping, "ping", 4) != 0) && (attempts < 10)) {
        uint32_t bytes = 0;
        device_error = idevice_connection_receive_timeout(connection, ping, 4, &bytes, 2000);
        if ((bytes == 0) && (device_error == IDEVICE_E_SUCCESS)) {
            attempts++;
            continue;
        } else if (device_error < 0) {
            NSLog(@"ERROR: Crash logs could not be moved. Connection interrupted.");
            break;
        }
    }
    idevice_disconnect(connection);
    free(ping);
    
    if (device_error != IDEVICE_E_SUCCESS || attempts > 10) {
        NSLog(@"ERROR: Failed to receive ping message from crash report mover.");
        return nil;
    }
    
    return [self serviceWithIdentifier:@"com.apple.crashreportcopymobile"];
}

- (SYMLockdowndService *)syslogService {
    return [self serviceWithIdentifier:@"com.apple.syslog_relay"];
}

@end

@interface SYMDevice ()
@property (nonatomic, assign) idevice_t device;
@property (nonatomic, strong) SYMAfcClient *afc;
@property (nonatomic, strong) SYMSyslogClient *syslog;
@end

@implementation SYMDevice

@synthesize udid = _udid;
@synthesize name = _name;

- (instancetype)initWithDeviceID:(nullable NSString *)udid {
    self = [super init];
    if (self) {
        _udid = udid;
        int ret = idevice_new(&_device, [self.udid cStringUsingEncoding:NSUTF8StringEncoding]);
        if (ret == IDEVICE_E_SUCCESS) {
            [self prepareDeviceInfo];
        } else {
            NSLog(@"ERROR: Failed to create device.");
        }
    }
    return self;
}

- (void)dealloc {
    if (_syslog) {
        [_syslog stopLogging];
    }
    if (_device) {
        idevice_free(_device);
    }
}

- (SYMLockdownd *)createNewLockdownd {
    lockdownd_client_t lockdownd = NULL;
    lockdownd_error_t error = lockdownd_client_new_with_handshake(_device, &lockdownd, "SYMDevice");
    if (error != LOCKDOWN_E_SUCCESS) {
        NSLog(@"ERROR: Failed to create lockdownd client.");
    }
    return [[SYMLockdownd alloc] initWithDevice:_device lockdownd:lockdownd];
}

- (void)prepareDeviceInfo {
    SYMLockdownd *lockdownd = [self createNewLockdownd];
    if (!_udid) {
        _udid = [lockdownd udid];
    }
    _name = [lockdownd deviceName];
}

- (NSArray *)crashList {
    if (!_afc) {
        SYMLockdownd *lockdownd = [self createNewLockdownd];
        _afc = [[lockdownd crashService] afc];
    }
    
    return [self.afc crashList];
}

- (NSString *)readFile:(SYMDeviceFile *)file
{
    if (!_afc) {
        SYMLockdownd *lockdownd = [self createNewLockdownd];
        _afc = [[lockdownd crashService] afc];
    }
    
    return [_afc readFile:file.path];
}

#pragma mark - Logging

- (void)startLoggingWithCallback:(void (^)(NSString * _Nonnull))callback
{
    SYMLockdownd *lockdownd = [self createNewLockdownd];
    _syslog = [[lockdownd syslogService] syslog];
    [_syslog startLoggingWithCallback:callback];
}

- (void)stopLogging {
    [_syslog stopLogging];
    _syslog = nil;
}

@end

