# This file adds functions to fetch and use a prebuilt sysroot.
# Copyright 2011  Linaro Limited
# Licensed under the GPL v2. See COPYING in the root of this package

do_libc_get() {
    CT_DoLog DEBUG "Fetching ${CT_PREBUILT_NAME}"
    CT_GetFile "${CT_PREBUILT_NAME}" "${CT_PREBUILT_BASE_URL}"

    return 0
}

do_libc_extract() {
    CT_Extract "${CT_PREBUILT_NAME}"
    CT_Pushd "${CT_SRC_DIR}/${CT_PREBUILT_NAME}"
    CT_Patch nochdir "prebuilt" "${CT_PREBUILT_NAME}"
    CT_Popd
}

do_libc_check_config() {
    :
}

do_libc_start_files() {
    # do_kernel_headers has already run
    CT_DoLog EXTRA "Installing the pre-built sysroot"
    CT_DoExecLog ALL cp -av "${CT_SRC_DIR}/${CT_PREBUILT_NAME}"/* "${CT_SYSROOT_DIR}"
}

do_libc() {
    :
}

do_libc_finish() {
    :
}
