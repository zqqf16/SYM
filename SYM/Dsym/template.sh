#!/bin/bash
#
# SYM dSYM download script template
# ---------------------------------
# Edit this script (Menu → Download Script…, or Settings → Download) so SYM can
# fetch matching .dSYM bundles for the current crash.
#
# How SYM invokes this script
# ---------------------------
#   /path/to/download.sh  <crash_file>  <download_directory>
#
#   $1  Absolute path to a temporary (or original) crash file SYM just wrote.
#       Contents are the report text currently shown in the editor.
#   $2  Download directory from Settings (Config.dsymDownloadDirectory).
#       Put downloaded .dSYM / zip archives under this folder (or a subfolder).
#
# Environment variables (exported by SYM)
# ---------------------------------------
#   APP_NAME       Process / executable name, e.g. Demo
#   UUID           Main binary UUID (normalized), e.g. E5B0A378-6816-3D90-86FD-2AEF15894A85
#   BUNDLE_ID      CFBundleIdentifier, e.g. im.zorro.demo
#   APP_VERSION    App version string. Prefer "build (marketing)", e.g. 212 (1.0.1).
#                  If the crash only has "1.0.1 (212)", SYM rewrites it to "212 (1.0.1)"
#                  for compatibility with older scripts.
#
# Exit codes (SYM treats any non-zero as failure)
# -----------------------------------------------
#   0   Success — dSYM is on disk and (ideally) UUID lines were printed to stdout
#   1   This crash is not supported / nothing to download
#   2   Download or unpack failed
#
# Progress UI
# -----------
#   SYM watches curl’s progress on stderr and maps it to the download progress bar.
#   Prefer:  curl --progress-bar …  (or default curl progress) so stderr stays useful.
#   Avoid redirecting curl’s stderr away unless you do not need the progress bar.
#
# Speeding up dSYM matching (important)
# -------------------------------------
#   After a successful download, print `dwarfdump --uuid` results to stdout.
#   SYM parses lines that look like:
#
#     UUID: E5B0A378-6816-3D90-86FD-2AEF15894A85 (arm64) /path/to/YourApp.app.dSYM/Contents/Resources/DWARF/YourApp
#
#   Matching UUIDs are then attached to the crash immediately (no Spotlight wait).
#
# Example (replace the URL with your own symbol server)
# -----------------------------------------------------
#   set -euo pipefail
#
#   CRASH_FILE="$1"
#   DEST_DIR="$2"
#   OUT_DIR="${DEST_DIR}/${UUID}"
#   ZIP_PATH="${DEST_DIR}/${UUID}.zip"
#
#   mkdir -p "${DEST_DIR}"
#
#   # Optional: skip crashes you cannot serve
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
#   # Print UUIDs for every dSYM so SYM can index them right away
#   find "${OUT_DIR}" -name "*.dSYM" -print0 | while IFS= read -r -d '' dsym; do
#     dwarfdump --uuid "${dsym}"
#   done
#
#   exit 0
#
# Tips
# ----
#   - Quote all paths; UUID / BUNDLE_ID may be empty for incomplete reports.
#   - Prefer downloading into "${2}/${UUID}/…" so multiple crashes do not clash.
#   - SYM also scans the download directory and Xcode Archives locally; a script
#     is only needed when dSYMs live on a remote server.
#   - Spotlight may still pick up new .dSYM packages later; dwarfdump output is faster.
#

# Replace this placeholder with your download logic (see Example above).
# Until then, leave only comments here — SYM treats comment-only scripts as
# “not configured” and will not save them as download.sh.
