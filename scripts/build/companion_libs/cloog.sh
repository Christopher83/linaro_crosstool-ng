# This file adds the functions to build the CLooG library
# Copyright 2009 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

do_cloog_get() { :; }
do_cloog_extract() { :; }
do_cloog() { :; }

# Overide functions depending on configuration
if [ "${CT_CLOOG}" = "y" ]; then

# Download CLooG
do_cloog_get() {
    CT_GetFile "cloog-${CT_CLOOG_VERSION}"  \
        ftp://gcc.gnu.org/pub/gcc/infrastructure
}

# Extract CLooG
do_cloog_extract() {
    CT_Extract "cloog-${CT_CLOOG_VERSION}"
    CT_Patch "cloog" "${CT_CLOOG_VERSION}"
}

do_cloog() {
    mkdir -p "${CT_BUILD_DIR}/build-cloog"
    cd "${CT_BUILD_DIR}/build-cloog"

    CT_DoStep INFO "Installing CLooG"

    CT_DoLog EXTRA "Configuring CLooG"

    CT_DoExecLog CFG                            \
    CFLAGS="${CT_CFLAGS_FOR_HOST}"              \
    "${CT_SRC_DIR}/cloog-${CT_CLOOG_VERSION}/configure"    \
        --build=${CT_BUILD}                     \
        --host=${CT_HOST}                       \
        --prefix="${CT_COMPLIBS_DIR}"           \
        --with-gmp-prefix="${CT_COMPLIBS_DIR}"  \
        --with-isl-prefix="${CT_COMPLIBS_DIR}"  \
        --disable-shared                        \
        --enable-static

    CT_DoLog EXTRA "Building CLooG"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        CT_DoLog EXTRA "Checking CLooG"
        CT_DoExecLog ALL make ${JOBSFLAGS} -s check
    fi

    CT_DoLog EXTRA "Installing CLooG"
    CT_DoExecLog ALL make install

    CT_EndStep
}

fi # CT_CLOOG
