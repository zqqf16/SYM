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

#import "MDUtil.h"
#include <sys/time.h>

id plist_to_nsobject(plist_t node) {
    id object = @"";
    plist_type type = plist_get_node_type(node);
    
    char *s = NULL;
    uint8_t b = 0;
    uint64_t u = 0;
    double d = 0;
    struct timeval tv = { 0, 0 };
    int i, count;
    NSMutableArray *array;
    NSMutableDictionary *dict;
    plist_t subnode = NULL;
    plist_dict_iter iter = NULL;
    char *key = NULL;
    
    switch (type) {
        case PLIST_DICT:
            dict = [NSMutableDictionary dictionary];
            plist_dict_new_iter(node, &iter);
            plist_dict_next_item(node, iter, &key, &subnode);
            while (subnode) {
                dict[[NSString stringWithCString:key encoding:NSUTF8StringEncoding]] = plist_to_nsobject(subnode);
                free(key);
                key = NULL;
                subnode = NULL;
                plist_dict_next_item(node, iter, &key, &subnode);
            }
            free(iter);
            object = [dict copy];
            break;
        case PLIST_ARRAY:
            count = plist_array_get_size(node);
            array = [NSMutableArray arrayWithCapacity:count];
            for (i = 0; i < count; i++) {
                subnode = plist_array_get_item(node, i);
                [array addObject:plist_to_nsobject(subnode)];
            }
            object = [array copy];
            break;
        case PLIST_STRING:
            plist_get_string_val(node, &s);
            object = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
            free(s);
            break;
        case PLIST_BOOLEAN:
            plist_get_bool_val(node, &b);
            object = [NSNumber numberWithUnsignedInt:b];
            break;
        case PLIST_DATE:
            plist_get_date_val(node, (int32_t *)&tv.tv_sec, (int32_t *)&tv.tv_usec);
            object = [NSDate dateWithTimeIntervalSince1970:(tv.tv_sec + tv.tv_usec/1000)];
            break;
        case PLIST_KEY:
            plist_get_key_val(node, &s);
            object = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
            free(s);
            break;
        case PLIST_UINT:
            plist_get_uint_val(node, &u);
            object = [NSNumber numberWithUnsignedLong:u];
            break;
        case PLIST_REAL:
            plist_get_real_val(node, &d);
            object = [NSNumber numberWithDouble:d];
            break;
        case PLIST_DATA:
            plist_get_data_val(node, &s, &u);
            object = [NSData dataWithBytes:s length:u];
            free(s);
            break;
        default:
            break;
    }
    
    return object;
}
