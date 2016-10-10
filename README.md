![image](images/slogan.png)

[![Build Status](https://travis-ci.org/zqqf16/SYM.svg?branch=master)](https://travis-ci.org/zqqf16/SYM) [![GitHub stars](https://img.shields.io/github/stars/zqqf16/SYM.svg)](https://github.com/zqqf16/SYM/stargazers) [![GitHub forks](https://img.shields.io/github/forks/zqqf16/SYM.svg)](https://github.com/zqqf16/SYM/network) [![GitHub issues](https://img.shields.io/github/issues/zqqf16/SYM.svg)](https://github.com/zqqf16/SYM/issues) [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/zqqf16/SYM/master/LICENSE) [![Contact](https://img.shields.io/badge/Contact-%40zqqf16-blue.svg)](https://twitter.com/zqqf16)

# SYM

An app for crash symbolicating. 

Download the latest version from [here](https://github.com/zqqf16/SYM/releases/latest).

## Features

1. Support Umeng, Bugly and Apple crash log.
2. Automatically search dSYM files.
3. Highlight key backtrace frames.

## Usage

#### Symbolicate

You can:

- paste in crash informations
- go to "Menu"->"File"->"Open" to open a crash file
- right click an .ips or .crash file, open with SYM

SYM can detect the crash format and symbolicate it automatically when it is opened or pasted in. You can manually do this by "Menu"->"Symbol"->"Symbolicate" or "⌘R"

#### Import a dSYM file

By default, SYM indexes all the dSYM files on your disk. However, there may be some "informal" type of dSYM files. You can import theme by "Menu"->"dSYM"->"Import dSYM".

## Example

![Demo](images/demo.png)
