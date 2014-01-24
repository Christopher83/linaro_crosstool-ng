# Wrapper to build the companion tools facilities

# List all companion tools facilities, and parse their scripts
CT_CROSS_EXTRAS_FACILITY_LIST=
for f in "${CT_LIB_DIR}/scripts/build/cross_extras/"*.sh; do
    _f="$(basename "${f}" .sh)"
    _f="${_f#???-}"
    __f="CT_CROSS_EXTRAS_${_f}"
    if [ "${!__f}" = "y" ]; then
        CT_DoLog DEBUG "Enabling cross extras '${_f}'"
        . "${f}"
        CT_CROSS_EXTRAS_FACILITY_LIST="${CT_CROSS_EXTRAS_FACILITY_LIST} ${_f}"
    else
        CT_DoLog DEBUG "Disabling cross extras '${_f}'"
    fi
done

# Download the cross extras facilities
do_cross_extras_get() {
    for f in ${CT_CROSS_EXTRAS_FACILITY_LIST}; do
        do_cross_extras_${f}_get
    done
}

# Extract and patch the cross extras facilities
do_cross_extras_extract() {
    for f in ${CT_CROSS_EXTRAS_FACILITY_LIST}; do
        do_cross_extras_${f}_extract
    done
}

# Build the cross extras facilities
do_cross_extras() {
    for f in ${CT_CROSS_EXTRAS_FACILITY_LIST}; do
        do_cross_extras_${f}_build
    done
}
