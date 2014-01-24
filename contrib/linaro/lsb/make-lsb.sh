# Builds a patched version of the LSB development files.
#
# Usage:
#  cd contrib/linaro/lsb
#  ./make-lsb.sh $dest
#  . $dest/env.sh
# 

set -e

DEST=${1:-../../../builds/lsb}
HERE=$( dirname $0 )

rm -rf $DEST
mkdir -p $DEST

base=$( readlink -f $PWD/$DEST )
arch=$( dpkg-architecture -qDEB_HOST_ARCH )
pool=http://archive.ubuntu.com/ubuntu/pool/

# Grab the original if needed
(cd $DEST && \
    wget -nv -N $pool/universe/l/lsb-build-base3/lsb-build-base3_3.2.2~pre1-1.2_$arch.deb)

# Extract all archives
ls $DEST/*$arch.deb | xargs -t -I{} dpkg-deb -x {} $DEST
# and patch
cat $HERE/*lsbenv-*.patch | patch -d $DEST -p1 -s

# Grab, patch, and build lsbcc
(cd $DEST && \
    wget -nv -N $pool/universe/l/lsb-build-cc3/lsb-build-cc3_3.2.0.orig.tar.gz)

mkdir -p $DEST/build
tar xzf $DEST/lsb-build*tar.gz -C $DEST/build
cat $HERE/*lsbcc-*.patch | patch -p1 -d $DEST/build/lsb-*
make -s -C $DEST/build/lsb-* all install INSTALL_ROOT=$base BINDIR=bin MANDIR=usr/man

# Set up an environment for when playing about with builds
env=$DEST/env.sh
usr=$base/usr
ver=4.1

cat > $env <<EOF
export PATH=$base/bin:\$PATH
export LSBCC=gcc-$ver
export LSBCXX=g++-$ver
export LSBCC_LIBS=$usr/lib/lsb3
export LSBCC_INCLUDES=$usr/include/lsb3
export LSBCXX_INCLUDES=$usr/include/lsb3/c++
EOF

if [ "$arch" = "amd64" ]; then
    echo export LSBCC_LDSO=/lib/ld-linux-x86-64.so.2 >> $env
else
    echo export LSBCC_LDSO=/lib/ld-linux.so.2 >> $env
fi

