# This file adds functions to build binutils
# Copyright 2007 Yann E. MORIN
# Licensed under the GPL v2. See COPYING in the root of this package

# Download binutils
do_binutils_get() {
    if echo ${CT_BINUTILS_VERSION} |grep -q linaro; then
        YYMM=`echo ${CT_BINUTILS_VERSION} |cut -d- -f3 |sed -e 's,^..,,'`
    fi
    CT_GetFile "binutils-${CT_BINUTILS_VERSION}"                                        \
               {ftp,http}://{ftp.gnu.org/gnu,ftp.kernel.org/pub/linux/devel}/binutils   \
               ftp://gcc.gnu.org/pub/binutils/{releases,snapshots} \
               https://releases.linaro.org/${YYMM}/components/toolchain/binutils-linaro \
               http://cbuild.validation.linaro.org/snapshots
}

# Extract binutils
do_binutils_extract() {
    CT_Extract "binutils-${CT_BINUTILS_VERSION}"
    CT_Patch "binutils" "${CT_BINUTILS_VERSION}"
}

# Build binutils
do_binutils() {
    local -a extra_config
    local -a extra_make_flags
    local -a binutils_tools
    local -a manuals_for
    local -a manuals_install
    local -a binutils_CFLAGS
    local -a binutils_LDFLAGS

    mkdir -p "${CT_BUILD_DIR}/build-binutils"
    cd "${CT_BUILD_DIR}/build-binutils"

    CT_DoStep INFO "Installing binutils"

    CT_DoLog EXTRA "Configuring binutils"

    binutils_tools=( ar as ld strip )
    if [ "${CT_BINUTILS_HAS_GOLD}" = "y" ]; then
        case "${CT_BINUTILS_LINKERS_LIST}" in
            ld)
                extra_config+=( --enable-ld=yes --enable-gold=no )
                binutils_tools+=( ld.bfd )
                ;;
            gold)
                extra_config+=( --enable-ld=no --enable-gold=yes )
                binutils_tools+=( ld.gold )
                ;;
            ld,gold)
                extra_config+=( --enable-ld=default --enable-gold=yes )
                binutils_tools+=( ld.bfd ld.gold )
                ;;
            gold,ld)
                extra_config+=( --enable-ld=yes --enable-gold=default )
                binutils_tools+=( ld.bfd ld.gold )
                ;;
        esac
        if [ "${CT_BINUTILS_GOLD_THREADS}" = "y" ]; then
            extra_config+=( --enable-threads )
        fi
    fi
    if [ "${CT_BINUTILS_PLUGINS}" = "y" ]; then
        extra_config+=( --enable-plugins )
    fi
    if [ "${CT_BINUTILS_HAS_PKGVERSION_BUGURL}" = "y" ]; then
        extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
        [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
    fi

    [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] && extra_config+=("--disable-nls")

    [ "${CT_LIBICONV_NEEDED}" = "y" ] && extra_config+=("--with-libiconv-prefix=${CT_COMPLIBS_DIR}")

    CT_DoLog DEBUG "Extra config passed: '${extra_config[*]}'"

    binutils_CFLAGS+=${CT_CFLAGS_FOR_HOST}
    if [ "${CT_ZLIB_NEEDED}" = "y" ]; then
        binutils_CFLAGS+=" -I${CT_COMPLIBS_DIR}/zlib/include"
        binutils_LDFLAGS+=" -L${CT_COMPLIBS_DIR}/zlib/lib"
    fi

    CT_DoExecLog CFG                                            \
    CFLAGS="${binutils_CFLAGS}"                                 \
    CXXFLAGS="${binutils_CFLAGS}"                               \
    LDFLAGS="${binutils_LDFLAGS}"                               \
    "${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}/configure"   \
        --build=${CT_BUILD}                                     \
        --host=${CT_HOST}                                       \
        --target=${CT_TARGET}                                   \
        --prefix=${CT_PREFIX_DIR}                               \
        --disable-multilib                                      \
        --disable-werror                                        \
        "${extra_config[@]}"                                    \
        ${CT_ARCH_WITH_FLOAT}                                   \
        ${BINUTILS_SYSROOT_ARG}                                 \
        "${CT_BINUTILS_EXTRA_CONFIG_ARRAY[@]}"

    if [ "${CT_STATIC_TOOLCHAIN}" = "y" ]; then
        extra_make_flags+=("LDFLAGS=-static -all-static")
        CT_DoLog EXTRA "Prepare binutils for static build"
        CT_DoExecLog ALL make ${JOBSFLAGS} configure-host
    fi

    CT_DoLog EXTRA "Building binutils"
    CT_DoExecLog ALL make "${extra_make_flags[@]}" ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing binutils"
    CT_DoExecLog ALL make install

    if [ "${CT_BUILD_MANUALS}" = "y" ]; then
        CT_DoLog EXTRA "Building and installing the binutils manuals"
        manuals_for=( gas binutils ld gprof )
        if [ "${CT_BINUTILS_LINKER_GOLD}" = "y" ]; then
            manuals_for+=( gold )
        fi
        manuals_install=( "${manuals_for[@]/#/install-pdf-}" )
        manuals_install+=( "${manuals_for[@]/#/install-html-}" )
        CT_DoExecLog ALL make ${JOBSFLAGS} pdf html
        CT_DoExecLog ALL make "${manuals_install[@]}"
    fi

    # Install the wrapper if needed
    if [ "${CT_BINUTILS_LD_WRAPPER}" = "y" ]; then
        CT_DoLog EXTRA "Installing ld wrapper"
        rm -f "${CT_PREFIX_DIR}/bin/${CT_TARGET}-ld"
        rm -f "${CT_PREFIX_DIR}/${CT_TARGET}/bin/ld"
        sed -r -e "s/@@DEFAULT_LD@@/${CT_BINUTILS_LINKER_DEFAULT}/" \
            "${CT_LIB_DIR}/scripts/build/binutils/binutils-ld.in"   \
            >"${CT_PREFIX_DIR}/bin/${CT_TARGET}-ld"
        chmod +x "${CT_PREFIX_DIR}/bin/${CT_TARGET}-ld"
        cp -a "${CT_PREFIX_DIR}/bin/${CT_TARGET}-ld"    \
              "${CT_PREFIX_DIR}/${CT_TARGET}/bin/ld"

        # If needed, force using ld.bfd during the toolchain build
        if [ "${CT_BINUTILS_FORCE_LD_BFD}" = "y" ]; then
            export CTNG_LD_IS=bfd
        fi
    fi

    # Make those new tools available to the core C compilers to come.
    # Note: some components want the ${TARGET}-{ar,as,ld,strip} commands as
    # well. Create that.
    mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/bin"
    mkdir -p "${CT_CC_CORE_STATIC_PREFIX_DIR}/bin"
    mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/bin"
    mkdir -p "${CT_CC_CORE_SHARED_PREFIX_DIR}/bin"
    for t in "${binutils_tools[@]}"; do
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_STATIC_PREFIX_DIR}/${CT_TARGET}/bin/${t}"
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_STATIC_PREFIX_DIR}/bin/${CT_TARGET}-${t}"
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_SHARED_PREFIX_DIR}/${CT_TARGET}/bin/${t}"
        ln -sv "${CT_PREFIX_DIR}/bin/${CT_TARGET}-${t}" "${CT_CC_CORE_SHARED_PREFIX_DIR}/bin/${CT_TARGET}-${t}"
    done 2>&1 |CT_DoLog ALL

    CT_EndStep
}

# Now on for the target libraries
do_binutils_target() {
    local -a extra_config
    local -a targets
    local -a build_targets
    local -a install_targets
    local t

    [ "${CT_BINUTILS_FOR_TARGET_IBERTY}" = "y" ] && targets+=("libiberty")
    [ "${CT_BINUTILS_FOR_TARGET_BFD}"    = "y" ] && targets+=("bfd")
    for t in "${targets[@]}"; do
        build_targets+=("all-${t}")
        install_targets+=("install-${t}")
    done

    if [ "${#targets[@]}" -ne 0 ]; then
        CT_DoStep INFO "Installing binutils for target"
        mkdir -p "${CT_BUILD_DIR}/build-binutils-for-target"
        CT_Pushd "${CT_BUILD_DIR}/build-binutils-for-target"

        CT_DoLog EXTRA "Configuring binutils for target"

        if [ "${CT_BINUTILS_HAS_PKGVERSION_BUGURL}" = "y" ]; then
            extra_config+=("--with-pkgversion=${CT_PKGVERSION}")
            [ -n "${CT_TOOLCHAIN_BUGURL}" ] && extra_config+=("--with-bugurl=${CT_TOOLCHAIN_BUGURL}")
        fi

        [ "${CT_TOOLCHAIN_ENABLE_NLS}" != "y" ] && extra_config+=("--disable-nls")

        CT_DoExecLog CFG                                            \
        "${CT_SRC_DIR}/binutils-${CT_BINUTILS_VERSION}/configure"   \
            --build=${CT_BUILD}                                     \
            --host=${CT_TARGET}                                     \
            --target=${CT_TARGET}                                   \
            --prefix=/usr                                           \
            --disable-werror                                        \
            --enable-shared                                         \
            --enable-static                                         \
            --disable-multilib                                      \
            "${extra_config[@]}"                                    \
            ${CT_ARCH_WITH_FLOAT}                                   \
            "${CT_BINUTILS_EXTRA_CONFIG[@]}"

        CT_DoLog EXTRA "Building binutils' libraries (${targets[*]}) for target"
        CT_DoExecLog ALL make ${JOBSFLAGS} "${build_targets[@]}"
        CT_DoLog EXTRA "Installing binutils' libraries (${targets[*]}) for target"
        CT_DoExecLog ALL make DESTDIR="${CT_SYSROOT_DIR}" "${install_targets[@]}"

        CT_Popd
        CT_EndStep
    fi
}
