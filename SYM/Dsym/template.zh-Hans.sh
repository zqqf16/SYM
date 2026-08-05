#!/bin/bash
#
# SYM dSYM 下载脚本模板
# ---------------------
# 通过菜单「下载脚本…」或设置中的下载相关项编辑本脚本，
# 让 SYM 按当前崩溃报告自动拉取对应的 .dSYM。
#
# SYM 如何调用本脚本
# ------------------
#   /path/to/download.sh  <崩溃文件路径>  <下载目录>
#
#   $1  SYM 写入的崩溃文件绝对路径（临时文件或原文件）。
#       内容为编辑器中当前展示的报告文本。
#   $2  设置里配置的下载目录（Config.dsymDownloadDirectory）。
#       请将下载的 .dSYM 或 zip 放到此目录（或其子目录）下。
#
# 环境变量（由 SYM 注入）
# ----------------------
#   APP_NAME       进程 / 可执行文件名，例如 Demo
#   UUID           主二进制 UUID（已规范化），例如 E5B0A378-6816-3D90-86FD-2AEF15894A85
#   BUNDLE_ID      CFBundleIdentifier，例如 im.zorro.demo
#   APP_VERSION    应用版本字符串。优先为「构建号 (营销版本)」形式，例如 212 (1.0.1)。
#                  若崩溃里只有 "1.0.1 (212)"，SYM 会改写成 "212 (1.0.1)"，
#                  以兼容旧脚本。
#
# 退出码（非 0 均视为失败）
# ------------------------
#   0   成功 — dSYM 已落盘，且最好已向 stdout 打印 UUID 行
#   1   当前崩溃不支持 / 无需下载
#   2   下载或解压失败
#
# 进度条
# ------
#   SYM 会读取 curl 输出到 stderr 的进度，映射到下载进度条。
#   建议使用：curl --progress-bar …（或默认进度输出），并保留 stderr。
#   若不需要进度条，再重定向 stderr。
#
# 加速 dSYM 匹配（重要）
# ----------------------
#   下载成功后，请将 `dwarfdump --uuid` 的结果打印到 stdout。
#   SYM 会解析形如下列的行：
#
#     UUID: E5B0A378-6816-3D90-86FD-2AEF15894A85 (arm64) /path/to/YourApp.app.dSYM/Contents/Resources/DWARF/YourApp
#
#   匹配到的 UUID 会立刻关联到当前崩溃（无需等待 Spotlight）。
#
# 示例（将 URL 换成你的符号服务器）
# ----------------------------------
#   set -euo pipefail
#
#   CRASH_FILE="$1"
#   DEST_DIR="$2"
#   OUT_DIR="${DEST_DIR}/${UUID}"
#   ZIP_PATH="${DEST_DIR}/${UUID}.zip"
#
#   mkdir -p "${DEST_DIR}"
#
#   # 可选：跳过无法提供的包名
#   # if [[ "${BUNDLE_ID}" != "im.zorro.demo" ]]; then
#   #   exit 1
#   # fi
#
#   curl --fail --location --progress-bar \
#     -o "${ZIP_PATH}" \
#     "https://your.server.example/dsyms/${UUID}.zip" \
#     || exit 2
#
#   mkdir -p "${OUT_DIR}"
#   unzip -o "${ZIP_PATH}" -d "${OUT_DIR}" || exit 2
#
#   # 打印每个 dSYM 的 UUID，供 SYM 立即索引
#   find "${OUT_DIR}" -name "*.dSYM" -print0 | while IFS= read -r -d '' dsym; do
#     dwarfdump --uuid "${dsym}"
#   done
#
#   exit 0
#
# 提示
# ----
#   - 路径请加引号；不完整的崩溃报告里 UUID / BUNDLE_ID 可能为空。
#   - 建议下载到 "${2}/${UUID}/…"，避免多次崩溃互相覆盖。
#   - SYM 也会扫描下载目录与 Xcode Archives；仅当 dSYM 在远程服务器时才需要脚本。
#   - Spotlight 稍后仍可能索引新的 .dSYM；打印 dwarfdump 结果会更快。
#

# 请将此处占位说明换成你的下载实现（参见上方示例）。
# 在真正编写逻辑前请只保留注释——SYM 会把“纯注释脚本”视为未配置，
# 也不会把它保存为 download.sh。
