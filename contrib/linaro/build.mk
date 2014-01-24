# Top level Makefile that builds the Linaro cross compilers
#
# Copyright 2011  Linaro Limited
#

TOP := $(shell pwd)

# Top level product
PRODUCT ?= gcc-linaro
# Targets to build.  See samples/linaro-%.  As at 2012-09 these
# include arm-linux-gnueabihf, arm-none-eabi, and
# arm-linux-gnueabihf-raspbian.
TARGETS = arm-linux-gnueabihf
# The variants to build including Linux hosted, Windows hosted, and
# just the device runtime
HOSTS = linux runtime win32
# Major version of the toolchain.  Pulled automatically from the
# .config file.  Strip the leading vendor, if any
FULL_VERSION = $(shell awk '-F"' '/^CT_CC_VERSION/ { print $$2 }' \
                      samples/linaro-$(TARGET)/crosstool.config)
VERSION = $(subst linaro-,,$(FULL_VERSION))
GCC_VERSION = $(shell echo $(VERSION) | sed -e 's/-/ /')

TOOLCHAIN_TMP = $(shell echo $(VERSION) | sed -e 's/^[^-]*-//g')
TOOLCHAIN_VERSION = $(shell echo $(TOOLCHAIN_TMP) | sed -e 's/-.*//g')

GDB_FULL = $(shell awk '-F"' '/^CT_GDB_VERSION/ { print $$2 }'    \
                   samples/linaro-$(TARGET)/crosstool.config)
GDB_TMP = $(subst linaro-,,$(GDB_FULL))
GDB_VERSION = $(shell echo $(GDB_TMP) | sed -e 's/-/ /')

LIBC_FULL = $(shell awk '-F"' '/^CT_LIBC_VERSION/ { print $$2 }'    \
                   samples/linaro-$(TARGET)/crosstool.config)
LIBC_TMP = $(subst linaro-,,$(LIBC_FULL))
LIBC_VERSION = $(shell echo $(LIBC_TMP) | sed -e 's/-/ /')

# Binary build identifier.  Default is empty. Use -01, -02, ... for respin.
SPIN ?=
# Development build identifier.  Normally +bzr1234
REVISION =

# Full name of this release.  Used in the tarball name
FULL = $(PRODUCT)-$(TARGET)-$(VERSION)$(SPIN)$(REVISION)
# Full name of the source tarball
SRC = $(FULL)_src

# Tarball/directory name
DIRNAME = $(FULL)_$(HOST)

# The architecture of the build machine.  Used for picking the runtime and others.
BUILD_ARCH = linux

-include local.mk

# Target this build compiles for
TARGET ?= $(firstword $(TARGETS))
# Host OS the toolchain will run on
HOST ?= $(firstword $(TARGETS))
# Pull the triplet out of the target
TRIPLET = $(subst -raspbian,,$(TARGET))

# Use bash as we use bashisms like brace expansion for clarity
SHELL = /bin/bash

BUILD = builds
HBUILD = $(BUILD)/$(TARGET)-$(HOST)
# Directory to put all stamp files
stamp = $(BUILD)/stamp/
# Sub build specific stamps
dstamp = $(stamp)$(TARGET)-$(HOST)-
INSTALL = $(HBUILD)/install
# Directory the build is composed into before taring
FINAL = $(HBUILD)/$(DIRNAME)
SYSROOT = $(FINAL)/$(TRIPLET)/libc
# List of files that overlap on case-insensitive filesystems
LINUX_INC = $(SYSROOT)/usr/include/linux
NETFILTER_RENAMES = \
	netfilter_ipv4/ipt_ECN \
	netfilter_ipv4/ipt_TTL \
	netfilter_ipv6/ip6t_HL \
	netfilter/xt_CONNMARK \
	netfilter/xt_DSCP \
	netfilter/xt_MARK \
	netfilter/xt_RATEEST \
	netfilter/xt_TCPMSS

# Subdirectory under share/doc to put the manuals
DOC_DIR = $(FINAL)/share/doc/$(PRODUCT)-$(TARGET)

# All of the target/host combinations.  Do all for the Linux host
# first to catch any config errors early.
ALL_TARGETS ?= $(foreach t,$(HOSTS),$(TARGETS:%=$(stamp)%-$(t)))

all: $(stamp)init-dirs targets $(stamp)src

check: $(TARGETS:%=$(stamp)%-check)

# The foreach expands to all combinations of TARGETS and HOSTS
targets: $(ALL_TARGETS)

$(stamp)init-dirs:
	install -d $(stamp) tarballs
	touch $@

# Build the local LSB environment
$(BUILD)/lsb/env.sh:
	$(TOP)/contrib/linaro/lsb/make-lsb.sh $(@D)

# Build README 
$(BUILD)/README.txt:
	echo "@set TOOLCHAIN_VERSION $(TOOLCHAIN_VERSION)" > version.texi
	echo "@set GCC_VERSION $(GCC_VERSION)" >> version.texi
	echo "@set GDB_VERSION $(GDB_VERSION)" >> version.texi
	echo "@set LIBC_VERSION $(LIBC_VERSION)" >> version.texi
	- makeinfo --plain -I$(TOP)/samples/linaro-$(TARGET)/   \
		   $(TOP)/contrib/linaro/doc/README.texi        \
		   > $(TOP)/contrib/linaro/doc/README.txt

# Build the Linux version using the LSB compilers
$(stamp)%-$(BUILD_ARCH): $(BUILD)/lsb/env.sh $(BUILD)/README.txt
	. $< && \
	PATH=$(TOP):$$PATH \
	$(MAKE) -f contrib/linaro/build.mk HOST=$(BUILD_ARCH) TARGET=$* go
	touch $@

# Build the win32 version using the just-built Linux compiler
$(stamp)%-win32: $(stamp)%-$(BUILD_ARCH)
	PATH=$(TOP):$(TOP)/$(BUILD)/$*-$(BUILD_ARCH)/install/bin:$$PATH \
	$(MAKE) -f contrib/linaro/build.mk HOST=win32 TARGET=$* EXE=.exe go
	touch $@

# Override for bare metal that has no runtime
$(stamp)%-none-eabi-runtime $(stamp)%-none-elf-runtime:
	touch $@

# Pull the runtime from the just-built Linux compiler
$(stamp)%-runtime: $(stamp)%-$(BUILD_ARCH)
	$(MAKE) -f contrib/linaro/build.mk HOST=runtime TARGET=$* go-runtime
	touch $@

# Override for bare metal that has no tests
$(stamp)%-none-eabi-check $(stamp)%-none-elf-check:
	touch $@

# Build the tests with the just-built Linux compiler
$(stamp)%-check: $(stamp)%-$(BUILD_ARCH)
	$(MAKE) -f contrib/linaro/build.mk HOST=check TARGET=$* go-check
	touch $@

# Fetch and build a range of packages from source
go-check: $(BUILD)/check/tarballs/tests-tarballs+bzr2505.tar.bz2
	rm -rf $(HBUILD)
	cp -a contrib/linaro/tests $(HBUILD)
	# Build the basic tests
	PATH=$(wildcard $(TOP)/$(BUILD)/$(TARGET)-$(BUILD_ARCH)/$(PRODUCT)-*/bin):$(PATH) \
	$(MAKE) -C $(HBUILD)/misc clean all CROSS_COMPILE=$(TRIPLET)-
	# Build a range of programs
	rm -rf $(HBUILD)/tarballs
	tar xaf $< -C $(HBUILD)
	PATH=$(wildcard $(TOP)/$(BUILD)/$(TARGET)-$(BUILD_ARCH)/$(PRODUCT)-*/bin):$(PATH) \
	$(MAKE) -C $(HBUILD) clean all TARGET=$(TRIPLET) TOPDIR=$(TOP) -k

# Fetch a tarball of test tarballs
$(BUILD)/check/tarballs/%:
	mkdir -p $(@D)
	cd $(BUILD)/check/tarballs && wget -nv -N http://launchpadlibrarian.net/118064865/$(@F)

# Build a tarball of the runtime to overlay on the device
go-runtime:
	rm -rf $(FINAL)
	case "$(TRIPLET)" in            \
	    aarch64*linux*)             \
	        $(MAKE) -f contrib/linaro/build.mk copy-runtime RUNTIME_SRC=lib64          \
	                  RUNTIME_TUPLE=$(shell $(BUILD)/$(TARGET)-$(BUILD_ARCH)/install/bin/$(TRIPLET)-gcc --print-multiarch);; \
	    arm*linux*)                 \
	        $(MAKE) -f contrib/linaro/build.mk copy-runtime RUNTIME_SRC=lib          \
	                  RUNTIME_TUPLE=$(shell $(BUILD)/$(TARGET)-$(BUILD_ARCH)/install/bin/$(TRIPLET)-gcc --print-multiarch);; \
	esac
	for i in $(wildcard $(BUILD)/$(TARGET)-$(BUILD_ARCH)/install/*-*/lib/arm-*); do \
		$(MAKE) -f contrib/linaro/build.mk copy-runtime RUNTIME_SRC=lib/`basename $$i` RUNTIME_TUPLE=`basename $$i`; \
	done
	cd $(HBUILD) && tar cf $(DIRNAME).tar $(DIRNAME)
	bzip2 -fk9 $(HBUILD)/$(DIRNAME).tar

copy-runtime:
	mkdir -p $(FINAL)/{lib,usr/lib}/$(RUNTIME_TUPLE)
	# Pull across all libraries
	cp -af $(BUILD)/$(TARGET)-$(BUILD_ARCH)/install/*-*/lib/*.so* $(FINAL)/usr/lib/$(RUNTIME_TUPLE)
	# Remove all sonames with no version
	rm -f $(FINAL)/usr/lib/$(RUNTIME_TUPLE)/*.so
	# Move libgcc
	mv $(FINAL)/usr/lib/$(RUNTIME_TUPLE)/libgcc*.so* $(FINAL)/lib/$(RUNTIME_TUPLE)

# Build a tarball of everything that went into the build
$(stamp)src: $(ALL_TARGETS)
	rm -rf $(BUILD)/src
	mkdir -p $(BUILD)/src/$(SRC)
	cp -afu tarballs/* $(BUILD)/src/$(SRC)
	cd $(BUILD)/src/$(SRC) && md5sum * > md5sum
	cd $(BUILD)/src && tar cjf $(SRC).tar.bz2 $(SRC)
	touch $@

# Stage 2: target and host specific
go: $(dstamp)archive

INSTALLER = $(TOP)/contrib/linaro/win32installer
$(BUILD)/win32installer/env.sh:
	$(INSTALLER)/setup.sh $(@D)

# Host specific ways of tarballing up.  Note that the .zip.xz version
# is 33 % of the size of the plain .zip
$(stamp)$(TARGET)-win32-archive: $(dstamp)fixup $(BUILD)/win32installer/env.sh
	rm -f $(HBUILD)/$(DIRNAME).zip*
	cd $(HBUILD) && zip -r0q $(DIRNAME).zip $(DIRNAME)
	xz -f9 $(HBUILD)/$(DIRNAME).zip
	cd $(HBUILD) && zip -r9q $(DIRNAME).zip $(DIRNAME)
	# Create a Windows installer
	cp $(INSTALLER)/gccvar.bat $(HBUILD)/$(DIRNAME)/bin
	-$(TOP)/$(BUILD)/win32installer/installjammer/installjammer         \
		-DBaseDir $(TOP)/$(HBUILD)/$(DIRNAME)                       \
		-DVersion $(VERSION) -DImage $(INSTALLER)/Linaro_Green.gif  \
		-DIcon $(INSTALLER)/Linaro_Sprinkles.gif -DTarget $(TARGET) \
		--output-dir $(TOP)/$(HBUILD)                               \
		--build $(INSTALLER)/$(TARGET).mpi

# Create a tarball and a xz compressed one for testing
$(stamp)$(TARGET)-$(BUILD_ARCH)-archive: $(dstamp)fixup
	cd $(HBUILD) && tar cf $(DIRNAME).tar $(DIRNAME)
	bzip2 -fk9 $(HBUILD)/$(DIRNAME).tar
	xz -fk9 $(HBUILD)/$(DIRNAME).tar

# Build
$(dstamp)build: $(HBUILD)/.config $(stamp)init-dirs
	cd $(HBUILD) && ln -fs ../../tarballs
	cd $(HBUILD) && DEB_TARGET_MULTIARCH=$(TRIPLET) ct-ng build
	touch $@

# Fix up the full tree
$(dstamp)fixup: $(dstamp)$(TARGET)-$(HOST)-fixup $(dstamp)$(HOST)-fixup $(dstamp)$(TARGET)-fixup
	touch $@

# Fallback rule for no fixups
$(dstamp)%-fixup: $(dstamp)common-fixup
	true

# Common fixups that run first
$(dstamp)common-fixup: $(dstamp)build
	# Copy the install/ tree to a directory with the full name
	rm -rf $(FINAL)
	cp -a $(INSTALL) $(FINAL)
	# Remove host libiberty.a
	rm $(FINAL)/lib/libiberty.a
	# Remove tmp files
	-rm $(FINAL)/$(TRIPLET)/libc/usr/lib/crt*.o
	-rm $(FINAL)/$(TRIPLET)/libc/usr/lib/libc.so
	# Remove the biarch symlinks
	find $(FINAL) -type l -name lib64 -exec rm {} \;
	find $(FINAL) -type l -name lib32 -exec rm {} \;
	# Remove the buildlog
	rm -f $(FINAL)/build.log.bz2
	# Remove the *-cc[.exe] symlink added by crosstool-NG
	rm -f $(FINAL)/bin/*-cc*
	# Convert the duplicates into symlinks
	rm -f $(FINAL)/bin/*-{ld,c++,gcc}{,.exe}
	cd $(FINAL)/bin \
	&& ln -sf $(TRIPLET)-ld.bfd$(EXE) $(TRIPLET)-ld$(EXE) \
	&& ln -sf $(TRIPLET)-g++$(EXE) $(TRIPLET)-c++$(EXE) \
	&& ln -sf $(TRIPLET)-gcc-4*$(EXE) $(TRIPLET)-gcc$(EXE)
	# Remove the populate script
	rm -f $(FINAL)/bin/*-populate
	# Remove the internal documentation
	rm -rf $(FINAL)/share/{doc,info,man}
	# .config shouldn't be executable
	chmod -x $(FINAL)/bin/*.config
	# Remove include/
	rm -rf $(FINAL)/include
	# Remove all libtool .la files (LP: #916671)
	find $(FINAL) -name "*.la" -exec rm {} \;
	# Copy the documentation across while splitting into html and
	# pdf directories
	mkdir -p $(DOC_DIR)/{html,pdf}
	cp -a $(INSTALL)/share/doc/*/*.pdf $(DOC_DIR)/pdf
	cp -a $(INSTALL)/share/*/*.pdf $(DOC_DIR)/pdf
	cp -a $(INSTALL)/share/doc/* $(DOC_DIR)/html
	rm -f $(DOC_DIR)/html/*.pdf
	cp -a $(INSTALL)/share/{man,info} $(DOC_DIR)
	rm -rf $(DOC_DIR)/*/{annotate,cppinternals,gccinstall,gccint,gdbint,stabs,libquadmath,standards}*
	# Fix any -real man pages
	for i in `ls $(DOC_DIR)/man/*/*-real*`; do \
		mv $$i `echo $$i | sed "s/-real//"`; done
	# Copy any Linaro specific documentation
	cp -af contrib/linaro/doc/*.txt $(DOC_DIR)

# Host or target specific fixups

$(dstamp)arm-linux-%-win32-fixup: $(dstamp)common-fixup
	# Rename the netfilter header files
	for i in $(NETFILTER_RENAMES); do \
		mv $(LINUX_INC)/$${i}.h $(LINUX_INC)/$${i}_.h; \
	done

SECTIONS = -R .comment -R .note -R .debug_info -R .debug_aranges    \
	-R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev      \
	-R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc \
	-R .debug_types -R .debug_macinfo

$(dstamp)win32-fixup: $(dstamp)common-fixup
	# Fix the line endings of any text files
	find $(FINAL) -name "*.txt" -print -exec flip -m {} \;
	# Strip .comment, .note and .debug related sections
	find $(FINAL)/ -name \*.a \
		-exec $(TRIPLET)-objcopy $(SECTIONS) {} \;
	find $(FINAL)/ -name \*.o \
		-exec $(TRIPLET)-objcopy $(SECTIONS) {} \;

$(dstamp)linux-fixup: $(dstamp)common-fixup
	# Strip .comment, .note and .debug related sections
	find $(FINAL)/ -name \*.a \
		-exec $(FINAL)/bin/*-objcopy $(SECTIONS) {} \;
	find $(FINAL)/ -name \*.o \
		-exec $(FINAL)/bin/*-objcopy $(SECTIONS) {} \;

# Override in local.mk to skip using the LSB compilers
USE_LSBCC ?= CT_BUILD_USE_LSBCC=y

# Settings to add just for Linux
LINUX_ADD = \
	$(USE_LSBCC)

# Settings to add just for win32
WIN32_ADD = \
	CT_CANADIAN=y \
	CT_HOST=\"i586-mingw32msvc\" \
	CT_BINUTILS_GOLD_THREADS=n

WIN32_REMOVE = \
	CT_CROSS \
	CT_BUILD_USE_LSBCC \
	CT_CROSS_EXTRAS_pkg_config \
	CT_BINUTILS_GOLD_THREADS \
	CT_CC_GCC_ENABLE_PLUGINS \
	CT_BINUTILS_PLUGINS

# Build the Linux specific configuration
$(BUILD)/$(TARGET)-$(BUILD_ARCH)/.config: ct-ng
	mkdir -p $(@D)
	cd $(@D) && echo | ct-ng linaro-$(TARGET)
	for i in $(LINUX_ADD); do \
		echo $$i >> $@; \
	done
	cd $(@D) && echo | ct-ng oldconfig

# Build the Windows specific configuration
$(BUILD)/$(TARGET)-win32/.config: ct-ng
	mkdir -p $(@D)
	cd $(@D) && echo | ct-ng linaro-$(TARGET)
	# The win32 changes are small.  Patch them here
	for i in $(WIN32_REMOVE); do \
		sed -i -r "s/^$$i.+//" $@; \
	done
	for i in $(WIN32_ADD); do \
		echo $$i >> $@; \
	done
	cd $(@D) && echo | ct-ng oldconfig

# Build ct-ng locally
ct-ng:
	./configure --local
	$(MAKE) -S MAKELEVEL=0

# Tidy up
clean:
	-$(MAKE) clean -S MAKELEVEL=0
	rm -rf $(BUILD) $(stamp)

# Grab the crosstool-NG version minus the +bzr
UPSTREAM_VERSION = $(firstword $(subst +, ,$(shell ./version.sh)))
RELEASE_VERSION = $(UPSTREAM_VERSION)-$(VERSION)$(SPIN)
RELEASE_NAME = crosstool-ng-$(RELEASE_VERSION)
RELEASE_DIR = builds/release/$(RELEASE_NAME)

# Make the release tarball
release:
	rm -rf builds/release
	install -d builds/release
	bzr export $(RELEASE_DIR)
	# Patch the version number
	rm -f $(RELEASE_DIR)/version.sh
	echo $(RELEASE_VERSION) > $(RELEASE_DIR)/.version
	# Tar it up
	cd builds/release && tar cjf $(RELEASE_NAME).tar.bz2 $(RELEASE_NAME)
