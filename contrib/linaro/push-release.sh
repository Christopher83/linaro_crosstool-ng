#!/bin/bash
#
# Pulls the latest release from S3 and pushes to Launchpad.
#

set -e

s3=s3://linaro-toolchain-builds

mkdir -p release/work release/files

accept="linux.tar.bz2 win32.exe win32.zip src.tar.bz2 runtime.tar.bz2"
# Use when testing
#accept="linux.tar.bz2 win32.exe win32.zip"

# LEB
target=arm-linux-gnueabihf
project=https://launchpad.net/linaro-toolchain-binaries

# Baremetal
#target=${1:-arm-none-eabi}
#project=${2:-https://launchpad.net/linaro-toolchain-unsupported}

# Get a list of everything in S3
s3cmd ls $s3 | awk -F/ '{ print $NF }' > release/work/all

# Make a list of all the releases
latest=$( grep -P "^gcc-linaro-$target.*-201.\.\d\d-20\d+_.+\.asc" release/work/all \
    | sed -r 's#.+-(201[0-9]\.[0-9]+-[0-9]+).+#\1#' \
    | sort | uniq | tail -n 1 )

milestone=$( echo $latest | awk -F- '{ print $1; }' )
echo Latest release is $latest for milestone $milestone

# Grab the Launchpad page.  Add a ? to defeat the caching
page=$project/trunk/$milestone
wget --quiet -O release/work/page $page\?

# Pull out the existing files
sed -r "s/(href=)/\n\1/" release/work/page | grep ^href > release/work/existing

# Filter out just the builds and the particular ones we publish
grep -F "${latest}_" release/work/all | grep -F $target > release/work/latest
echo > release/work/fetch

for i in $accept; do
    grep "$i\$" release/work/latest >> release/work/fetch || echo "Warning: no $i files found"
done

echo > release/work/present
echo > release/work/missing

for i in $(cat release/work/fetch); do
    grep -qF $i release/work/existing || echo $i >> release/work/missing
    grep -qF $i release/work/existing && echo $i >> release/work/present
done

echo The project page at $page contains: $(cat release/work/present)
echo Will upload: $(cat release/work/missing)

echo Fetching $( cat release/work/fetch )
cat release/work/fetch | xargs -L 1 -I{} -P 3 s3cmd get -p --no-progress --continue $s3/{} release/files || true
cat release/work/fetch | xargs -L 1 -I{} -P 3 s3cmd get -p --force --no-progress $s3/{}.asc release/files

[ -z "$LP_COOKIE" ] && echo "Need your Launchpad cookie in \$LP_COOKIE before uploading" && exit 1

read -p "Continue the upload (y/n)? "
[ "$REPLY" != "y" ] && exit 0

for i in $(cat release/work/missing); do
    case $i in
	*src.tar*) description="Source"; type="CODETARBALL"; ;;
	*runtime.tar*) description="Target runtime"; type="CODETARBALL"; ;;
	*linux.tar*)  description="Linux binary"; type="INSTALLER"; ;;
	*win32.exe*)  description="Windows installer" type="INSTALLER"; ;;
	*win32.zip*)  description="Windows binary" type="INSTALLER" ;;
	*)  echo "Unrecognised type"; exit 1 ;;
    esac

    echo "Adding $i ($description, a $type)"

    curl -f -o - \
	$page/+adddownloadfile \
	-e $page/+adddownloadfile \
	-b lp=$LP_COOKIE \
	-F "field.description=$description" \
	-F "field.filecontent.used=" \
	-F "field.filecontent=@release/files/$i" \
	-F "field.signature.used=" \
	-F "field.signature=@release/files/$i.asc" \
	-F "field.contenttype=$type" \
	-F "field.contenttype-empty-marker=1" \
	-F "field.actions.add=Upload"
done
