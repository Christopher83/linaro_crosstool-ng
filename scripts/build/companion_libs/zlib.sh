# This file adds the functions to build the ZLIB library
# Copyright 2011 Michael Edwards
# Licensed under the GPL v2. See COPYING in the root of this package

do_zlib_get() { :; }
do_zlib_extract() { :; }
do_zlib() { :; }

CT_ZLIB_VERSION="1.2.5"
# Overide functions depending on configuration
if [ "${CT_ZLIB_NEEDED}" = "y" ]; then

do_zlib_get() {
    CT_GetFile "zlib-${CT_ZLIB_VERSION}" .tar.gz    \
        http://sourceforge.net/projects/libpng/files
}

do_zlib_extract() {
    CT_Extract "zlib-${CT_ZLIB_VERSION}"
    CT_Patch "zlib" "${CT_ZLIB_VERSION}"
}

do_zlib() {
    mkdir -p "${CT_BUILD_DIR}/build-zlib"
    cd "${CT_BUILD_DIR}/build-zlib"

    CT_DoStep INFO "Installing zlib"

    cp -a "${CT_SRC_DIR}/zlib-${CT_ZLIB_VERSION}" "${CT_BUILD_DIR}/build-zlib"
    CT_Pushd "${CT_BUILD_DIR}/build-zlib/zlib-${CT_ZLIB_VERSION}"

    CT_DoLog EXTRA "Configuring zlib"

    CT_DoExecLog CFG                                \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    CXXFLAGS="${CT_CFLAGS_FOR_HOST}"                \
    ./configure  --prefix="${CT_COMPLIBS_DIR}/zlib" \
        --static

    CT_DoLog EXTRA "Building zlib"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing zlib"
    CT_DoExecLog ALL make install

    CT_Popd
    CT_EndStep
}

fi # CT_ZLIB
