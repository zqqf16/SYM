#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import re
import sys
import json
import requests

def get_raw(url):
    r = requests.get(url)
    if r.status_code != 200:
        return None
    return r.text

def parse_models(regex, text):
    result = []
    lastModel = ""
    model_regex = re.compile(r'.*\d,\d')
    for item in regex.findall(text):
        if model_regex.match(item):
            result.append([item, lastModel])
        else:
            lastModel = item
    return result
    
def get_all_models(url):
    text = get_raw(url)
    if not text:
        print("Connect to url failed")
        return

    results = [
        ["i386", "Simulator"],
        ["x86_64", "Simulator"],
    ]

    ipad = re.compile(r'rowspan.*(iPad[\w \(\)-.]*)')
    results += parse_models(ipad, text)

    iPhone = re.compile(r'rowspan.*(iPhone[\w \(\)-.]*)')
    results += parse_models(iPhone, text)

    iPod = re.compile(r'rowspan.*(iPod[\w \(\)-.]*)')
    results += parse_models(iPod, text)
    
    watch = re.compile(r'rowspan.*?((?:Apple )*Watch[\w \(\)-.]*)')
    results += parse_models(watch, text)
    
    tv = re.compile(r'.*(Apple[ ]*TV[\w \(\)-.]*)')
    results += parse_models(tv, text)
    
    return results
    
def json_output(results):
    json_dict = { m[0]: m[1] for m in results }
    print(json.dumps(json_dict, indent=4))

def nsdict_output(results):
    print("@{")
    for m in results:
        print('    @"{}": @"{}",'.format(m[0], m[1]))
        
    print('}')

def text_output(results):
    for m in results:
        print('{}:{}'.format(*m))
    
def pretty(results, fmt='json'):
    if fmt == 'nsdict':
        nsdict_output(results)
    elif fmt == 'json':
        json_output(results)
    else:
        text_output(results)
    

if __name__ == '__main__':
    results = get_all_models('https://www.theiphonewiki.com/w/index.php?title=Models&action=edit')
    fmt = 'text'
    if len(sys.argv) > 1:
        fmt = sys.argv[1]
    pretty(results, fmt)