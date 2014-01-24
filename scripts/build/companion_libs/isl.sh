# This file adds the functions to build the ISL library
# Copyright 2013 Zhenqiang Chen
# Licensed under the GPL v2. See COPYING in the root of this package

do_isl_get() { :; }
do_isl_extract() { :; }
do_isl() { :; }

# Overide functions depending on configuration
if [ "${CT_ISL}" = "y" ]; then

# Download PPL
do_isl_get() {
    CT_GetFile "isl-${CT_ISL_VERSION}"                                      \
        ftp://gcc.gnu.org/pub/gcc/infrastructure
}

# Extract PPL
do_isl_extract() {
    CT_Extract "isl-${CT_ISL_VERSION}"
    CT_Patch "isl" "${CT_ISL_VERSION}"
}

do_isl() {
    mkdir -p "${CT_BUILD_DIR}/build-isl"
    cd "${CT_BUILD_DIR}/build-isl"

    CT_DoStep INFO "Installing ISL"

    CT_DoLog EXTRA "Configuring ISL"

    CT_DoExecLog CFG                                \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"                  \
    CXXFLAGS="${CT_CFLAGS_FOR_HOST}"                \
    "${CT_SRC_DIR}/isl-${CT_ISL_VERSION}/configure" \
        --build=${CT_BUILD}                         \
        --host=${CT_HOST}                           \
        --prefix="${CT_COMPLIBS_DIR}"               \
        --with-gmp-prefix="${CT_COMPLIBS_DIR}"      \
        --disable-shared                            \
        --enable-static

    CT_DoLog EXTRA "Building ISL"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking ISL"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing ISL"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_ISL
