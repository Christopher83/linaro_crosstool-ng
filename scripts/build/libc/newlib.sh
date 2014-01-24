# This file adds functions to build the Newlib C library
# Copyright 2009 DoréDevelopment
# Licensed under the GPL v2. See COPYING in the root of this package
#
# Edited by Martin Lund <mgl@doredevelopment.dk>
#

libc_newlib_version() {
    if [ -z "${CT_LIBC_NEWLIB_CVS}" ]; then
        echo "${CT_LIBC_VERSION}"
    else
        echo "cvs${CT_LIBC_VERSION:+-${CT_LIBC_VERSION}}"
    fi
}

do_libc_get() {
    local avr32headers_src

    avr32headers_src="http://dev.doredevelopment.dk/avr32-toolchain/sources"

    if echo ${CT_LIBC_VERSION} |grep -q linaro; then
        YYMM=`echo ${CT_LIBC_VERSION} |cut -d- -f3 |sed -e 's,^..,,'`
    fi

    if [ -z "${CT_LIBC_NEWLIB_CVS}" ]; then
        CT_GetFile "newlib-${CT_LIBC_VERSION}"         \
                   ftp://sources.redhat.com/pub/newlib \
                   http://mirrors.kernel.org/sources.redhat.com/newlib \
                   https://releases.linaro.org/${YYMM}/components/toolchain/newlib-linaro \
                   http://cbuild.validation.linaro.org/snapshots
    else
        CT_GetCVS "newlib-$(libc_newlib_version)"                   \
                  ":pserver:anoncvs@sources.redhat.com:/cvs/src"    \
                  "newlib"                                          \
                  "${CT_LIBC_VERSION}"                              \
                  "newlib-$(libc_newlib_version)=src"
    fi

    if [ "${CT_ATMEL_AVR32_HEADERS}" = "y" ]; then
        CT_GetFile "avr32headers" ${avr32headers_src}
    fi
}

do_libc_extract() {
    CT_Extract "newlib-$(libc_newlib_version)"
    CT_Patch "newlib" "$(libc_newlib_version)"

    if [ "${CT_ATMEL_AVR32_HEADERS}" = "y" ]; then
        CT_Extract "avr32headers"
    fi
}

do_libc_check_config() {
    :
}

do_libc_start_files() {
    local -a newlib_opts

    CT_DoStep INFO "Installing C library"

    mkdir -p "${CT_BUILD_DIR}/build-libc"
    cd "${CT_BUILD_DIR}/build-libc"

    CT_DoLog EXTRA "Configuring C library"

    if [ "${CT_LIBC_NEWLIB_IO_C99FMT}" = "y" ]; then
        newlib_opts+=( "--enable-newlib-io-c99-formats" )
    else
        newlib_opts+=( "--disable-newlib-io-c99-formats" )
    fi
    if [ "${CT_LIBC_NEWLIB_IO_LL}" = "y" ]; then
        newlib_opts+=( "--enable-newlib-io-long-long" )
    else
        newlib_opts+=( "--disable-newlib-io-long-long" )
    fi
    if [ "${CT_LIBC_NEWLIB_IO_FLOAT}" = "y" ]; then
        newlib_opts+=( "--enable-newlib-io-float" )
        if [ "${CT_LIBC_NEWLIB_IO_LDBL}" = "y" ]; then
            newlib_opts+=( "--enable-newlib-io-long-double" )
        else
            newlib_opts+=( "--disable-newlib-io-long-double" )
        fi
    else
        newlib_opts+=( "--disable-newlib-io-float" )
        newlib_opts+=( "--disable-newlib-io-long-double" )
    fi
    if [ "${CT_LIBC_NEWLIB_DISABLE_SUPPLIED_SYSCALLS}" = "y" ]; then
        newlib_opts+=( "--disable-newlib-supplied-syscalls" )
    else
        newlib_opts+=( "--enable-newlib-supplied-syscalls" )
    fi

    [ "${CT_LIBC_NEWLIB_ENABLE_TARGET_OPTSPACE}" = "y" ] && newlib_opts+=("--enable-target-optspace")

    # Note: newlib handles the build/host/target a little bit differently
    # than one would expect:
    #   build  : not used
    #   host   : the machine building newlib
    #   target : the machine newlib runs on
    CT_DoExecLog CFG                                    \
    CC_FOR_BUILD="${CT_BUILD}-gcc"                      \
    CFLAGS_FOR_TARGET="${CT_TARGET_CFLAGS}"             \
    AR=${CT_TARGET}-ar                                  \
    RANLIB=${CT_TARGET}-ranlib                          \
    "${CT_SRC_DIR}/newlib-$(libc_newlib_version)/configure" \
        --host=${CT_BUILD}                              \
        --target=${CT_TARGET}                           \
        --prefix=${CT_PREFIX_DIR}                       \
        "${newlib_opts[@]}"                             \
        "${CT_LIBC_NEWLIB_EXTRA_CONFIG_ARRAY[@]}"

    CT_DoLog EXTRA "Building C library"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing C library"
    CT_DoExecLog ALL make install install_root="${CT_SYSROOT_DIR}"

    if [ "${CT_BUILD_MANUALS}" = "y" ]; then
        local -a doc_dir="${CT_BUILD_DIR}/build-libc/${CT_TARGET}"

        CT_DoLog EXTRA "Building and installing the C library manual"
        CT_DoExecLog ALL make pdf html

        # NEWLIB install-{pdf.html} fail for some versions
        CT_DoExecLog ALL mkdir -p "${CT_PREFIX_DIR}/share/doc/newlib"
        CT_DoExecLog ALL cp -av "${doc_dir}/newlib/libc/libc.pdf"   \
                                "${doc_dir}/newlib/libm/libm.pdf"   \
                                "${doc_dir}/newlib/libc/libc.html"  \
                                "${doc_dir}/newlib/libm/libm.html"  \
                                "${CT_PREFIX_DIR}/share/doc/newlib"
    fi

    CT_EndStep
}

do_libc() {
    :
}

do_libc_finish() {
    CT_DoStep INFO "Finishing C library"
    
    if [ "${CT_ATMEL_AVR32_HEADERS}" = "y" ]; then
        CT_DoLog EXTRA "Installing Atmel's AVR32 headers"
        CT_DoExecLog ALL cp -r ${CT_SRC_DIR}/avr32headers "${CT_PREFIX_DIR}/${CT_TARGET}/include/avr32"
    fi

    CT_EndStep
}
