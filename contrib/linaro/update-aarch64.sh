#!/bin/bash
#
# Update the aarch64 versions to the latest snapshots
#
# This only works from Michael's network.  Fix.
# An ugly hack with poor style.  Fix.
#

invoke="ssh cbuild@orion"
ctools="~/lib/cbuild-tools"
clib=~/linaro/cbuild/lib
repos="~/repos"

# Make the snapshots
snapshot() {
    # Enable those you want to snapshot
    false && $invoke "$ctools/export-git.sh" "$repos/binutils-trunk" binutils-2.24~
    false && $invoke "$ctools/up_branch.sh" "$repos/gcc-arm-aarch64-4.7" gcc-arm-aarch64-4.7+
    false && $invoke "$ctools/export-git.sh" "$repos/newlib" newlib-1.21~
}

make_tarball() {
    # Make a tarball from the xdelta if it doesn't already exist
    local latest=$1

    if ! grep -qF $latest.tar.xz snapshots.txt; then
        make -f $clib/fetch.mk B=$latest HTTPSNAPSHOTS=orion/snapshots TOPDIR=$clib/..
        mv $latest/$latest.tar .
        xz $latest.tar
        rsync -t --progress $latest.tar.xz cbuild@orion:~/snapshots
    fi
}

latest() {
    # Pull the latest version from the file list
    grep $1 snapshots.txt | tail -n1 | sed -r 's/\.tar.+//'
}

get_version() {
    # Drop the first word to pull out the crosstool-NG style version
    echo $1 | sed -r 's/[^\-]+-//'
}

move_patches() {
    # Rename the patches to the latest version
    if [ ! -d contrib/linaro/patches/$1/$3 ]; then
        if [ -d contrib/linaro/patches/$1/$2* ]; then
            bzr mv contrib/linaro/patches/$1/$2* contrib/linaro/patches/$1/$3
        fi
    fi
}

snapshot

# Find the latest versions
$invoke ls "~/snapshots" | sort > snapshots.txt

binutils_latest=$(latest binutils-2.24~)
gcc_latest=$(latest gcc-arm-aarch64-4.7+svn)
newlib_latest=$(latest newlib-1.21~)
gdb_latest=$(latest gdb-7.6~)
eglibc_latest=$(latest eglibc-2.16+svn)
ports_latest=$(latest eglibc-ports-2.16+svn)

# HACK: override to match OpenEmbedded
binutils_latest="binutils-2.24~20120920+gitb05c76f"
gcc_latest="gcc-arm-aarch64-4.7+svn191987"
eglibc_latest="eglibc-2.16+svn20393"
ports_latest="eglibc-ports-2.16+svn20393"

binutils_version=$(get_version $binutils_latest)
gcc_version=$(get_version $gcc_latest)
newlib_version=$(get_version $newlib_latest)
gdb_version=$(get_version $gdb_latest)
eglibc_version=$(get_version $eglibc_latest)
ports_version=$(get_version $ports_latest)

# Make tarballs of each
make_tarball $binutils_latest
make_tarball $gcc_latest
make_tarball $newlib_latest
make_tarball $gdb_latest
make_tarball $eglibc_latest
make_tarball $ports_latest

# Update the config files
sed -i -r "s#arm-aarch64-4[^ \"]*#$gcc_version#" config/cc/gcc.in
sed -i -r "s#2\.24~[^ \"]*#$binutils_version#" config/binutils/binutils.in
sed -i -r "s#1\.21~[^ \"]*#$newlib_version#" config/libc/newlib.in
sed -i -r "s#7\.6~[^ \"]*#$gdb_version#" config/debug/gdb.in
sed -i -r "s#2\.16+[^ \"]*#$eglibc_version#" config/libc/eglibc.in

move_patches gcc arm-aarch64 $gcc_version
move_patches binutils 2.24~ $binutils_version
move_patches newlib 1.21~ $newlib_version
move_patches gdb 7.3~ $gdb_version
move_patches eglibc ports-2_16+ $ports_version
