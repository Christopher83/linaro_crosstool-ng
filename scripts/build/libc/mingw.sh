do_libc_get() {
    CT_GetFile "mingwrt-${CT_MINGWRT_VERSION}-mingw32-src" \
        http://downloads.sourceforge.net/sourceforge/mingw

    if [ -n "${CT_MINGW_DIRECTX}" ]; then
        CT_GetFile "directx-devel" \
            http://www.libsdl.org/extras/win32/common
    fi
    if [ -n "${CT_MINGW_OPENGL}" ]; then
        CT_GetFile "opengl-devel" \
            http://www.libsdl.org/extras/win32/common
    fi
    if [ -n "${CT_MINGW_PDCURSES}" ]; then
        CT_GetFile "PDCurses-${CT_MINGW_PDCURSES_VERSION}" \
            http://downloads.sourceforge.net/sourceforge/pdcurses
    fi
    if [ -n "${CT_MINGW_GNURX}" ]; then
        CT_GetFile "mingw-libgnurx-${CT_MINGW_GNURX_VERSION}-src" \
            http://downloads.sourceforge.net/sourceforge/mingw
    fi
}

do_libc_extract() {
    CT_Extract "mingwrt-${CT_MINGWRT_VERSION}-mingw32-src"

    if [ -n "${CT_MINGW_PDCURSES}" ]; then
        CT_Extract "PDCurses-${CT_MINGW_PDCURSES_VERSION}"
        CT_Patch "PDCurses" "${CT_MINGW_PDCURSES_VERSION}"
    fi
    if [ -n "${CT_MINGW_GNURX}" ]; then
        CT_Extract "mingw-libgnurx-${CT_MINGW_GNURX_VERSION}-src"
        CT_Patch "mingw-libgnurx" "${CT_MINGW_GNURX_VERSION}-src"
    fi
}

do_libc_check_config() {
    :
}

do_libc_start_files() {
    CT_DoStep INFO "Installing C library headers"

    CT_DoLog EXTRA "Installing MinGW Runtime headers"
    mkdir -p "${CT_HEADERS_DIR}"
    cp -r ${CT_SRC_DIR}/mingwrt-${CT_MINGWRT_VERSION}-mingw32-src/include/* \
          ${CT_HEADERS_DIR}

    # It seems mingw is strangely set up to look into /mingw instead of
    # /usr (notably when looking for the headers). This symlink is
    # here to workaround this, and seems to be here to last... :-/
    CT_DoExecLog ALL ln -sv "usr" "${CT_SYSROOT_DIR}/mingw"

    CT_EndStep
}

do_libc() {
    CT_DoStep INFO "Building MinGW files"

    CT_DoLog EXTRA "Configuring W32-API"

    mkdir -p "${CT_BUILD_DIR}/build-w32api"
    cd "${CT_BUILD_DIR}/build-w32api"

    CT_DoExecLog CFG                                                  \
    CFLAGS="-I${CT_HEADERS_DIR}"                                      \
    LDFLAGS="-L${CT_SYSROOT_DIR}/lib"                                 \
    "${CT_SRC_DIR}/w32api-${CT_W32API_VERSION}-mingw32-src/configure" \
        --prefix=${CT_SYSROOT_DIR}                                    \
        --includedir=${CT_HEADERS_DIR}                                \
        --host=${CT_TARGET}

    CT_DoLog EXTRA "Building W32-API"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing W32-API"
    CT_DoExecLog ALL make install

    CT_DoLog EXTRA "Configuring MinGW Runtime"

    mkdir -p "${CT_BUILD_DIR}/build-mingwrt"
    cd "${CT_BUILD_DIR}/build-mingwrt"

    CT_DoExecLog CFG                                                    \
    CFLAGS="-I${CT_HEADERS_DIR}"                                        \
    LDFLAGS="-L${CT_SYSROOT_DIR}/lib"                                   \
    "${CT_SRC_DIR}/mingwrt-${CT_MINGWRT_VERSION}-mingw32-src/configure" \
        --prefix=${CT_SYSROOT_DIR}/                                     \
        --includedir=${CT_HEADERS_DIR}                                  \
        --host=${CT_TARGET}

    CT_DoLog EXTRA "Building MinGW Runtime"
    CT_DoExecLog ALL make ${JOBSFLAGS}

    CT_DoLog EXTRA "Installing MinGW Runtime"
    CT_DoExecLog ALL make install

    CT_EndStep
}

do_libc_finish() {
    CT_DoStep INFO "Installing MinGW Development libraries"

    CT_Pushd "${CT_SYSROOT_DIR}"
    if [ -n "${CT_MINGW_DIRECTX}" ]; then
        CT_DoLog EXTRA "Installing DirectX development package"
        CT_Extract nochdir "directx-devel"
    fi
    if [ -n "${CT_MINGW_OPENGL}" ]; then
        CT_DoLog EXTRA "Installing OpenGL development package"
        CT_Extract nochdir "opengl-devel"
    fi
    CT_Popd

    if [ -n "${CT_MINGW_PDCURSES}" ]; then
        CT_DoLog EXTRA "Building PDCurses development files"
        mkdir -p "${CT_BUILD_DIR}/build-pdcurses"
        cd "${CT_BUILD_DIR}/build-pdcurses"

        make -f ${CT_SRC_DIR}/PDCurses-${CT_MINGW_PDCURSES_VERSION}/win32/mingwin32.mak libs \
            PDCURSES_SRCDIR=${CT_SRC_DIR}/PDCurses-${CT_MINGW_PDCURSES_VERSION} \
            CROSS_COMPILE=${CT_TARGET}-

        CT_DoLog EXTRA "Installing PDCurses development files"
        chmod a+r ${CT_SRC_DIR}/PDCurses-${CT_MINGW_PDCURSES_VERSION}/*.h
        cp ${CT_SRC_DIR}/PDCurses-${CT_MINGW_PDCURSES_VERSION}/*.h \
           ${CT_HEADERS_DIR}/
        cp pdcurses.a ${CT_SYSROOT_DIR}/lib/libpdcurses.a
        cp pdcurses.a ${CT_SYSROOT_DIR}/lib/libncurses.a
    fi

    if [ -n "${CT_MINGW_GNURX}" ]; then
        CT_DoLog EXTRA "Configuring GnuRX development files"

        mkdir -p "${CT_BUILD_DIR}/build-gnurx"
        cd "${CT_BUILD_DIR}/build-gnurx"

        CT_DoExecLog CFG                                                        \
        CFLAGS="${CT_CFLAGS_FOR_TARGET}"                                        \
        "${CT_SRC_DIR}/mingw-libgnurx-${CT_MINGW_GNURX_VERSION}-src/configure"  \
            --build=${CT_BUILD}                                                 \
            --host=${CT_TARGET}                                                 \
            --prefix=${CT_SYSROOT_DIR}                                          \
            --includedir=${CT_HEADERS_DIR}                                      \
            --enable-shared                                                     \
            --enable-static

        CT_DoLog EXTRA "Building GnuRX development files"
        CT_DoExecLog ALL make ${JOBSFLAGS}

        CT_DoLog EXTRA "Installing GnuRX development files"
        CT_DoExecLog ALL make install-dev
    fi

    CT_EndStep
}

