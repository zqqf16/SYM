#!/usr/bin/env bash
set -euo pipefail

# Rebuild static libimobiledevice stack for SYM (universal arm64 + x86_64).
# Run from SYM/Device: ./build.sh
# Output is copied into ./libimobiledevice/

MIN_OS="13.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
OUT_DIR="${SCRIPT_DIR}/libimobiledevice"
CFLAGS_UNIVERSAL="-arch arm64 -arch x86_64 -mmacosx-version-min=${MIN_OS}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

export PKG_CONFIG_PATH="${BUILD_DIR}"

write_pc() {
  local name="$1"
  local version="$2"
  local prefix="$3"
  local libname="$4"
  cat > "${BUILD_DIR}/${name}.pc" <<EOF
prefix=${prefix}
exec_prefix=\${prefix}
libdir=\${prefix}/src/.libs
includedir=\${prefix}/include

Name: ${name}
Description: ${name}
Version: ${version}

Requires:
Libs: -L\${libdir} -l${libname}
Cflags: -I\${includedir}
EOF
}

# --- libplist ---
cd "${BUILD_DIR}"
git clone --depth 1 https://github.com/libimobiledevice/libplist.git
cd libplist
./autogen.sh CFLAGS="${CFLAGS_UNIVERSAL}" --without-cython --disable-shared --enable-static
make -j"$(sysctl -n hw.ncpu)"
write_pc "libplist-2.0" "2.6.0" "${BUILD_DIR}/libplist" "plist-2.0"

# --- libimobiledevice-glue ---
cd "${BUILD_DIR}"
git clone --depth 1 https://github.com/libimobiledevice/libimobiledevice-glue.git
cd libimobiledevice-glue
./autogen.sh CFLAGS="${CFLAGS_UNIVERSAL}" --disable-shared --enable-static
make -j"$(sysctl -n hw.ncpu)"
write_pc "libimobiledevice-glue-1.0" "1.3.0" "${BUILD_DIR}/libimobiledevice-glue" "imobiledevice-glue-1.0"

# --- libusbmuxd ---
cd "${BUILD_DIR}"
git clone --depth 1 https://github.com/libimobiledevice/libusbmuxd.git
cd libusbmuxd
./autogen.sh CFLAGS="${CFLAGS_UNIVERSAL}" --disable-shared --enable-static
make -j"$(sysctl -n hw.ncpu)"
write_pc "libusbmuxd-2.0" "2.1.0" "${BUILD_DIR}/libusbmuxd" "usbmuxd-2.0"

# --- openssl (static universal, libs only) ---
cd "${BUILD_DIR}"
git clone --depth 1 --branch openssl-3.3.2 https://github.com/openssl/openssl.git openssl 2>/dev/null \
  || git clone --depth 1 https://github.com/openssl/openssl.git openssl
cd openssl

JOBS="$(sysctl -n hw.ncpu)"
ARM_PREFIX="/tmp/openssl-arm-sym"
X86_PREFIX="/tmp/openssl-x86-sym"
rm -rf "${ARM_PREFIX}" "${X86_PREFIX}"

./Configure darwin64-arm64-cc --prefix="${ARM_PREFIX}" no-shared no-tests no-ui-console no-apps -mmacosx-version-min="${MIN_OS}"
make -j"${JOBS}" build_libs
make install_dev
make distclean || make clean || true

./Configure darwin64-x86_64-cc --prefix="${X86_PREFIX}" no-shared no-tests no-ui-console no-apps -mmacosx-version-min="${MIN_OS}"
make -j"${JOBS}" build_libs
make install_dev

mkdir -p libs include
lipo "${ARM_PREFIX}/lib/libssl.a" "${X86_PREFIX}/lib/libssl.a" -create -output libs/libssl.a
lipo "${ARM_PREFIX}/lib/libcrypto.a" "${X86_PREFIX}/lib/libcrypto.a" -create -output libs/libcrypto.a
cp -R "${ARM_PREFIX}/include/"* include/

cat > "${BUILD_DIR}/openssl.pc" <<EOF
prefix=${BUILD_DIR}/openssl
exec_prefix=\${prefix}
libdir=\${prefix}/libs
includedir=\${prefix}/include

Name: openssl
Description: openssl
Version: 3.3.0

Requires:
Libs: -L\${libdir} -lssl -lcrypto
Cflags: -I\${includedir}
EOF

# --- libtatsu (required by modern libimobiledevice) ---
cd "${BUILD_DIR}"
git clone --depth 1 https://github.com/libimobiledevice/libtatsu.git
cd libtatsu
./autogen.sh CFLAGS="${CFLAGS_UNIVERSAL}" --disable-shared --enable-static
make -j"$(sysctl -n hw.ncpu)"
write_pc "libtatsu-1.0" "1.0.3" "${BUILD_DIR}/libtatsu" "tatsu-1.0"

# --- libimobiledevice ---
cd "${BUILD_DIR}"
git clone --depth 1 https://github.com/libimobiledevice/libimobiledevice.git
cd libimobiledevice

# Compatibility shims for older Makefile assumptions (safe if patterns absent)
sed -i.bak -e 's/\$(libplist_CFLAGS) \\/\$(libplist_CFLAGS) \$(limd_glue_CFLAGS) \\/g' common/Makefile.am || true
sed -i.bak -e 's/tools docs//g' Makefile.am || true

./autogen.sh CFLAGS="${CFLAGS_UNIVERSAL}" --without-cython --disable-shared --enable-static
make -j"$(sysctl -n hw.ncpu)"

# --- stage headers + libs into OUT_DIR ---
STAGE="${BUILD_DIR}/stage"
rm -rf "${STAGE}"
mkdir -p "${STAGE}/plist" "${STAGE}/libimobiledevice"

cp "${BUILD_DIR}/libplist/include/plist/plist.h" "${STAGE}/plist/"
cp "${BUILD_DIR}/libusbmuxd/include/"*.h "${STAGE}/" 2>/dev/null || true
cp -R "${BUILD_DIR}/libimobiledevice/include/libimobiledevice/"* "${STAGE}/libimobiledevice/"
cp "${BUILD_DIR}/libimobiledevice/include/"*.h "${STAGE}/" 2>/dev/null || true

{
  for header in "${STAGE}"/*.h; do
    [ -f "$header" ] || continue
    base="$(basename "$header")"
    [ "$base" = "asprintf.h" ] && continue
    [ "$base" = "libimobiledevicec.h" ] && continue
    echo "#include \"${base}\""
  done
  echo '#include "plist/plist.h"'
  for header in "${STAGE}"/libimobiledevice/*.h; do
    [ -f "$header" ] || continue
    echo "#include \"libimobiledevice/$(basename "$header")\""
  done
} > "${STAGE}/libimobiledevicec.h"
rm -f "${STAGE}/asprintf.h"

cat > "${STAGE}/module.modulemap" <<'EOF'
module libimobiledevicec {
    umbrella header "libimobiledevicec.h"
    export *
    module * { export * }
}
EOF

cp "${BUILD_DIR}/libplist/src/.libs/libplist-2.0.a" "${STAGE}/"
cp "${BUILD_DIR}/libimobiledevice-glue/src/.libs/libimobiledevice-glue-1.0.a" "${STAGE}/"
cp "${BUILD_DIR}/libusbmuxd/src/.libs/libusbmuxd-2.0.a" "${STAGE}/"
cp "${BUILD_DIR}/libtatsu/src/.libs/libtatsu.a" "${STAGE}/libtatsu-1.0.a"
cp "${BUILD_DIR}/openssl/libs/libcrypto.a" "${STAGE}/"
cp "${BUILD_DIR}/openssl/libs/libssl.a" "${STAGE}/"
cp "${BUILD_DIR}/libimobiledevice/src/.libs/libimobiledevice-1.0.a" "${STAGE}/"

# Preserve any existing non-generated files, then replace libs/headers
mkdir -p "${OUT_DIR}"
rsync -a --delete \
  --exclude '.DS_Store' \
  "${STAGE}/" "${OUT_DIR}/"

echo "Built libimobiledevice stack into ${OUT_DIR}"
ls -la "${OUT_DIR}"/*.a
