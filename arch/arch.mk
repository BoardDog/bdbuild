################################################################################
#
# Architecture-specific definitions
#
################################################################################

# Include any architecture specific makefiles.
-include $(sort $(wildcard arch/arch.mk.*))
