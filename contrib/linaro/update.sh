#!/bin/bash
# 
# (C) 2013-2014 Bernhard Rosenkränzer <Bernhard.Rosenkranzer@linaro.org>
# Released into the Public Domain.

# Convert a human readable version identifier (e.g. 4.8)
# into a machine comparable version identifier (e.g. 40008000000000000000)
version() {
	local OUT=0
	local O=0
	for i in `seq 1 4`; do
		O="`echo $1. |cut -d. -f$i -s |sed -e 's,0*,,'`"
		[ -z "$O" ] && O=0
		OUT=$((OUT*1000+$O))
	done
	echo $OUT
}

# Check the latest currently downloadable version of a Linaro project
current() {
	local SNAP=`curl -s http://cbuild.validation.linaro.org/snapshots/ |grep '^<tr>.*<td><a' |sed -e 's,^.*<a[^"]*",,;s,".*,,' |grep -v '.asc$' |grep -vE '(bzr|_rc|branch-merge|integration|test)' |grep "${1}-linaro-.*-20[0-9][0-9]\.[01]" |sort |sed -e "s,${1}-linaro-,,;s,\.tar.*,," |grep -E '^[0-9]'`
	local LATEST=""
	local V
	local CV
	local LV=0
	local CR
	local LR=0
	local CS
	local LS=0
	local WV=$(version ${2})
	for V in $SNAP; do
		CV=$(version $(echo $V |cut -d- -f1))
		[ "$WV" -eq 0 -o "$CV" -eq "$WV" ] || continue
		CR=$(version $(echo $V |cut -d- -f2))
		CS=$(version $(echo $V |cut -d- -f3))
		[ "$CV" -lt "$LV" ] && continue
		[ "$CV" -eq "$LV" ] && [ "$CR" -lt "$LR" ] && continue
		[ "$CV" -eq "$LV" ] && [ "$CR" -eq "$LR" ] && [ "$CS" -lt "$LS" ] && continue
		LATEST=$V
		LV=$CV
		LR=$CR
		LS=$CS
	done
	echo "$LATEST"
}

# Check the version of a Linaro component used in a config
used() {
	grep ^${1}= samples/${2}/crosstool.config|sed -e "s,.*=\"linaro-,,;s,\".*,,"
}

# Check the latest version of a component available in a config listing
available() {
	local AVAIL 
	local V
	local CV
	local LV=0
	local CR
	local LR=0
	local CS
	local LS=0
	if [ -n "${3}" ]; then
		AVAIL=`grep "^config ${1}_linaro_${3/./_}" ${2} |grep -v TIP |sed -e "s,^config ${1}_linaro_,,"`
	else
		AVAIL=`grep "^config ${1}_linaro_" ${2} |grep -v TIP |sed -e "s,^config ${1}_linaro_,,"`
	fi
	for V in $AVAIL; do
		CV=`echo $V |sed -e 's,_20[0-9][0-9].*,,'`
		CR=`echo $V |sed -e "s,${CV}_,,"`
		CS=`echo $CR |cut -d_ -f3-`
		CR=`echo $CR |cut -d_ -f1-2`
		CV="`echo ${CV/_/.}`"
		CR="`echo ${CR/_/.}`"
		[ "`version $CV`" -lt "`version $LV`" ] && continue
		[ "`version $CV`" -eq "`version $LV`" ] && [ "`version $CR`" -lt "`version $LR`" ] && continue
		[ "`version $CV`" -eq "`version $LV`" ] && [ "`version $CR`" -eq "`version $LR`" ] && [ "`version $CS`" -lt "`version $LS`" ] && continue
		LATEST=$V
		LV=$CV
		LR=$CR
		LS=$CS
	done
	if [ -n "$LS" ]; then
		echo $LV-$LR-$LS
	else
		echo $LV-$LR
	fi
}

cd "`dirname $0`/../.."

USED_GCC=`used CT_CC_VERSION linaro-arm-linux-gnueabihf`
USED_GCC47=`available CC_V config/cc/gcc.in 4.7`
USED_GCC48=`available CC_V config/cc/gcc.in 4.8`
USED_BINUTILS=`used CT_BINUTILS_VERSION linaro-arm-linux-gnueabihf`
USED_NEWLIB=`used CT_LIBC_VERSION linaro-arm-none-eabi`
USED_GDB=`used CT_GDB_VERSION linaro-arm-linux-gnueabihf`
USED_EGLIBC=`used CT_LIBC_VERSION linaro-armeb-linux-gnueabihf`

CURRENT_GCC=`current gcc`
CURRENT_GCC47=`current gcc 4.7`
CURRENT_GCC48=`current gcc 4.8`
CURRENT_BINUTILS=`current binutils`
CURRENT_NEWLIB=`current newlib`
CURRENT_GDB=`current gdb`
CURRENT_EGLIBC=`current eglibc`

for i in "$@"; do
	[ "$i" = "--without-gcc" ] && CURRENT_GCC=$USED_GCC
	[ "$i" = "--without-gcc47" ] && CURRENT_GCC47=$USED_GCC47
	[ "$i" = "--without-gcc48" ] && CURRENT_GCC48=$USED_GCC48
	[ "$i" = "--without-binutils" ] && CURRENT_BINUTILS=$USED_BINUTILS
	[ "$i" = "--without-newlib" ] && CURRENT_NEWLIB=$USED_NEWLIB
	[ "$i" = "--without-gdb" ] && CURRENT_GDB=$USED_GDB
	[ "$i" = "--without-eglibc" ] && CURRENT_EGLIBC=$USED_EGLIBC
done

echo "gcc: $USED_GCC -> $CURRENT_GCC"
echo "gcc 4.7: $USED_GCC47 -> $CURRENT_GCC47"
echo "gcc 4.8: $USED_GCC48 -> $CURRENT_GCC48"
echo "binutils: $USED_BINUTILS -> $CURRENT_BINUTILS"
echo "newlib: $USED_NEWLIB -> $CURRENT_NEWLIB"
echo "gdb: $USED_GDB -> $CURRENT_GDB"
echo "eglibc: $USED_EGLIBC -> $CURRENT_EGLIBC"

if [ "$USED_GCC" != "$CURRENT_GCC" ]; then
	echo "Updating gcc $USED_GCC -> $CURRENT_GCC"
	USED_DASHED=$(echo $USED_GCC |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	CURRENT_DASHED=$(echo $CURRENT_GCC |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	sed -i -e "s,CC_V_linaro_$USED_DASHED,CC_V_linaro_$CURRENT_DASHED,;s,linaro-$USED_GCC,linaro-$CURRENT_GCC,g" config/cc/gcc.in
	sed -i -e "s,^CT_CC_VERSION=\"linaro-$USED_GCC\",CT_CC_VERSION=\"linaro-$CURRENT_GCC\",;s,CT_CC_V_linaro_$USED_DASHED,CT_CC_V_linaro_$CURRENT_DASHED," samples/*/crosstool.config
	cd contrib/linaro/patches/gcc
	[ -d linaro-$USED_GCC ] && bzr mv linaro-$USED_GCC linaro-$CURRENT_GCC
	cd ../../../..
fi
if [ "$USED_GCC47" != "$CURRENT_GCC47" ]; then
	echo "Updating gcc $USED_GCC47 -> $CURRENT_GCC47"
	USED_DASHED=$(echo $USED_GCC47 |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	CURRENT_DASHED=$(echo $CURRENT_GCC47 |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	sed -i -e "s,CC_V_linaro_$USED_DASHED,CC_V_linaro_$CURRENT_DASHED,;s,linaro-$USED_GCC47,linaro-$CURRENT_GCC47,g" config/cc/gcc.in
	sed -i -e "s,^CT_CC_VERSION=\"linaro-$USED_GCC\",CT_CC_VERSION=\"linaro-$CURRENT_GCC\",;s,CT_CC_V_linaro_$USED_DASHED,CT_CC_V_linaro_$CURRENT_DASHED," samples/*/crosstool.config
	cd contrib/linaro/patches/gcc
	[ -d linaro-$USED_GCC47 ] && bzr mv linaro-$USED_GCC47 linaro-$CURRENT_GCC47
	cd ../../../..
fi
if [ "$USED_GCC48" != "$CURRENT_GCC48" ]; then
	echo "Updating gcc $USED_GCC48 -> $CURRENT_GCC48"
	USED_DASHED=$(echo $USED_GCC48 |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	CURRENT_DASHED=$(echo $CURRENT_GCC48 |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	sed -i -e "s,CC_V_linaro_$USED_DASHED,CC_V_linaro_$CURRENT_DASHED,;s,linaro-$USED_GCC48,linaro-$CURRENT_GCC48,g" config/cc/gcc.in
	sed -i -e "s,^CT_CC_VERSION=\"linaro-$USED_GCC\",CT_CC_VERSION=\"linaro-$CURRENT_GCC\",;s,CT_CC_V_linaro_$USED_DASHED,CT_CC_V_linaro_$CURRENT_DASHED," samples/*/crosstool.config
	cd contrib/linaro/patches/gcc
	[ -d linaro-$USED_GCC48 ] && bzr mv linaro-$USED_GCC48 linaro-$CURRENT_GCC48
	cd ../../../..
fi
if [ "$USED_BINUTILS" != "$CURRENT_BINUTILS" ]; then
	echo "Updating binutils $USED_BINUTILS -> $CURRENT_BINUTILS"
	USED_DASHED=$(echo $USED_BINUTILS |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	CURRENT_DASHED=$(echo $CURRENT_BINUTILS |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	sed -i -e "s,BINUTILS_LINARO_V_$USED_DASHED,BINUTILS_LINARO_V_$CURRENT_DASHED,;s,linaro-$USED_BINUTILS,linaro-$CURRENT_BINUTILS,g" config/binutils/binutils.in
	sed -i -e "s,CT_BINUTILS_LINARO_V_$USED_DASHED,CT_BINUTILS_LINARO_V_$CURRENT_DASHED,g;s,linaro-$USED_BINUTILS,linaro-$CURRENT_BINUTILS,g" samples/*/crosstool.config
	cd contrib/linaro/patches/gcc
	[ -d linaro-$USED_BINUTILS ] && bzr mv linaro-$USED_BINUTILS linaro-$CURRENT_BINUTILS
	cd -
fi
if [ "$USED_EGLIBC" != "$CURRENT_EGLIBC" ]; then
	echo "Updating eglibc $USED_EGLIBC -> $CURRENT_EGLIBC"
	USED_DASHED=$(echo $USED_EGLIBC |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	CURRENT_DASHED=$(echo $CURRENT_EGLIBC |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	sed -i -e "s,LIBC_EGLIBC_LINARO_V_$USED_DASHED,LIBC_EGLIBC_LINARO_V_$CURRENT_DASHED,;s,linaro-$USED_EGLIBC,linaro-$CURRENT_EGLIBC,g;s,Linaro $(echo $USED_EGLIBC |cut -d- -f1-2)\",Linaro $(echo $CURRENT_EGLIBC |cut -d- -f1-2)\",g" config/libc/eglibc.in
	for i in samples/*/crosstool.config; do
		if grep -q CT_LIBC=\"eglibc\" $i; then
			sed -i -e "s,CT_LIBC_VERSION=\"linaro-$USED_EGLIBC\",CT_LIBC_VERSION=\"linaro-$CURRENT_EGLIBC\",g" $i
		fi
	done
	sed -i -e "s,CT_LIBC_EGLIBC_LINARO_V_$USED_DASHED,CT_LIBC_EGLIBC_LINARO_V_$CURRENT_DASHED,g" samples/*/crosstool.config
	cd contrib/linaro/patches/eglibc
	[ -d linaro-$USED_EGLIBC ] && bzr mv linaro-$USED_EGLIBC linaro-$CURRENT_EGLIBC
	cd -
fi
if [ "$USED_GDB" != "$CURRENT_GDB" ]; then
	echo "Updating gdb $USED_GDB -> $CURRENT_GDB"
	USED_DASHED=$(echo $USED_GDB |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	CURRENT_DASHED=$(echo $CURRENT_GDB |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	sed -i -e "s,GDB_V_linaro_$USED_DASHED,GDB_V_linaro_$CURRENT_DASHED,;s,linaro-$USED_GDB,linaro-$CURRENT_GDB,g" config/debug/gdb.in
	sed -i -e "s,CT_GDB_V_linaro_$USED_DASHED,CT_GDB_V_linaro_$CURRENT_DASHED,g;s,linaro-$USED_GDB,linaro-$CURRENT_GDB,g" samples/*/crosstool.config
	cd contrib/linaro/patches/gdb
	[ -d linaro-$USED_GDB ] && bzr mv linaro-$USED_GDB linaro-$CURRENT_GDB
	cd -
fi
if [ "$USED_NEWLIB" != "$CURRENT_NEWLIB" ]; then
	echo "Updating newlib $USED_NEWLIB -> $CURRENT_NEWLIB"
	USED_DASHED=$(echo $USED_NEWLIB |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	CURRENT_DASHED=$(echo $CURRENT_NEWLIB |cut -d- -f1-2 |sed -e 's,\.,_,g;s,-,_,g')
	sed -i -e "s,LIBC_NEWLIB_LINARO_$USED_DASHED,LIBC_NEWLIB_LINARO_$CURRENT_DASHED,;s,Linaro $USED_NEWLIB,Linaro $CURRENT_NEWLIB,g;s,linaro-$USED_NEWLIB,linaro-$CURRENT_NEWLIB,g" config/libc/newlib.in
	for i in samples/*/crosstool.config; do
		if grep -q CT_LIBC=\"newlib\" $i; then
			sed -i -e "s,CT_LIBC_VERSION=\"linaro-$USED_NEWLIB\",CT_LIBC_VERSION=\"linaro-$CURRENT_NEWLIB\",g" $i
		fi
	done
	sed -i -e "s,CT_LIBC_NEWLIB_LINARO_$USED_DASHED,CT_LIBC_NEWLIB_LINARO_$CURRENT_DASHED,g" samples/*/crosstool.config
	if [ -d contrib/linaro/patches/newlib ]; then
		cd contrib/linaro/patches/newlib
		[ -d linaro-$USED_NEWLIB ] && bzr mv linaro-$USED_NEWLIB linaro-$CURRENT_NEWLIB
		cd -
	fi
fi
find . -name "*.config" |xargs sed -i -e "s,^CT_TOOLCHAIN_PKGVERSION=\"Linaro.*,CT_TOOLCHAIN_PKGVERSION=\"Linaro GCC $CURRENT_GCC\",g"
