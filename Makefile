#
# Default config file is in $(TOPDIR)/board/$(BOARD_NAME)/*_defconfig
# First, run xxx_defconfig
# Then, `make menuconfig' if needed
#

TOPDIR=$(shell pwd)

CONFIG_CONFIG_IN=Config.in
CONFIG_DEFCONFIG=.defconfig
CONFIG=config

CONFIG_SHELL=$(shell which bash)
ifeq ($(CONFIG_SHELL),)
$(error GNU Bash is needed to build Bootstrap!)
endif

BINDIR:=$(TOPDIR)/binaries

DATE := $(shell date)
VERSION := 3.6.2
REVISION :=
SCMINFO := $(shell ($(TOPDIR)/host-utilities/setlocalversion $(TOPDIR)))

# Use 'make V=1' for the verbose mode
ifneq ("$(origin V)", "command line")
Q=@
export Q
MAKE_OPTION=--no-print-directory
endif

noconfig_targets:= menuconfig defconfig $(CONFIG) oldconfig

# Check first if we want to configure at91bootstrap
#
ifeq ($(filter $(noconfig_targets),$(MAKECMDGOALS)),)
-include .config
endif

include	host-utilities/host.mk

ifeq ($(HAVE_DOT_CONFIG),)

all: menuconfig

# configuration
# ---------------------------------------------------------------------------

HOSTCFLAGS=$(CFLAGS_FOR_BUILD)
export HOSTCFLAGS

$(CONFIG)/conf:
	@mkdir -p $(CONFIG)/at91bootstrap-config
	@$(MAKE) $(MAKE_OPTION) CC="$(HOSTCC)" -C $(CONFIG) conf
	-@if [ ! -f .config ]; then \
		cp $(CONFIG_DEFCONFIG) .config; \
	fi

$(CONFIG)/mconf:
	@mkdir -p $(CONFIG)/at91bootstrap-config
	@$(MAKE) $(MAKE_OPTION) CC="$(HOSTCC)" -C $(CONFIG) conf mconf
	-@if [ ! -f .config ]; then \
		cp $(CONFIG_DEFCONFIG) .config; \
	fi

menuconfig: $(CONFIG)/mconf
	@mkdir -p $(CONFIG)/at91bootstrap-config
	@if ! KCONFIG_AUTOCONFIG=$(CONFIG)/at91bootstrap-config/auto.conf \
		KCONFIG_AUTOHEADER=$(CONFIG)/at91bootstrap-config/autoconf.h \
		$(CONFIG)/mconf $(CONFIG_CONFIG_IN); then \
		test -f .config.cmd || rm -f .config; \
	fi

$(CONFIG): $(CONFIG)/conf
	@mkdir -p $(CONFIG)/at91bootstrap-config
	@KCONFIG_AUTOCONFIG=$(CONFIG)/at91bootstrap-config/auto.conf \
		KCONFIG_AUTOHEADER=$(CONFIG)/at91bootstrap-config/autoconf.h \
		$(CONFIG)/conf $(CONFIG_CONFIG_IN)

oldconfig: $(CONFIG)/conf
	@mkdir -p $(CONFIG)/at91bootstrap-config
	@KCONFIG_AUTOCONFIG=$(CONFIG)/at91bootstrap-config/auto.conf \
		KCONFIG_AUTOHEADER=$(CONFIG)/at91bootstrap-config/autoconf.h \
		$(CONFIG)/conf -o $(CONFIG_CONFIG_IN)

defconfig: $(CONFIG)/conf
	@mkdir -p $(CONFIG)/at91bootstrap-config
	@KCONFIG_AUTOCONFIG=$(CONFIG)/at91bootstrap-config/auto.conf \
		KCONFIG_AUTOHEADER=$(CONFIG)/at91bootstrap-config/autoconf.h \
		$(CONFIG)/conf -d $(CONFIG_CONFIG_IN)


else #  Have DOT Config

HOSTARCH := $(shell uname -m | sed -e s/arm.*/arm/)

AS=$(CROSS_COMPILE)gcc
CC=$(CROSS_COMPILE)gcc
LD=$(CROSS_COMPILE)ld
NM= $(CROSS_COMPILE)nm
SIZE=$(CROSS_COMPILE)size
OBJCOPY=$(CROSS_COMPILE)objcopy
OBJDUMP=$(CROSS_COMPILE)objdump

PROJECT := $(strip $(subst ",,$(CONFIG_PROJECT)))
IMG_ADDRESS := $(strip $(subst ",,$(CONFIG_IMG_ADDRESS)))
IMG_SIZE := $(strip $(subst ",,$(CONFIG_IMG_SIZE)))
JUMP_ADDR := $(strip $(subst ",,$(CONFIG_JUMP_ADDR)))
OF_OFFSET := $(strip $(subst ",,$(CONFIG_OF_OFFSET)))
OF_ADDRESS := $(strip $(subst ",,$(CONFIG_OF_ADDRESS)))
BOOTSTRAP_MAXSIZE := $(strip $(subst ",,$(CONFIG_BOOTSTRAP_MAXSIZE)))
MEMORY := $(strip $(subst ",,$(CONFIG_MEMORY)))
IMAGE_NAME:= $(strip $(subst ",,$(CONFIG_IMAGE_NAME)))
CARD_SUFFIX := $(strip $(subst ",,$(CONFIG_CARD_SUFFIX)))
MEM_BANK := $(strip $(subst ",,$(CONFIG_MEM_BANK)))
MEM_SIZE := $(strip $(subst ",,$(CONFIG_MEM_SIZE)))
LINUX_KERNEL_ARG_STRING := $(strip $(subst ",,$(CONFIG_LINUX_KERNEL_ARG_STRING)))

# Board definitions
BOARDNAME:=$(strip $(subst ",,$(CONFIG_BOARDNAME)))

MACH_TYPE:=$(strip $(subst ",,$(CONFIG_MACH_TYPE)))
LINK_ADDR:=$(strip $(subst ",,$(CONFIG_LINK_ADDR)))
DATA_SECTION_ADDR:=$(strip $(subst ",,$(CONFIG_DATA_SECTION_ADDR)))
TOP_OF_MEMORY:=$(strip $(subst ",,$(CONFIG_TOP_OF_MEMORY)))

# CRYSTAL is UNUSED
CRYSTAL:=$(strip $(subst ",,$(CONFIG_CRYSTAL)))

# driver definitions
SPI_CLK:=$(strip $(subst ",,$(CONFIG_SPI_CLK)))
SPI_BOOT:=$(strip $(subst ",,$(CONFIG_SPI_BOOT)))

ifeq ($(REVISION),)
REV:=
else
REV:=-$(strip $(subst ",,$(REVISION)))
endif

ifeq ($(CONFIG_OF_LIBFDT), y)
BLOB:=-dt
else
BLOB:=
endif

ifeq ($(CONFIG_LOAD_LINUX), y)
TARGET_NAME:=linux-$(subst I,i,$(IMAGE_NAME))
endif

ifeq ($(CONFIG_LOAD_ANDROID), y)
TARGET_NAME:=android-$(subst I,i,$(IMAGE_NAME))
endif

ifeq ($(CONFIG_LOAD_UBOOT), y)
TARGET_NAME:=$(subst -,,$(basename $(IMAGE_NAME)))
endif

ifeq ($(CONFIG_LOAD_64KB), y)
TARGET_NAME:=$(basename $(IMAGE_NAME))
endif

ifeq ($(CONFIG_LOAD_1MB), y)
TARGET_NAME:=$(basename $(IMAGE_NAME))
endif

ifeq ($(CONFIG_LOAD_4MB), y)
TARGET_NAME:=$(basename $(IMAGE_NAME))
endif

BOOT_NAME=$(BOARDNAME)-$(PROJECT)$(CARD_SUFFIX)boot-$(TARGET_NAME)$(BLOB)-$(VERSION)$(REV)
AT91BOOTSTRAP:=$(BINDIR)/$(BOOT_NAME).bin

ifeq ($(IMAGE),)
IMAGE=$(BOOT_NAME).bin
endif

ifeq ($(SYMLINK),)
SYMLINK=at91bootstrap.bin
endif

COBJS-y:= $(TOPDIR)/main.o $(TOPDIR)/board/$(BOARDNAME)/$(BOARDNAME).o
SOBJS-y:= $(TOPDIR)/crt0_gnu.o

include	lib/libc.mk
include	driver/driver.mk
include	fs/src/fat.mk

#$(SOBJS-y:.o=.S)

SRCS:= $(COBJS-y:.o=.c)
OBJS:= $(SOBJS-y) $(COBJS-y)
INCL=board/$(BOARDNAME)
GC_SECTIONS=--gc-sections

CPPFLAGS=-ffunction-sections -g -Os -Wall \
	-fno-stack-protector \
	-I$(INCL) -Iinclude -Ifs/include \
	-DAT91BOOTSTRAP_VERSION=\"$(VERSION)$(REV)$(SCMINFO)\" -DCOMPILE_TIME="\"$(DATE)\""

ASFLAGS=-g -Os -Wall -I$(INCL) -Iinclude

include	toplevel_cpp.mk
include	board/board_cpp.mk
include	driver/driver_cpp.mk

# Linker flags.
#  -Wl,...:     tell GCC to pass this to linker.
#    -Map:      create map file
#    --cref:    add cross reference to map file
#  -lc 	   : 	tells the linker to tie in newlib
#  -lgcc   : 	tells the linker to tie in newlib
LDFLAGS+=-nostartfiles -Map=$(BINDIR)/$(BOOT_NAME).map --cref -static
LDFLAGS+=-T elf32-littlearm.lds $(GC_SECTIONS) -Ttext $(LINK_ADDR)

ifneq ($(DATA_SECTION_ADDR),)
LDFLAGS+=-Tdata $(DATA_SECTION_ADDR)
endif

gccversion := $(shell expr `$(CC) -dumpversion`)

ifdef YYY   # For other utils
ifeq ($(CC),gcc) 
TARGETS=no-cross-compiler
else
TARGETS=$(AT91BOOTSTRAP) host-utilities .config filesize
endif
endif

TARGETS=$(AT91BOOTSTRAP)

PHONY:=all

all: CheckCrossCompile PrintFlags $(AT91BOOTSTRAP) ChkFileSize

CheckCrossCompile:
	@( if [ "$(HOSTARCH)" != "arm" ]; then \
		if [ "x$(CROSS_COMPILE)" == "x" ]; then \
			echo "error: Environment variable "CROSS_COMPILE" must be defined!"; \
			exit 2; \
		fi \
	fi )

PrintFlags:
	@echo CC
	@echo ========
	@echo $(CC) $(gccversion)&& echo
	@echo as FLAGS
	@echo ========
	@echo $(ASFLAGS) && echo
	@echo gcc FLAGS
	@echo =========
	@echo $(CPPFLAGS) && echo
	@echo ld FLAGS
	@echo ========
	@echo $(LDFLAGS) && echo

$(AT91BOOTSTRAP): $(OBJS)
	$(if $(wildcard $(BINDIR)),,mkdir -p $(BINDIR))
	@echo "  LD        "$(BOOT_NAME).elf
	@$(LD) $(LDFLAGS) -n -o $(BINDIR)/$(BOOT_NAME).elf $(OBJS)
#	@$(OBJCOPY) --strip-debug --strip-unneeded $(BINDIR)/$(BOOT_NAME).elf -O binary $(BINDIR)/$(BOOT_NAME).bin
	@$(OBJCOPY) --strip-all $(BINDIR)/$(BOOT_NAME).elf -O binary $@

%.o : %.c .config
	@echo "  CC        "$<
	@$(CC) $(CPPFLAGS) -c -o $@ $<

%.o : %.S .config
	@echo "  AS        "$<
	@$(AS) $(ASFLAGS)  -c -o $@  $<


$(AT91BOOTSTRAP).fixboot: $(AT91BOOTSTRAP)
	./scripts/fixboot.py $(AT91BOOTSTRAP)

boot: $(AT91BOOTSTRAP).fixboot

PHONY+= boot bootstrap

rebuild: clean all

ChkFileSize: $(AT91BOOTSTRAP)
	@( fsize=`stat -c%s $(BINDIR)/$(BOOT_NAME).bin`; \
	  echo "Size of $(BOOT_NAME).bin is $$fsize bytes"; \
	  if [ "$$fsize" -gt "$(BOOTSTRAP_MAXSIZE)" ] ; then \
		echo "[Failed***] It's too big to fit into SRAM area. the support maxium size is $(BOOTSTRAP_MAXSIZE)"; \
		rm -rf $(BINDIR); \
		exit 2;\
	  else \
	  	echo "[Succeeded] It's OK to fit into SRAM area"; \
	  fi )
endif  # HAVE_DOT_CONFIG

PHONY+= rebuild

%_defconfig:
	@(conf_file=`find ./board -name $@`; \
	if [ "$$conf_file"x != "x" ]; then \
		cp $$conf_file .config; \
	else \
		echo "Error: *** Cannot find file: $@"; \
		exit 2; \
	fi )
	@$(MAKE) oldconfig

update:
	cp .config board/$(BOARDNAME)/$(BOARDNAME)_defconfig

no-cross-compiler:
	@echo
	@echo
	@echo
	@echo "	You should consider using a cross compiler for ARM !"
	@echo "	I.E: CROSS_COMPILE should contains something useful."
	@echo

debug:
	@echo CONFIG=$(CONFIG)
	@echo AS=$(AS)
	@echo CROSS_COMPILE=$(CROSS_COMPILE)

PHONY+=update no-cross-compiler debug

distrib: mrproper
	$(Q)find . -type f \( -name .depend \
		-o -name '*.srec' \
		-o -name '*.elf' \
		-o -name '*.map' \
		-o -name '*.o' \
		-o -name '*~' \) \
		-print0 \
		| xargs -0 rm -f
	$(Q)rm -fr result
	$(Q)rm -fr build
	$(Q)rm -fr ..make.deps.tmp
	$(Q)rm -fr config/conf

config-clean:
	@echo "  CLEAN        "configuration files!
	$(Q)make $(MAKE_OPTION) -C config distclean
	$(Q)rm -fr config/at91bootstrap-config
	$(Q)rm -f  config/.depend

clean:
	@echo "  CLEAN        "obj and misc files!
	$(Q)find . -type f \( -name .depend \
		-o -name '*.srec' \
		-o -name '*.o' \
		-o -name '*~' \) \
		-print0 \
		| xargs -0 rm -f

distclean: clean config-clean
#	rm -fr $(BINDIR)
	$(Q)rm -fr .config .config.cmd .config.old
	$(Q)rm -fr .auto.deps
	$(Q)rm -f .installed
	$(Q)rm -f ..*.tmp
	$(Q)rm -f .configured

mrproper: distclean
	@echo "  CLEAN        "binary files!
	$(Q)rm -fr $(BINDIR)
	$(Q)rm -fr log

PHONY+=distrib config-clean clean distclean mrproper

tarball: distrib
	$(Q)rm -fr ../source/at91bootstrap-$(VERSION)
	$(Q)rm -fr ../source/at91bootstrap-$(VERSION).tar*
	$(Q)mkdir -p ../source
	$(Q)find . -depth -print0 | cpio --null -pd ../source/at91bootstrap-$(VERSION)
	$(Q)rm -fr ../source/at91bootstrap-$(VERSION)/.git
	$(Q)tar -C ../source -cf ../source/at91bootstrap-$(VERSION).tar at91bootstrap-$(VERSION)
	$(Q)bzip2  ../source/at91bootstrap-$(VERSION).tar
	cp ../source/at91bootstrap-$(VERSION).tar.bz2 /usr/local/install/downloads

tarballx: clean
	$(Q)F=`basename $(CURDIR)` ; cd .. ; \
	$(Q)T=`basename $(CURDIR)`-$(VERSION).tar ;  \
	$(Q)tar --force-local -cf $$T $$F > /dev/null; \
	$(Q)rm -f $$T.bz2 ; \
	$(Q)bzip2 $$T ; \
	cp -f $$T.bz2 /usr/local/install/downloads

PHONY+=tarball tarballx

.PHONY: $(PHONY)
