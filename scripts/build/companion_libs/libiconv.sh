# This file adds the functions to build the LIBICONV library
# Copyright 2011 Linaro Limited
# Licensed under the GPL v2. See COPYING in the root of this package

do_libiconv_get() { :; }
do_libiconv_extract() { :; }
do_libiconv() { :; }

if [ "${CT_LIBICONV_NEEDED}" = "y" ]; then

# hard-coded
CT_LIBICONV_VERSION="1.14"

do_libiconv_get() {
    CT_GetFile "libiconv-${CT_LIBICONV_VERSION}"     \
        http://ftp.gnu.org/pub/gnu/libiconv
}

do_libiconv_extract() {
    CT_Extract "libiconv-${CT_LIBICONV_VERSION}"
    CT_Patch "libiconv" "${CT_LIBICONV_VERSION}"
}

do_libiconv() {
    mkdir -p "${CT_BUILD_DIR}/build-libiconv"
    cd "${CT_BUILD_DIR}/build-libiconv"

    CT_DoStep INFO "Installing libiconv"

    CT_DoLog EXTRA "Configuring libiconv"

    CT_DoExecLog CFG                                \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    CXXFLAGS="${CT_CFLAGS_FOR_HOST}"                \
    "${CT_SRC_DIR}/libiconv-${CT_LIBICONV_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --prefix="${CT_COMPLIBS_DIR}"               \
        --disable-shared                            \
        --enable-static

    CT_DoLog EXTRA "Building libiconv"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing libiconv"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_LIBCONV_NEEDED
