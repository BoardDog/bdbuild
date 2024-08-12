################################################################################
#
# skeleton-ubuntu-base
#
################################################################################

SKELETON_UBUNTU_BASE_ARCH = $(call qstrip,$(BR2_UBUNTU_BASE_ARCH))
SKELETON_UBUNTU_BASE_VERSION = $(call qstrip,$(BR2_UBUNTU_BASE_RELEASE))
SKELETON_UBUNTU_BASE_SOURCE = ubuntu-base-$(SKELETON_UBUNTU_BASE_VERSION)-base-$(SKELETON_UBUNTU_BASE_ARCH).tar.gz
SKELETON_UBUNTU_BASE_SITE = https://cdimage.ubuntu.com/ubuntu-base/releases/$(SKELETON_UBUNTU_BASE_VERSION)/release

SKELETON_UBUNTU_BASE_ADD_TOOLCHAIN_DEPENDENCY = NO
SKELETON_UBUNTU_BASE_ADD_SKELETON_DEPENDENCY = NO

SKELETON_UBUNTU_BASE_DEPENDENCIES = skeleton-init-common

SKELETON_UBUNTU_BASE_PROVIDES = skeleton

define SKELETON_UBUNTU_BASE_EXTRACT_CMDS
	$(if $(SKELETON_UBUNTU_BASE_SOURCE), \
		mkdir -p $(@D)/rootfs/ && \
		$(TAR) -xzf $(SKELETON_UBUNTU_BASE_DL_DIR)/$(SKELETON_UBUNTU_BASE_SOURCE) -C $(@D)/rootfs/ \
	)
endef

define SKELETON_UBUNTU_BASE_INSTALL_TARGET_CMDS
	$(call SYSTEM_RSYNC,$(@D)/rootfs/,$(TARGET_DIR))
	$(call INIT_BASE_ROOTFS,$(SKELETON_UBUNTU_BASE_ARCH),$(TARGET_DIR))
	chmod 777 $(TARGET_DIR)/tmp/
	$(call EXECUTECMD,$(TARGET_DIR),"apt-get update")
	$(INSTALL) -m 0644 support/misc/target-dir-warning.txt $(TARGET_DIR_WARNING_FILE)
endef

SKELETON_UBUNTU_BASE_HOSTNAME = $(call qstrip,$(BR2_TARGET_GENERIC_HOSTNAME))
SKELETON_UBUNTU_BASE_ISSUE = $(call qstrip,$(BR2_TARGET_GENERIC_ISSUE))
SKELETON_UBUNTU_BASE_ROOT_PASSWD = $(call qstrip,$(BR2_TARGET_GENERIC_ROOT_PASSWD))
SKELETON_UBUNTU_BASE_PASSWD_METHOD = $(call qstrip,$(BR2_TARGET_GENERIC_PASSWD_METHOD))
SKELETON_UBUNTU_BASE_BIN_SH = $(call qstrip,$(BR2_SYSTEM_BIN_SH))

ifneq ($(SKELETON_UBUNTU_BASE_HOSTNAME),)
SKELETON_UBUNTU_BASE_HOSTS_LINE = $(SKELETON_UBUNTU_BASE_HOSTNAME)
SKELETON_UBUNTU_BASE_SHORT_HOSTNAME = $(firstword $(subst ., ,$(SKELETON_UBUNTU_BASE_HOSTNAME)))
ifneq ($(SKELETON_UBUNTU_BASE_HOSTNAME),$(SKELETON_UBUNTU_BASE_SHORT_HOSTNAME))
SKELETON_UBUNTU_BASE_HOSTS_LINE += $(SKELETON_UBUNTU_BASE_SHORT_HOSTNAME)
endif
define SKELETON_UBUNTU_BASE_SET_HOSTNAME
	mkdir -p $(TARGET_DIR)/etc
	echo "$(SKELETON_UBUNTU_BASE_HOSTNAME)" > $(TARGET_DIR)/etc/hostname
	$(SED) '$$a \127.0.1.1\t$(SKELETON_UBUNTU_BASE_HOSTS_LINE)' \
		-e '/^127.0.1.1/d' $(TARGET_DIR)/etc/hosts
endef
SKELETON_UBUNTU_BASE_TARGET_FINALIZE_HOOKS += SKELETON_UBUNTU_BASE_SET_HOSTNAME
endif

ifneq ($(SKELETON_UBUNTU_BASE_ISSUE),)
define SKELETON_UBUNTU_BASE_SET_ISSUE
	echo "$(SKELETON_UBUNTU_BASE_ISSUE)" > $(TARGET_DIR)/etc/issue
endef
SKELETON_UBUNTU_BASE_TARGET_FINALIZE_HOOKS += SKELETON_UBUNTU_BASE_SET_ISSUE
endif

ifeq ($(BR2_TARGET_ENABLE_ROOT_LOGIN),y)
ifneq ($(filter $$1$$% $$5$$% $$6$$%,$(SKELETON_UBUNTU_BASE_ROOT_PASSWD)),)
SKELETON_UBUNTU_BASE_ROOT_PASSWORD = '$(SKELETON_UBUNTU_BASE_ROOT_PASSWD)'
else ifneq ($(SKELETON_UBUNTU_BASE_ROOT_PASSWD),)
# This variable will only be evaluated in the finalize stage, so we can
# be sure that host-mkpasswd will have already been built by that time.
SKELETON_UBUNTU_BASE_ROOT_PASSWORD = "`$(MKPASSWD) -m "$(SKELETON_UBUNTU_BASE_PASSWD_METHOD)" "$(SKELETON_UBUNTU_BASE_ROOT_PASSWD)"`"
endif
else # !BR2_TARGET_ENABLE_ROOT_LOGIN
SKELETON_UBUNTU_BASE_ROOT_PASSWORD = "*"
endif
define SKELETON_UBUNTU_BASE_SET_ROOT_PASSWD
	$(SED) s,^root:[^:]*:,root:$(SKELETON_UBUNTU_BASE_ROOT_PASSWORD):, $(TARGET_DIR)/etc/shadow
endef
SKELETON_UBUNTU_BASE_TARGET_FINALIZE_HOOKS += SKELETON_UBUNTU_BASE_SET_ROOT_PASSWD

ifeq ($(BR2_SYSTEM_BIN_SH_NONE),y)
define SKELETON_UBUNTU_BASE_SET_BIN_SH
	rm -f $(TARGET_DIR)/bin/sh
endef
else
# Add /bin/sh to /etc/shells otherwise some login tools like dropbear
# can reject the user connection. See man shells.
define SKELETON_UBUNTU_BASE_ADD_SH_TO_SHELLS
	grep -qsE '^/bin/sh$$' $(TARGET_DIR)/etc/shells \
		|| echo "/bin/sh" >> $(TARGET_DIR)/etc/shells
endef
SKELETON_UBUNTU_BASE_TARGET_FINALIZE_HOOKS += SKELETON_UBUNTU_BASE_ADD_SH_TO_SHELLS
ifneq ($(SKELETON_UBUNTU_BASE_BIN_SH),)
define SKELETON_UBUNTU_BASE_SET_BIN_SH
	ln -sf $(SKELETON_UBUNTU_BASE_BIN_SH) $(TARGET_DIR)/bin/sh
	$(SED) '/^root:/s,[^/]*$$,$(SKELETON_UBUNTU_BASE_BIN_SH),' \
		$(TARGET_DIR)/etc/passwd
endef
endif
endif
SKELETON_UBUNTU_BASE_TARGET_FINALIZE_HOOKS += SKELETON_UBUNTU_BASE_SET_BIN_SH

$(eval $(generic-package))
