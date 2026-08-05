![image](images/slogan.png)

[![Build Status](https://github.com/zqqf16/SYM/actions/workflows/test.yml/badge.svg)](https://github.com/zqqf16/SYM/actions/workflows/test.yml) [![GitHub issues](https://img.shields.io/github/issues/zqqf16/SYM.svg)](https://github.com/zqqf16/SYM/issues) [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/zqqf16/SYM/master/LICENSE) [![Contact](https://img.shields.io/badge/Contact-%40zqqf16-blue.svg)](https://twitter.com/zqqf16)

# SYM

A macOS app for symbolicating Apple crash reports. Open a `.crash` or `.ips`, let SYM find the matching dSYMs, and turn hex stacks into something you can actually read.

**Download:** [latest release](https://github.com/zqqf16/SYM/releases/latest)

![Demo](images/demo.jpg)

---

## For users

### What it does

- Opens Apple crash reports (classic `.crash`, IPS, and a few related JSON formats). You can also paste a log straight into the editor.
- Looks for matching dSYMs on your Mac, including Xcode Archives. You can import them by hand if needed.
- Symbolicates in one click. Find (⌘F) and Undo (⌘Z) work as you'd expect.
- Optional download script if your dSYMs live on a server.
- Talks to a connected iOS device: pull crashes off the device, browse an app's sandbox.

### Requirements

macOS 13 or later.

### How to use it

1. Grab the app from [Releases](https://github.com/zqqf16/SYM/releases/latest) and install it.
2. Open a crash file, or paste the log into the editor.
3. Check the toolbar / dSYM sheet for matches. If nothing shows up, **Import** a dSYM, or set up a download script and hit **Download**.
4. Click **Symbolicate**.
5. Use ⌘F to search, ⌘Z if you want the previous text back.

Useful places in the UI:

- **dSYM** — which binaries have symbols, import/download
- **Devices** — import crashes from a phone, browse sandboxes
- **Settings** — font, highlight color, line numbers, summary bar, download folder/script, hardware model name updates

---

## For developers

### Setup

- macOS 13+
- A recent Xcode (with Command Line Tools)
- Clone the repo and open `SYM.xcodeproj`

Swift packages resolve on first open / first build.

### Run & test

In Xcode: scheme **SYM**, destination **My Mac**, then Run.

From the terminal:

```bash
xcodebuild -scheme SYM -destination 'platform=macOS' build
xcodebuild test -scheme SYM -destination 'platform=macOS'
```

Crash parsing tests only:

```bash
xcodebuild test -scheme SYM -destination 'platform=macOS' -only-testing:SYMTests/CrashReportTests
```

### Versioning

Marketing version and build number live in the Xcode project (e.g. `0.9.0` / `110`). Bump the build before a release:

```bash
make next
```

Or edit Version / Build under Target SYM → General.

### Shipping a build

The `Makefile` covers the usual release steps:

```bash
# Archive a Release build and export the .app
make archive

# Same, but bake in a download script
make archive script=/path/to/download.sh

# Notarize (needs a notarytool keychain profile named "Notarization")
make notarize

# Build a DMG under dist/
make dmg

# Copy into /Applications
make install
```

Output lands in `build/` and `dist/`. To wipe those:

```bash
make clean
```

### Occasional maintenance

Rebuild the vendored device libraries:

```bash
cd SYM/Device && ./build.sh
```

Refresh the bundled hardware model name list:

```bash
./scripts/update-hardware-models.sh
```

(Users can also hit Check for Updates under Settings → Hardware Models.)

### License

MIT. See [LICENSE](LICENSE).

---

## 中文

macOS 上的崩溃日志符号化工具。打开 `.crash` / `.ips` 等报告，自动匹配 dSYM，一键还原可读堆栈。

最新版本：[Releases](https://github.com/zqqf16/SYM/releases/latest)

### 用户指南

**能做什么**

- 打开或粘贴 Apple 崩溃报告（经典 `.crash`、IPS / JSON 等常见格式）
- 自动在本机查找匹配的 dSYM（含 Xcode Archives）；也可手动导入
- 一键符号化，结果可查找、可撤销
- 自定义脚本从服务器下载 dSYM
- 连接 iOS 设备：导入设备上的崩溃日志，浏览应用沙盒文件

**系统要求：** macOS 13 或更高版本

**怎么用**

1. 从 [Releases](https://github.com/zqqf16/SYM/releases/latest) 下载并安装 SYM。
2. 用 SYM 打开崩溃文件，或把日志内容粘贴进编辑器。
3. 等待工具栏 / dSYM 面板显示已匹配的符号文件；没有的话可点 **Import** 手动选择，或配置下载脚本后点 **Download**。
4. 点击工具栏 **Symbolicate（符号化）**。
5. 需要时用 ⌘F 查找，⌘Z 撤销符号化。

常用入口：

- **dSYM**：查看符号匹配状态，导入或下载 dSYM
- **Devices**：连接设备后导入崩溃、浏览沙盒
- **Settings**：字体、高亮、行号、摘要栏、下载目录、下载脚本、硬件型号库更新等

### 开发指南

**环境：** macOS 13+、较新的 Xcode（含 Command Line Tools）。克隆后打开 `SYM.xcodeproj`，Swift 包会在首次打开 / 构建时解析。

**运行与测试：** Xcode 选 scheme **SYM**、目标 **My Mac** 后 Run。命令行：

```bash
xcodebuild -scheme SYM -destination 'platform=macOS' build
xcodebuild test -scheme SYM -destination 'platform=macOS'
# 仅崩溃解析测试
xcodebuild test -scheme SYM -destination 'platform=macOS' -only-testing:SYMTests/CrashReportTests
```

**版本号：** 在 Xcode 工程里改 Version / Build，或发版前执行 `make next`。

**打包发布：**

```bash
make archive                              # Release 归档并导出 .app
make archive script=/path/to/download.sh  # 可选：内置下载脚本
make notarize                             # 需 Keychain profile「Notarization」
make dmg                                  # 生成 dist/ 下的 DMG
make install                              # 安装到 /Applications
make clean
```

**可选维护：**

```bash
cd SYM/Device && ./build.sh                 # 重建设备相关静态库
./scripts/update-hardware-models.sh         # 刷新随 App 附带的硬件型号库
```

（用户也可在 Settings → Hardware Models → Check for Updates 在线更新。）

**许可：** MIT，见 [LICENSE](LICENSE)。
