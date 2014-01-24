# download and unzip installjammer

set -e

HERE=$( dirname $0 )
DEST=$HERE/../../../builds/win32installer

rm -rf $DEST
mkdir -p $DEST

mirror=https://launchpad.net/linaro-toolchain-binaries/support/01/+download/
INSTALLJAMMER=installjammer-1.3-snapshot.tar.gz

pushd $DEST
wget -nv -N $mirror/$INSTALLJAMMER
tar xzf $INSTALLJAMMER
popd
