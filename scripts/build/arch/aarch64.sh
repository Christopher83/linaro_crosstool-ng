# Compute ARM-specific values

CT_DoArchTupleValues() {
    # The architecture part of the tuple:
    [ "${CT_ARCH_BE}" = "y" ] && target_endian_eb="_be"
    CT_TARGET_ARCH="${CT_ARCH}${target_endian_eb}"
    CT_ARCH_WITH_FLOAT=
    CT_ARCH_FLOAT_CFLAG=
    # On Linux the architecture is arm64
    CT_LINUX_ARCH=arm64
}
