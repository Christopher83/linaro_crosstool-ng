#!/bin/bash
#
# Pulls the latest release from S3 to a local directory
#

set -e

s3=s3://linaro-toolchain-builds

# LEB
targets="arm-linux-gnueabihf aarch64-linux-gnu"

# Get a list of everything in S3
s3cmd ls $s3 | awk -F/ '{ print $NF }' > release/work/all

# Make a list of all the releases
latest=$( grep -P "^gcc-linaro-$(echo $targets |cut -d" " -f1).*-201.\.\d\d-20\d+_.+\.asc" release/work/all \
    | sed -r 's#.+-(201[0-9]\.[0-9]+-[0-9]+).+#\1#' \
    | sort | uniq | tail -n 1 )

milestone=$( echo $latest | awk -F- '{ print $1; }' )
echo Latest release is $latest for milestone $milestone

mkdir -p ~/release-${latest}
cd ~/release-${latest}
s3cmd ls $s3 |grep $latest |cut -b30- |while read f; do
	echo $f |grep -q '+bzr' && continue
	s3cmd get $f
done
for target in $targets; do
	md5sum gcc-linaro-$target-*-${latest}_linux.tar.bz2
	md5sum gcc-linaro-$target-*-${latest}_win32.exe
done
