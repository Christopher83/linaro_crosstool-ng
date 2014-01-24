# Build script for pkgconfig

# 0.25 and earlier include a copy of glib which makes things much easier
# Note that glib 2.30 and above depend on libffi
CT_PKG_CONFIG_VERSION=0.25

do_cross_extras_pkg_config_get() {
    CT_GetFile "pkg-config-${CT_PKG_CONFIG_VERSION}" \
               http://pkgconfig.freedesktop.org/releases
}

do_cross_extras_pkg_config_extract() {
    CT_Extract "pkg-config-${CT_PKG_CONFIG_VERSION}"
    CT_Patch "pkg-config" "${CT_PKG_CONFIG_VERSION}"
}

do_cross_extras_pkg_config_build() {
    CT_DoStep EXTRA "Installing pkg-config"
    mkdir -p "${CT_BUILD_DIR}/build-pkg-config"
    CT_Pushd "${CT_BUILD_DIR}/build-pkg-config"

    CT_DoExecLog CFG \
        "${CT_SRC_DIR}/pkg-config-${CT_PKG_CONFIG_VERSION}/configure" \
        --prefix="${CT_PREFIX_DIR}"            \
        --build=${CT_BUILD}                    \
        --host=${CT_HOST}                      \
        --program-prefix=${CT_TARGET}-         \
        --program-suffix=-real                 \
        --with-pc-path="${CT_SYSROOT_DIR}/usr/lib/${CT_TARGET}/pkgconfig:${CT_SYSROOT_DIR}/usr/lib//pkgconfig:${CT_SYSROOT_DIR}/usr/share/pkgconfig"

    CT_DoExecLog ALL make ${JOBFLAGS}
    CT_DoExecLog ALL make install

    # Make a wrapper that handles relocatable sysroots
    CT_DoExecLog ALL cp -a "${CT_LIB_DIR}/scripts/build/cross_extras/pkg-config-wrapper" "${CT_PREFIX_DIR}/bin/${CT_TARGET}-pkg-config"

    CT_Popd
    CT_EndStep
}
