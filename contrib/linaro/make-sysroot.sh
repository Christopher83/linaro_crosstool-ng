#!/bin/bash
#
# Makes a sysroot from a Ubuntu release.  Tries to follow the same
# style as multistrap.
#
# make-sysroot.sh squeeze armel http://ftp.nz.debian.org/debian/ main
# make-sysroot.sh wheezy armhf http://archive.raspbian.org/raspbian main none
#

set -e

# Configuration

# Suite to fetch (natty, oneiric, testing, ...)
suite=${1:-precise}
arch=${2:-armhf}
otherarch=${5:-armel}
if [ "$otherarch" = "none" ]; then otherarch= ; fi

# Mirror to fetch from
source=${3:-http://ports.ubuntu.com/ubuntu-ports/}
components=${4:-"main universe"}
packages="libc6 libc6-dev libc6-dbg linux-libc-dev"
#roots="xaos gnome-games"
roots=
exclude="libgcc* libstdc++* libbz2* libselinux*"

# Locals

build=build
# Where to fetch patches
dist=$build/dist
# Where to build the temporary sysroot
sysroot=$build/libc

etc=$dist/$suite/etc
archives=$dist/$suite/var/cache/apt/archives

# Start afresh
rm -rf $build
mkdir -p $dist $sysroot

# Create the distro
chdist --data-dir $dist --arch $arch create $suite
# Make a couple of directories to supress APT warnings
mkdir -p $etc/apt/{apt.conf.d,preferences.d}

# Suppress downloading i386
echo "APT::Architectures { \"$otherarch\" };" >> $etc/apt/apt.conf

if [ ! -z "$otherarch" ]; then
    mkdir -p $etc/dpkg/dpkg.cfg.d
    echo 'foreign-architecture $otherarch' >> $etc/dpkg/dpkg.cfg.d/multiarch
fi

# Create the source list and update
cat > $etc/apt/sources.list <<EOF
deb $source $suite $components
deb-src $source $suite $components
EOF

flags="-qq -y --force-yes"

chdist --data-dir $dist apt-get $suite $flags update

# Grab all of the packages
for i in $packages; do
    package="$i"
    if [ ! -z "$otherarch" ]; then package="$package $package:$otherarch"; fi
    chdist --data-dir $dist apt-get $suite install $flags -d --no-install-recommends $package
done

# And the build-deps of the roots
if [ -n "$roots" ]; then
    chdist --data-dir $dist apt-get $suite build-dep $flags -d --no-install-recommends $roots
fi

# Remove any troublesome packages
for i in $exclude; do
    rm -vf $archives/$i.deb
done

# Extract the packages that we want and all devel-like packages
for i in $packages "lib*" "*-dev"; do
    for j in $archives/${i}_*.deb; do
        echo Extracting $( basename $j )
        dpkg-deb -x $j $sysroot
    done
done

# Tidy up
rm -rf $sysroot/etc $sysroot/usr/{sbin,bin}

# Some packages include absolute links in sysroot/usr/lib.
# Convert to relative links instead
for lib in $( find $sysroot -type l ); do
    target=$( readlink $lib )
    base=$( basename $target )

    case $target in
        /*)
            v=$( echo $lib | sed -r "s#^$sysroot/##" | tr -cd / | sed "s#/#../#g" )
            p=$( echo $target | sed "s#^/##" )
            rm $lib
            if [ -f $( dirname $lib )'/'$v$p ]; then
                ln -s $v$p $lib
            fi
            ;;
        *)  ;;
    esac
done

# Tarball it up
tar caf $suite-sysroot-$arch-1+bzr$(bzr revno).tar.bz2 -C $build $(basename $sysroot)
