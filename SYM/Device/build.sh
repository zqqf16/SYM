#!/usr/bin/env bash

BUILD_DIR="`pwd`/build"
PWD="`pwd`"

rm -rf "${BUILD_DIR}"
mkdir "${BUILD_DIR}"

# build libplist
cd "${BUILD_DIR}"
git clone --depth 1 https://github.com/libimobiledevice/libplist.git

cd libplist
./autogen.sh CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=10.11" --without-cython
make

cd "${BUILD_DIR}"

tee -a libplist-2.0.pc << END
prefix="${BUILD_DIR}/libplist"
exec_prefix=\${prefix}
libdir=\${exec_prefix}/src/.libs
sharedlibdir=\${libdir}
includedir=\${prefix}/include

Name: libplist-2.0
Description: libplist
Version: 2.2.0

Requires:
Libs: -L\${libdir} -lplist-2.0
Cflags: -I\${includedir}
END

export PKG_CONFIG_PATH="${BUILD_DIR}"

# build glue

git clone --depth 1 https://github.com/libimobiledevice/libimobiledevice-glue.git

cd libimobiledevice-glue
./autogen.sh CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=10.11"
make

cd "${BUILD_DIR}"

tee -a libimobiledevice-glue-1.0.pc << END
prefix="${BUILD_DIR}/libimobiledevice-glue"
exec_prefix=\${prefix}
libdir=\${exec_prefix}/src/.libs
sharedlibdir=\${libdir}
includedir=\${prefix}/include

Name: libimobiledevice-glue-1.0
Description: libimobiledevice-glue-1.0
Version: 2.2.0

Requires:
Libs: -L\${libdir} -limobiledevice-glue-1.0
Cflags: -I\${includedir}
END


# build libusbmuxd

git clone --depth 1 https://github.com/libimobiledevice/libusbmuxd.git
cd libusbmuxd
./autogen.sh CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=10.11"
make

cd "${BUILD_DIR}"

tee -a libusbmuxd-2.0.pc << END
prefix="${BUILD_DIR}/libusbmuxd"
exec_prefix=\${prefix}
libdir=\${exec_prefix}/src/.libs
sharedlibdir=\${libdir}
includedir=\${prefix}/include

Name: libusbmuxd-2.0
Description: libusbmuxd-2.0
Version: 2.0.2

Requires:
Libs: -L\${libdir} -lusbmuxd-2.0
Cflags: -I\${includedir}
END


# openssl
git clone --depth 1 https://github.com/openssl/openssl.git openssl
cd openssl

./Configure darwin64-arm64-cc --prefix="/tmp/openssl-arm" no-asm  -mmacosx-version-min=10.11
make build_generated libssl.a libcrypto.a
make install_sw
make clean

./Configure darwin64-x86_64-cc --prefix="/tmp/openssl-x86"  -mmacosx-version-min=10.11
make build_generated libssl.a libcrypto.a
make install_sw

mkdir -p libs

lipo /tmp/openssl-arm/lib/libssl.a /tmp/openssl-x86/lib/libssl.a -create -output libs/libssl.a
lipo /tmp/openssl-arm/lib/libcrypto.a /tmp/openssl-x86/lib/libcrypto.a -create -output libs/libcrypto.a


cd "${BUILD_DIR}"

tee -a openssl.pc << END
prefix="${BUILD_DIR}/openssl"
exec_prefix=\${prefix}
libdir=\${exec_prefix}/libs
sharedlibdir=\${libdir}
includedir=\${prefix}/include

Name: openssl
Description: openssl
Version: 3.0.2

Requires:
Libs: -L\${libdir} -lssl -lcrypto
Cflags: -I\${includedir}
END

# libimobiledevice
git clone --depth 1 https://github.com/libimobiledevice/libimobiledevice
cd libimobiledevice

# there are some errors in these files
sed -i -e 's/\$(libplist_CFLAGS) \\/\$(libplist_CFLAGS) \$(limd_glue_CFLAGS) \\/g' common/Makefile.am
sed -i -e 's/tools docs//g' Makefile.am


./autogen.sh CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=10.11" --without-cython
make

cd "${BUILD_DIR}"

# copy files
mkdir -p headers/plist
cp libplist/include/plist/plist.h headers/plist
cp libusbmuxd/include/*.h headers 
cp libimobiledevice/include/*.h headers
cp -R libimobiledevice/include/libimobiledevice headers/

cd headers
rm asprintf.h
for header in *.h
do
    echo "#include \"${header}\"" >> libimobiledevicec.h
done

echo "#include \"plist/plist.h\"" >> libimobiledevicec.h

for header in libimobiledevice/*.h
do
    echo "#include \"${header}\"" >> libimobiledevicec.h
done
cd ..

mv libimobiledevicec.h headers
tee -a headers/module.modulemap << END
module libimobiledevicec {
    umbrella header "libimobiledevicec.h"
    export *
    module * { export * }
}
END

cp libplist/src/.libs/libplist-2.0.a headers
cp libimobiledevice-glue/src/.libs/libimobiledevice-glue-1.0.a headers
cp libusbmuxd/src/.libs/libusbmuxd-2.0.a headers
cp openssl/libs/libcrypto.a headers
cp openssl/libs/libssl.a headers
cp libimobiledevice/src/.libs/libimobiledevice-1.0.a headers

mv headers "${PWD}"/libs