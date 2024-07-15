#--------------------------------------------------------------
# Just run 'make menuconfig', configure stuff, then run 'make'.
# You shouldn't need to mess with anything beyond this point...
#--------------------------------------------------------------

# Delete default rules. We don't use them. This saves a bit of time.
.SUFFIXES:

# we want bash as shell
SHELL := $(shell if [ -x "$$BASH" ]; then echo $$BASH; \
	 else if [ -x /bin/bash ]; then echo /bin/bash; \
	 else echo sh; fi; fi)

# Set O variable if not already done on the command line;
# or avoid confusing packages that can use the O=<dir> syntax for out-of-tree
# build by preventing it from being forwarded to sub-make calls.
ifneq ("$(origin O)", "command line")
O := $(CURDIR)/output
endif

# Check if the current Buildroot execution meets all the pre-requisites.
# If they are not met, Buildroot will actually do its job in a sub-make meeting
# its pre-requisites, which are:
#  1- Permissive enough umask:
#       Wrong or too restrictive umask will prevent Buildroot and packages from
#       creating files and directories.
#  2- Absolute canonical CWD (i.e. $(CURDIR)):
#       Otherwise, some packages will use CWD as-is, others will compute its
#       absolute canonical path. This makes harder tracking and fixing host
#       machine path leaks.
#  3- Absolute canonical output location (i.e. $(O)):
#       For the same reason as the one for CWD.

# Remove the trailing '/.' from $(O) as it can be added by the makefile wrapper
# installed in the $(O) directory.
# Also remove the trailing '/' the user can set when on the command line.
override O := $(patsubst %/,%,$(patsubst %.,%,$(O)))
# Make sure $(O) actually exists before calling realpath on it; this is to
# avoid empty CANONICAL_O in case on non-existing entry.
CANONICAL_O := $(shell mkdir -p $(O) >/dev/null 2>&1)$(realpath $(O))

# gcc fails to build when the srcdir contains a '@'
ifneq ($(findstring @,$(CANONICAL_O)),)
$(error The build directory can not contain a '@')
endif

CANONICAL_CURDIR = $(realpath $(CURDIR))

REQ_UMASK = 0022

# Make sure O= is passed (with its absolute canonical path) everywhere the
# toplevel makefile is called back.
EXTRAMAKEARGS := O=$(CANONICAL_O)

# Check Buildroot execution pre-requisites here.
ifneq ($(shell umask):$(CURDIR):$(O),$(REQ_UMASK):$(CANONICAL_CURDIR):$(CANONICAL_O))
.PHONY: _all $(MAKECMDGOALS)

$(MAKECMDGOALS): _all
	@:

_all:
	@umask $(REQ_UMASK) && \
		$(MAKE) -C $(CANONICAL_CURDIR) --no-print-directory \
			$(MAKECMDGOALS) $(EXTRAMAKEARGS)

else # umask / $(CURDIR) / $(O)

# This is our default rule, so must come first
all:
.PHONY: all

# absolute path
TOPDIR := $(CURDIR)
CONFIG_CONFIG_IN = Config.in
CONFIG = support/kconfig
DATE := $(shell date +%Y%m%d)

# Compute the full local version string so packages can use it as-is
# Need to export it, so it can be got from environment in children (eg. mconf)

BR2_LOCALVERSION := $(shell $(TOPDIR)/support/scripts/setlocalversion)
ifeq ($(BR2_LOCALVERSION),)
export BR2_VERSION_FULL := $(BR2_VERSION)
else
export BR2_VERSION_FULL := $(BR2_LOCALVERSION)
endif

# List of targets and target patterns for which .config doesn't need to be read in
noconfig_targets := menuconfig nconfig gconfig xconfig config oldconfig randconfig \
	defconfig %_defconfig allyesconfig allnoconfig alldefconfig syncconfig release \
	randpackageconfig allyespackageconfig allnopackageconfig \
	print-version olddefconfig distclean manual manual-% check-package

# Some global targets do not trigger a build, but are used to collect
# metadata, or do various checks. When such targets are triggered,
# some packages should not do their configuration sanity
# checks. Provide them a BR_BUILDING variable set to 'y' when we're
# actually building and they should do their sanity checks.
#
# We're building in two situations: when MAKECMDGOALS is empty
# (default target is to build), or when MAKECMDGOALS contains
# something else than one of the nobuild_targets.
nobuild_targets := source %-source \
	legal-info %-legal-info external-deps _external-deps \
	clean distclean help show-targets graph-depends \
	%-graph-depends %-show-depends %-show-version \
	graph-build graph-size list-defconfigs \
	savedefconfig update-defconfig printvars show-vars
ifeq ($(MAKECMDGOALS),)
BR_BUILDING = y
else ifneq ($(filter-out $(nobuild_targets),$(MAKECMDGOALS)),)
BR_BUILDING = y
endif

# We call make recursively to build packages. The command-line overrides that
# are passed to Buildroot don't apply to those package build systems. In
# particular, we don't want to pass down the O=<dir> option for out-of-tree
# builds, because the value specified on the command line will not be correct
# for packages.
MAKEOVERRIDES :=

# Include some helper macros and variables
include support/misc/utils.mk

# Set variables related to in-tree or out-of-tree build.
# Here, both $(O) and $(CURDIR) are absolute canonical paths.
ifeq ($(O),$(CURDIR)/output)
CONFIG_DIR := $(CURDIR)
NEED_WRAPPER =
else
CONFIG_DIR := $(O)
NEED_WRAPPER = y
endif

# bash prints the name of the directory on 'cd <dir>' if CDPATH is
# set, so unset it here to not cause problems. Notice that the export
# line doesn't affect the environment of $(shell ..) calls.
export CDPATH :=

BASE_DIR := $(CANONICAL_O)
$(if $(BASE_DIR),, $(error output directory "$(O)" does not exist))

# Handling of BR2_EXTERNAL.
#
# The value of BR2_EXTERNAL is stored in .br-external in the output directory.
# The location of the external.mk makefile fragments is computed in that file.
# On subsequent invocations of make, this file is read in. BR2_EXTERNAL can
# still be overridden on the command line, therefore the file is re-created
# every time make is run.

BR2_EXTERNAL_FILE = $(BASE_DIR)/.br2-external.mk
-include $(BR2_EXTERNAL_FILE)
$(shell support/scripts/br2-external -d '$(BASE_DIR)' $(BR2_EXTERNAL))
BR2_EXTERNAL_ERROR =
include $(BR2_EXTERNAL_FILE)
ifneq ($(BR2_EXTERNAL_ERROR),)
$(error $(BR2_EXTERNAL_ERROR))
endif

# Workaround bug in make-4.3: https://savannah.gnu.org/bugs/?57676
$(BASE_DIR)/.br2-external.mk:;

# To make sure that the environment variable overrides the .config option,
# set this before including .config.
ifneq ($(BR2_DL_DIR),)
DL_DIR := $(BR2_DL_DIR)
endif
ifneq ($(BR2_CCACHE_DIR),)
BR_CACHE_DIR := $(BR2_CCACHE_DIR)
endif

# Need that early, before we scan packages
# Avoids doing the $(or...) everytime
BR_GRAPH_OUT := $(or $(BR2_GRAPH_OUT),pdf)

BUILD_DIR := $(BASE_DIR)/build
BINARIES_DIR := $(BASE_DIR)/images
BASE_TARGET_DIR := $(BASE_DIR)/target
PER_PACKAGE_DIR := $(BASE_DIR)/per-package
# initial definition so that 'make clean' works for most users, even without
# .config. HOST_DIR will be overwritten later when .config is included.
HOST_DIR := $(BASE_DIR)/host
GRAPHS_DIR := $(BASE_DIR)/graphs

LEGAL_INFO_DIR = $(BASE_DIR)/legal-info
REDIST_SOURCES_DIR_TARGET = $(LEGAL_INFO_DIR)/sources
REDIST_SOURCES_DIR_HOST = $(LEGAL_INFO_DIR)/host-sources
LICENSE_FILES_DIR_TARGET = $(LEGAL_INFO_DIR)/licenses
LICENSE_FILES_DIR_HOST = $(LEGAL_INFO_DIR)/host-licenses
LEGAL_MANIFEST_CSV_TARGET = $(LEGAL_INFO_DIR)/manifest.csv
LEGAL_MANIFEST_CSV_HOST = $(LEGAL_INFO_DIR)/host-manifest.csv
LEGAL_WARNINGS = $(LEGAL_INFO_DIR)/.warnings
LEGAL_REPORT = $(LEGAL_INFO_DIR)/README

BR2_CONFIG = $(CONFIG_DIR)/.config

# Pull in the user's configuration file
ifeq ($(filter $(noconfig_targets),$(MAKECMDGOALS)),)
-include $(BR2_CONFIG)
endif

ifeq ($(BR2_PER_PACKAGE_DIRECTORIES),)
# Disable top-level parallel build if per-package directories is not
# used. Indeed, per-package directories is necessary to guarantee
# determinism and reproducibility with top-level parallel build.
.NOTPARALLEL:
endif

# timezone and locale may affect build output
ifeq ($(BR2_REPRODUCIBLE),y)
export TZ = UTC
export LANG = C
export LC_ALL = C
endif

# To put more focus on warnings, be less verbose as default
# Use 'make V=1' to see the full commands
ifeq ("$(origin V)", "command line")
  KBUILD_VERBOSE = $(V)
endif
ifndef KBUILD_VERBOSE
  KBUILD_VERBOSE = 0
endif

ifeq ($(KBUILD_VERBOSE),1)
  Q =
ifndef VERBOSE
  VERBOSE = 1
endif
export VERBOSE
else
  Q = @
endif

# kconfig uses CONFIG_SHELL
CONFIG_SHELL := $(SHELL)

export SHELL CONFIG_SHELL Q KBUILD_VERBOSE

ifndef HOSTAR
HOSTAR := ar
endif
ifndef HOSTAS
HOSTAS := as
endif
ifndef HOSTCC
HOSTCC := gcc
HOSTCC := $(shell which $(HOSTCC) || type -p $(HOSTCC) || echo gcc)
endif
ifndef HOSTCC_NOCCACHE
HOSTCC_NOCCACHE := $(HOSTCC)
endif
ifndef HOSTCXX
HOSTCXX := g++
HOSTCXX := $(shell which $(HOSTCXX) || type -p $(HOSTCXX) || echo g++)
endif
ifndef HOSTCXX_NOCCACHE
HOSTCXX_NOCCACHE := $(HOSTCXX)
endif
ifndef HOSTCPP
HOSTCPP := cpp
endif
ifndef HOSTLD
HOSTLD := ld
endif
ifndef HOSTLN
HOSTLN := ln
endif
ifndef HOSTNM
HOSTNM := nm
endif
ifndef HOSTOBJCOPY
HOSTOBJCOPY := objcopy
endif
ifndef HOSTRANLIB
HOSTRANLIB := ranlib
endif
HOSTAR := $(shell which $(HOSTAR) || type -p $(HOSTAR) || echo ar)
HOSTAS := $(shell which $(HOSTAS) || type -p $(HOSTAS) || echo as)
HOSTCPP := $(shell which $(HOSTCPP) || type -p $(HOSTCPP) || echo cpp)
HOSTLD := $(shell which $(HOSTLD) || type -p $(HOSTLD) || echo ld)
HOSTLN := $(shell which $(HOSTLN) || type -p $(HOSTLN) || echo ln)
HOSTNM := $(shell which $(HOSTNM) || type -p $(HOSTNM) || echo nm)
HOSTOBJCOPY := $(shell which $(HOSTOBJCOPY) || type -p $(HOSTOBJCOPY) || echo objcopy)
HOSTRANLIB := $(shell which $(HOSTRANLIB) || type -p $(HOSTRANLIB) || echo ranlib)
SED := $(shell which sed || type -p sed) -i -e

export HOSTAR HOSTAS HOSTCC HOSTCXX HOSTLD
export HOSTCC_NOCCACHE HOSTCXX_NOCCACHE

# Determine the userland we are running on.
#
# Note that, despite its name, we are not interested in the actual
# architecture name. This is mostly used to determine whether some
# of the binary tools (e.g. pre-built external toolchains) can run
# on the current host. So we need to know if the userland we're
# running on can actually run those toolchains.
#
# For example, a 64-bit prebuilt toolchain will not run on a 64-bit
# kernel if the userland is 32-bit (e.g. in a chroot for example).
#
# So, we extract the first part of the tuple the host gcc was
# configured to generate code for; we assume this is our userland.
#
export HOSTARCH := $(shell LC_ALL=C $(HOSTCC_NOCCACHE) -v 2>&1 | \
	sed -e '/^Target: \([^-]*\).*/!d' \
	    -e 's//\1/' \
	    -e 's/i.86/x86/' \
	    -e 's/arm.*/arm/' \
	    -e 's/sh.*/sh/' )

# When adding a new host gcc version in Config.in,
# update the HOSTCC_MAX_VERSION variable:
HOSTCC_MAX_VERSION := 11

HOSTCC_VERSION := $(shell V=$$($(HOSTCC_NOCCACHE) --version | \
	sed -n -r 's/^.* ([0-9]*)\.([0-9]*)\.([0-9]*)[ ]*.*/\1 \2/p'); \
	[ "$${V%% *}" -le $(HOSTCC_MAX_VERSION) ] || V=$(HOSTCC_MAX_VERSION); \
	printf "%s" "$${V}")

# For gcc >= 5.x, we only need the major version.
ifneq ($(firstword $(HOSTCC_VERSION)),4)
HOSTCC_VERSION := $(firstword $(HOSTCC_VERSION))
endif

ifeq ($(BR2_NEEDS_HOST_UTF8_LOCALE),y)
# First, we try to use the user's configured locale (as that's the
# language they'd expect messages to be displayed), then we favour
# a non language-specific locale like C.UTF-8 if one is available,
# so we sort with the C locale to get it at the top.
# This is guaranteed to not be empty, because of the check in
# support/dependencies/dependencies.sh
HOST_UTF8_LOCALE := $(shell \
			( echo $${LC_ALL:-$${LC_MESSAGES:-$${LANG}}}; \
			  locale -a 2>/dev/null | LC_ALL=C sort \
			) \
			| grep -i -E 'utf-?8$$' \
			| head -n 1)
HOST_UTF8_LOCALE_ENV := LC_ALL=$(HOST_UTF8_LOCALE)
endif

# Make sure pkg-config doesn't look outside the buildroot tree
HOST_PKG_CONFIG_PATH := $(PKG_CONFIG_PATH)
unexport PKG_CONFIG_PATH
unexport PKG_CONFIG_SYSROOT_DIR
unexport PKG_CONFIG_LIBDIR

# Having DESTDIR set in the environment confuses the installation
# steps of some packages.
unexport DESTDIR

# Causes breakage with packages that needs host-ruby
unexport RUBYOPT

# Compilation of perl-related packages will fail otherwise
unexport PERL_MM_OPT

include package/pkg-utils.mk

# configuration
# ---------------------------------------------------------------------------

HOSTCFLAGS = $(CFLAGS_FOR_BUILD)
export HOSTCFLAGS

$(BUILD_DIR)/buildroot-config/%onf:
	mkdir -p $(@D)/lxdialog
	PKG_CONFIG_PATH="$(HOST_PKG_CONFIG_PATH)" $(MAKE) CC="$(HOSTCC_NOCCACHE)" HOSTCC="$(HOSTCC_NOCCACHE)" \
	    obj=$(@D) -C $(CONFIG) -f Makefile.br $(@F)

DEFCONFIG = $(call qstrip,$(BR2_DEFCONFIG))

# We don't want to fully expand BR2_DEFCONFIG here, so Kconfig will
# recognize that if it's still at its default $(CONFIG_DIR)/defconfig
COMMON_CONFIG_ENV = \
	BR2_DEFCONFIG='$(call qstrip,$(value BR2_DEFCONFIG))' \
	KCONFIG_AUTOCONFIG=$(BUILD_DIR)/buildroot-config/auto.conf \
	KCONFIG_AUTOHEADER=$(BUILD_DIR)/buildroot-config/autoconf.h \
	KCONFIG_TRISTATE=$(BUILD_DIR)/buildroot-config/tristate.config \
	BR2_CONFIG=$(BR2_CONFIG) \
	HOST_GCC_VERSION="$(HOSTCC_VERSION)" \
	BASE_DIR=$(BASE_DIR) \
	SKIP_LEGACY=

xconfig: $(BUILD_DIR)/buildroot-config/qconf outputmakefile
	@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN)

gconfig: $(BUILD_DIR)/buildroot-config/gconf outputmakefile
	@$(COMMON_CONFIG_ENV) srctree=$(TOPDIR) $< $(CONFIG_CONFIG_IN)

menuconfig: $(BUILD_DIR)/buildroot-config/mconf outputmakefile
	@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN)

nconfig: $(BUILD_DIR)/buildroot-config/nconf outputmakefile
	@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN)

config: $(BUILD_DIR)/buildroot-config/conf outputmakefile
	@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN)

# For the config targets that automatically select options, we pass
# SKIP_LEGACY=y to disable the legacy options. However, in that case
# no values are set for the legacy options so a subsequent oldconfig
# will query them. Therefore, run an additional olddefconfig.

randconfig allyesconfig alldefconfig allnoconfig: $(BUILD_DIR)/buildroot-config/conf outputmakefile
	@$(COMMON_CONFIG_ENV) SKIP_LEGACY=y $< --$@ $(CONFIG_CONFIG_IN)
	@$(COMMON_CONFIG_ENV) $< --olddefconfig $(CONFIG_CONFIG_IN) >/dev/null

randpackageconfig allyespackageconfig allnopackageconfig: $(BUILD_DIR)/buildroot-config/conf outputmakefile
	@grep -v BR2_PACKAGE_ $(BR2_CONFIG) > $(CONFIG_DIR)/.config.nopkg
	@$(COMMON_CONFIG_ENV) SKIP_LEGACY=y \
		KCONFIG_ALLCONFIG=$(CONFIG_DIR)/.config.nopkg \
		$< --$(subst package,,$@) $(CONFIG_CONFIG_IN)
	@rm -f $(CONFIG_DIR)/.config.nopkg
	@$(COMMON_CONFIG_ENV) $< --olddefconfig $(CONFIG_CONFIG_IN) >/dev/null

oldconfig syncconfig olddefconfig: $(BUILD_DIR)/buildroot-config/conf outputmakefile
	@$(COMMON_CONFIG_ENV) $< --$@ $(CONFIG_CONFIG_IN)

defconfig: $(BUILD_DIR)/buildroot-config/conf outputmakefile
	@$(COMMON_CONFIG_ENV) $< --defconfig$(if $(DEFCONFIG),=$(DEFCONFIG)) $(CONFIG_CONFIG_IN)

%_defconfig: $(BUILD_DIR)/buildroot-config/conf  outputmakefile
	@defconfig=$(or \
		$(firstword \
			$(foreach d, \
				$(call reverse,$(TOPDIR) $(BR2_EXTERNAL_DIRS)), \
				$(wildcard $(d)/configs/$@) \
			) \
		), \
		$(error "Can't find $@") \
	); \
	$(COMMON_CONFIG_ENV) BR2_DEFCONFIG=$${defconfig} \
		$< --defconfig=$${defconfig} $(CONFIG_CONFIG_IN)

update-defconfig: savedefconfig

savedefconfig: $(BUILD_DIR)/buildroot-config/conf outputmakefile
	@$(COMMON_CONFIG_ENV) $< \
		--savedefconfig=$(if $(DEFCONFIG),$(DEFCONFIG),$(CONFIG_DIR)/defconfig) \
		$(CONFIG_CONFIG_IN)
	@$(SED) '/^BR2_DEFCONFIG=/d' $(if $(DEFCONFIG),$(DEFCONFIG),$(CONFIG_DIR)/defconfig)

.PHONY: defconfig savedefconfig update-defconfig

# Build
# ---------------------------------------------------------------------------

ifeq ($(BR2_HAVE_DOT_CONFIG),y)

################################################################################
#
# Hide troublesome environment variables from sub processes
#
################################################################################
unexport CROSS_COMPILE
unexport ARCH
unexport CC
unexport LD
unexport AR
unexport CXX
unexport CPP
unexport RANLIB
unexport CFLAGS
unexport CXXFLAGS
unexport GREP_OPTIONS
unexport TAR_OPTIONS
unexport CONFIG_SITE
unexport QMAKESPEC
unexport TERMINFO
unexport MACHINE
unexport O
unexport GCC_COLORS
unexport PLATFORM
unexport OS
unexport DEVICE_TREE

# GNU_HOST_NAME := $(shell support/gnuconfig/config.guess)

PACKAGES :=
PACKAGES_ALL :=

# silent mode requested?
QUIET := $(if $(findstring s,$(filter-out --%,$(MAKEFLAGS))),-q)

# Strip off the annoying quoting
ARCH := $(call qstrip,$(BR2_ARCH))
NORMALIZED_ARCH := $(call qstrip,$(BR2_NORMALIZED_ARCH))
KERNEL_ARCH := $(call qstrip,$(BR2_NORMALIZED_ARCH))

ZCAT := $(call qstrip,$(BR2_ZCAT))
BZCAT := $(call qstrip,$(BR2_BZCAT))
XZCAT := $(call qstrip,$(BR2_XZCAT))
LZCAT := $(call qstrip,$(BR2_LZCAT))
TAR_OPTIONS = $(call qstrip,$(BR2_TAR_OPTIONS)) -xf

ifeq ($(BR2_PER_PACKAGE_DIRECTORIES),y)
HOST_DIR = $(if $(PKG),$(PER_PACKAGE_DIR)/$($(PKG)_NAME)/host,$(call qstrip,$(BR2_HOST_DIR)))
TARGET_DIR = $(if $(ROOTFS),$(ROOTFS_$(ROOTFS)_TARGET_DIR),$(if $(PKG),$(PER_PACKAGE_DIR)/$($(PKG)_NAME)/target,$(BASE_TARGET_DIR)))
else
HOST_DIR := $(call qstrip,$(BR2_HOST_DIR))
TARGET_DIR = $(if $(ROOTFS),$(ROOTFS_$(ROOTFS)_TARGET_DIR),$(BASE_TARGET_DIR))
endif

ifneq ($(HOST_DIR),$(BASE_DIR)/host)
HOST_DIR_SYMLINK = $(BASE_DIR)/host
$(HOST_DIR_SYMLINK): | $(BASE_DIR)
	ln -snf $(HOST_DIR) $(HOST_DIR_SYMLINK)
endif

STAGING_DIR_SYMLINK = $(BASE_DIR)/staging
$(STAGING_DIR_SYMLINK): | $(BASE_DIR)
	ln -snf $(STAGING_DIR) $(STAGING_DIR_SYMLINK)

# Quotes are needed for spaces and all in the original PATH content.
BR_PATH = "$(HOST_DIR)/bin:$(HOST_DIR)/sbin:$(PATH)"

# Location of a file giving a big fat warning that output/target
# should not be used as the root filesystem.
TARGET_DIR_WARNING_FILE = $(TARGET_DIR)/THIS_IS_NOT_YOUR_ROOT_FILESYSTEM

ifeq ($(BR2_CCACHE),y)
CCACHE = $(HOST_DIR)/bin/ccache
BR_CACHE_DIR ?= $(call qstrip,$(BR2_CCACHE_DIR))
export BR_CACHE_DIR
HOSTCC = $(CCACHE) $(HOSTCC_NOCCACHE)
HOSTCXX = $(CCACHE) $(HOSTCXX_NOCCACHE)
export BR2_USE_CCACHE ?= 1
endif

# Scripts in support/ or post-build scripts may need to reference
# these locations, so export them so it is easier to use
export BR2_CONFIG
export BR2_REPRODUCIBLE
export TARGET_DIR
export STAGING_DIR
export HOST_DIR
export BINARIES_DIR
export BASE_DIR

################################################################################
#
# You should probably leave this stuff alone unless you know
# what you are doing.
#
################################################################################

all: world

include system/system.mk
include package/Makefile.in
# arch/arch.mk must be after package/Makefile.in because it may need to
# complement variables defined therein, like BR_NO_CHECK_HASH_FOR.
include arch/arch.mk
include support/dependencies/dependencies.mk

include $(sort $(wildcard toolchain/*.mk))
include $(sort $(wildcard toolchain/*/*.mk))

include $(sort $(wildcard package/*/*.mk))

# include and build u-boot
include boot/common.mk
# include and build kernel
include linux/linux.mk
include fs/common.mk

.PHONY: prepare
prepare: $(BUILD_DIR)/buildroot-config/auto.conf
	@$(foreach s, $(call qstrip,$(BR2_ROOTFS_PRE_BUILD_SCRIPT)), \
		$(call MESSAGE,"Executing pre-build script $(s)"); \
		$(EXTRA_ENV) $(s) \
			$(TARGET_DIR) \
			$(call qstrip,$(BR2_ROOTFS_POST_SCRIPT_ARGS)) \
			$(call qstrip,$(BR2_ROOTFS_PRE_BUILD_SCRIPT_ARGS))$(sep))

.PHONY: world
world: target-post-image

.PHONY: target-post-image
target-post-image: $(TARGETS_ROOTFS) target-finalize staging-finalize
	@rm -f $(ROOTFS_COMMON_TAR)
	$(Q)mkdir -p $(BINARIES_DIR)
	@$(foreach s, $(call qstrip,$(BR2_ROOTFS_POST_IMAGE_SCRIPT)), \
		$(call MESSAGE,"Executing post-image script $(s)"); \
		$(EXTRA_ENV) $(s) \
			$(BINARIES_DIR) \
			$(call qstrip,$(BR2_ROOTFS_POST_SCRIPT_ARGS)) \
			$(call qstrip,$(BR2_ROOTFS_POST_IMAGE_SCRIPT_ARGS))$(sep))

else # ifeq ($(BR2_HAVE_DOT_CONFIG),y)

# Some subdirectories are also package names. To avoid that "make linux"
# on an unconfigured tree produces "Nothing to be done", add an explicit
# rule for it.
# Also for 'all' we error out and ask the user to configure first.
.PHONY: linux toolchain
linux toolchain all: outputmakefile
	$(error Please configure Buildroot first (e.g. "make menuconfig"))
	@exit 1

endif # ifeq ($(BR2_HAVE_DOT_CONFIG),y)

# Cleaning
# ---------------------------------------------------------------------------

.PHONY: clean
clean:
	rm -rf $(BASE_TARGET_DIR) $(BINARIES_DIR) $(HOST_DIR) $(HOST_DIR_SYMLINK) \
		$(BUILD_DIR) $(BASE_DIR)/staging \
		$(LEGAL_INFO_DIR) $(GRAPHS_DIR) $(PER_PACKAGE_DIR) $(O)/pkg-stats.*

.PHONY: distclean
distclean: clean
ifeq ($(O),$(CURDIR)/output)
	rm -rf $(O)
endif
	rm -rf $(TOPDIR)/dl $(BR2_CONFIG) $(CONFIG_DIR)/.config.old $(CONFIG_DIR)/..config.tmp \
		$(CONFIG_DIR)/.auto.deps $(BASE_DIR)/.br2-external.*

# Documentation
# ---------------------------------------------------------------------------
# List the defconfig files
# $(1): base directory
# $(2): br2-external name, empty for bundled
define list-defconfigs
	@first=true; \
	for defconfig in $(1)/configs/*_defconfig; do \
		[ -f "$${defconfig}" ] || continue; \
		if $${first}; then \
			if [ "$(2)" ]; then \
				printf 'External configs in "$(call qstrip,$(2))":\n'; \
			else \
				printf "Built-in configs:\n"; \
			fi; \
			first=false; \
		fi; \
		defconfig="$${defconfig##*/}"; \
		printf "  %-35s - Build for %s\n" "$${defconfig}" "$${defconfig%_defconfig}"; \
	done; \
	$${first} || printf "\n"
endef

# We iterate over BR2_EXTERNAL_NAMES rather than BR2_EXTERNAL_DIRS,
# because we want to display the name of the br2-external tree.
.PHONY: list-defconfigs
list-defconfigs:
	$(call list-defconfigs,$(TOPDIR))
	$(foreach name,$(BR2_EXTERNAL_NAMES),\
		$(call list-defconfigs,$(BR2_EXTERNAL_$(name)_PATH),\
			$(BR2_EXTERNAL_$(name)_DESC))$(sep))

# Miscellaneous
# ---------------------------------------------------------------------------

# .PHONY: source
# source: $(foreach p,$(PACKAGES),$(p)-all-source)

# .PHONY: _external-deps external-deps
# _external-deps: $(foreach p,$(PACKAGES),$(p)-all-external-deps)
# external-deps:
# 	@$(MAKE1) -Bs $(EXTRAMAKEARGS) _external-deps | sort -u

# .PHONY: legal-info-clean
# legal-info-clean:
# 	@rm -fr $(LEGAL_INFO_DIR)

# .PHONY: legal-info-prepare
# legal-info-prepare: $(LEGAL_INFO_DIR)
# 	@$(call MESSAGE,"Buildroot $(BR2_VERSION_FULL) Collecting legal info")
# 	@$(call legal-license-file,HOST,buildroot,buildroot,COPYING,COPYING,support/legal-info/buildroot.hash)
# 	@$(call legal-manifest,TARGET,PACKAGE,VERSION,LICENSE,LICENSE FILES,SOURCE ARCHIVE,SOURCE SITE,DEPENDENCIES WITH LICENSES)
# 	@$(call legal-manifest,HOST,PACKAGE,VERSION,LICENSE,LICENSE FILES,SOURCE ARCHIVE,SOURCE SITE,DEPENDENCIES WITH LICENSES)
# 	@$(call legal-manifest,HOST,buildroot,$(BR2_VERSION_FULL),GPL-2.0+,COPYING,not saved,not saved)
# 	@$(call legal-warning,the Buildroot source code has not been saved)
# 	@cp $(BR2_CONFIG) $(LEGAL_INFO_DIR)/buildroot.config

# .PHONY: legal-info
# legal-info: legal-info-clean legal-info-prepare $(foreach p,$(PACKAGES),$(p)-all-legal-info) \
# 		$(REDIST_SOURCES_DIR_TARGET) $(REDIST_SOURCES_DIR_HOST)
# 	@cat support/legal-info/README.header >>$(LEGAL_REPORT)
# 	@if [ -r $(LEGAL_WARNINGS) ]; then \
# 		cat support/legal-info/README.warnings-header \
# 			$(LEGAL_WARNINGS) >>$(LEGAL_REPORT); \
# 		cat $(LEGAL_WARNINGS); fi
# 	@rm -f $(LEGAL_WARNINGS)
# 	@(cd $(LEGAL_INFO_DIR); \
# 		find * -type f -exec sha256sum {} + | LC_ALL=C sort -k2 \
# 			>.legal-info.sha256; \
# 		mv .legal-info.sha256 legal-info.sha256)
# 	@echo "Legal info produced in $(LEGAL_INFO_DIR)"

.PHONY: show-info
show-info:
	@:
	$(info $(call clean-json, \
			{ $(foreach p, \
				$(sort $(foreach i,$(PACKAGES) $(TARGETS_ROOTFS), \
						$(i) \
						$($(call UPPERCASE,$(i))_FINAL_RECURSIVE_DEPENDENCIES) \
					) \
				), \
				$(call json-info,$(call UPPERCASE,$(p)))$(comma) \
			) } \
		) \
	)

.PHONY: pkg-stats
pkg-stats:
	@cd "$(CONFIG_DIR)" ; \
	$(TOPDIR)/support/scripts/pkg-stats -c \
		--json $(O)/pkg-stats.json \
		--html $(O)/pkg-stats.html \
		--nvd-path $(DL_DIR)/buildroot-nvd

# printvars prints all the variables currently defined in our
# Makefiles. Alternatively, if a non-empty VARS variable is passed,
# only the variables matching the make pattern passed in VARS are
# displayed.
# show-vars does the same, but as a JSON dictionnary.
#
# Note: we iterate of .VARIABLES and filter each variable individually,
# to workaround a bug in make 4.3; see https://savannah.gnu.org/bugs/?59093
.PHONY: printvars
printvars:
ifndef VARS
	$(error Please pass a non-empty VARS to 'make printvars')
endif
	@:
	$(foreach V, \
		$(sort $(foreach X, $(.VARIABLES), $(filter $(VARS),$(X)))), \
		$(if $(filter-out environment% default automatic, \
				$(origin $V)), \
		$(if $(QUOTED_VARS),\
			$(info $V='$(subst ','\'',$(if $(RAW_VARS),$(value $V),$($V)))'), \
			$(info $V=$(if $(RAW_VARS),$(value $V),$($V))))))
# ')))) # Syntax colouring...

# See details above, same as for printvars
.PHONY: show-vars
show-vars: VARS?=%
show-vars:
	@:
	$(foreach i, \
		$(call clean-json, { \
			$(foreach V, \
				$(.VARIABLES), \
				$(and $(filter $(VARS),$(V)) \
					, \
					$(filter-out environment% default automatic, $(origin $V)) \
					, \
					"$V": { \
						"expanded": $(call mk-json-str,$($V))$(comma) \
						"raw": $(call mk-json-str,$(value $V)) \
					}$(comma) \
				) \
			) \
		} ) \
		, \
		$(info $(i)) \
	)

# Help
# ---------------------------------------------------------------------------

.PHONY: help
help:
	@echo 'Cleaning:'
	@echo '  clean                  - delete all files created by build'
	@echo '  distclean              - delete all non-source files (including .config)'
	@echo
	@echo 'Build:'
	@echo '  all                    - make world'
	@echo '  toolchain              - build toolchain'
	@echo '  sdk                    - build relocatable SDK'
	@echo
	@echo 'Configuration:'
	@echo '  menuconfig             - interactive curses-based configurator'
	@echo '  nconfig                - interactive ncurses-based configurator'
	@echo '  xconfig                - interactive Qt-based configurator'
	@echo '  gconfig                - interactive GTK-based configurator'
	@echo '  oldconfig              - resolve any unresolved symbols in .config'
	@echo '  syncconfig             - Same as oldconfig, but quietly, additionally update deps'
	@echo '  olddefconfig           - Same as syncconfig but sets new symbols to their default value'
	@echo '  randconfig             - New config with random answer to all options'
	@echo '  defconfig              - New config with default answer to all options;'
	@echo '                             BR2_DEFCONFIG, if set on the command line, is used as input'
	@echo '  savedefconfig          - Save current config to BR2_DEFCONFIG (minimal config)'
	@echo '  update-defconfig       - Same as savedefconfig'
	@echo '  allyesconfig           - New config where all options are accepted with yes'
	@echo '  allnoconfig            - New config where all options are answered with no'
	@echo '  alldefconfig           - New config where all options are set to default'
	@echo '  randpackageconfig      - New config with random answer to package options'
	@echo '  allyespackageconfig    - New config where pkg options are accepted with yes'
	@echo '  allnopackageconfig     - New config where package options are answered with no'
	@echo
	@echo 'Documentation:'
	@echo '  list-defconfigs        - list all defconfigs (pre-configured minimal systems)'
	@echo
	@echo 'Miscellaneous:'
	@echo '  source                 - download all sources needed for offline-build'
	@echo '  external-deps          - list external packages used'
	@echo '  legal-info             - generate info about license compliance'
	@echo '  show-info              - generate info about packages, as a JSON blurb'
	@echo '  pkg-stats              - generate info about packages as JSON and HTML'
	@echo '  printvars              - dump internal variables selected with VARS=...'
	@echo '  show-vars              - dump all internal variables as a JSON blurb; use VARS=...'
	@echo '                           to limit the list to variables names matching that pattern'
	@echo
	@echo 'For further details, see README, generate the Buildroot manual, or consult'
	@echo 'it on-line at http://buildroot.org/docs.html'
	@echo

# Other
# ---------------------------------------------------------------------------

# staging and target directories do NOT list these as
# dependencies anywhere else
$(BASE_DIR) $(BUILD_DIR) $(BASE_TARGET_DIR) $(HOST_DIR) $(BINARIES_DIR) $(LEGAL_INFO_DIR) $(REDIST_SOURCES_DIR_TARGET) $(REDIST_SOURCES_DIR_HOST) $(PER_PACKAGE_DIR):
	@mkdir -p $@

# outputmakefile generates a Makefile in the output directory, if using a
# separate output directory. This allows convenient use of make in the
# output directory.
.PHONY: outputmakefile
outputmakefile:
ifeq ($(NEED_WRAPPER),y)
	$(Q)$(TOPDIR)/support/scripts/mkmakefile $(TOPDIR) $(O)
endif

print-version:
	@echo $(BR2_VERSION_FULL)

check-package:
	$(Q)./utils/check-package `git ls-tree -r --name-only HEAD` \
		--ignore-list=$(TOPDIR)/.checkpackageignore

.PHONY: .checkpackageignore
.checkpackageignore:
	$(Q)./utils/check-package --failed-only `git ls-tree -r --name-only HEAD` \
		> .checkpackageignore

.PHONY: $(noconfig_targets)

endif #umask / $(CURDIR) / $(O)