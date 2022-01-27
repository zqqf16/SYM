#!/bin/bash

# Download the .dSYM file to wherever you want.
# SYM can find it automatically.

# Environment variables:
#    $1               # original crash file path
#    $2               # download directory
#    ${APP_NAME}      # e.g. im_zorro_sym
#    ${UUID}          # e.g. E5B0A378-6816-3D90-86FD-2AEF15894A85
#    ${BUNDLE_ID}     # e.g. im.zorro.sym
#    ${APP_VERSION}   # e.g. 212 (1.0.1)

# Error handling:
#    exit 0           # success
#    exit 1           # crash not supported
#    exit 2           # download failed

# Examples:
#    curl -o $2/${UUID}.zip http://your.server.domain/path/to/${UUID}.zip
#    unzip -o "$2/${UUID}.zip" -d "$2/${UUID}"
#    for f in "$2/${UUID}/*.dSYM"; do dwarfdump --uuid $f ; done
#

# Tips:
#    - curl progress will be shown in the downlaod progress bar
#    - run `dwarfdump --uuid` at the end of the script to output the UUID will speed up the indexing process