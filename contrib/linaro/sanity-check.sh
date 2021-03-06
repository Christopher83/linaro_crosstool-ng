#!/bin/bash
#
# Automatically runs some of the sanity checks that need to be done for
# the release checksheet (use on a directory generated by download-release.sh)
#

set -e

[ -n "$1" ] && cd "$1"

targets="arm-linux-gnueabihf aarch64-linux-gnu"
pt=`echo $targets |cut -d" " -f1` # pt == primary target

for target in $targets; do
	if ! [ -e gcc-linaro-$target-*-*_linux.tar.bz2 ]; then
		echo "Usage: $0 /path/to/directory/generated/by/download-release.sh"
		exit 1
	fi
done
version=`ls gcc-linaro-$pt-*-*_linux.tar.bz2 |sed -e "s,gcc-linaro-$pt-[^-]*-,,;s,_.*,,"`
milestone=`echo $version |cut -d- -f1`

for target in $targets; do
	tar xf gcc-linaro-$target-*-*_linux.tar.bz2
	cd gcc-linaro-$target-*-*/bin
	for i in gcc g++ gfortran addr2line ar as c++filt gprof nm objcopy \
			objdump ranlib readelf size strings strip ld ld.bfd \
			ld.gold pkg-config gdb; do
		if ! ./$target-$i --help &>/dev/null; then
			if [ "$target-$i" = "aarch64-linux-gnu-ld.gold" ]; then
				echo "$target-$i fails to start (expected)"
			else
				echo "$target-$i fails to start"
			fi
		elif [ "$target-$i" = "aarch64-linux-gnu-ld.gold" ]; then
			echo "$target-$i started working"
		fi
	done
	for i in gcc as gdb; do
		if ! ./$target-$i --version 2>&1|head -n1 |grep -qE "linaro-[^-]*-[^-]*-$version"; then
			echo "Unexpected $i version in $target-$i:"
			./$target-$i --version
		fi
		if ! LANGUAGE=fr ./$target-$i --help 2>&1 |grep -q fichier; then
			if [ "$i" = "gdb" ]; then
				echo "$target-$i is missing a French translation (expected)"
			else
				echo "$target-$i is missing a French translation"
			fi
		elif [ "$i" = "gdb" ]; then
			echo "$target-$i added a French translation"
		fi
	done
	cd ..
	if ! [ -d share/doc ]; then
		echo "Documentation for $target missing"
	else
		if ! grep -q $milestone share/doc/gcc-linaro-$target/README.txt; then
			echo "Incorrect version number in gcc-linaro-$target/README.txt"
		fi
		for i in as binutils cpp gcc gdb gfortran gprof ld refcard; do
			if [ ! -e share/doc/gcc-linaro-$target/pdf/$i.pdf ]; then
				echo "Missing PDF doc for $target $i"
			fi
		done
		for i in as.html binutils.html cpp gcc gdb gfortran gprof.html ld.html; do
			if [ ! -d share/doc/gcc-linaro-$target/html/$i ]; then
				echo "Missing HTML doc for $target $i"
			fi
		done
		if ! grep -q $version share/doc/gcc-linaro-$target/html/gcc/index.html; then
			echo "Incorrect package version on GCC doc cover for $target"
		fi
	fi
	cd ..
	rm -rf gcc-linaro-$target-*-*_linux
done
