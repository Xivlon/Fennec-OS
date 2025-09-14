# Top-level Makefile for Fennec OS

ARCH ?= x86_64
BUILD_DIR := build
INIT_SRC := init/init.c init/service.c init/log.c
INIT_OBJS := $(INIT_SRC:.c=.o)
CROSS_PREFIX_x86_64 :=
CROSS_PREFIX_aarch64 := aarch64-linux-gnu-
CROSS_PREFIX_riscv64 := riscv64-linux-gnu-

CC := $(CROSS_PREFIX_$(ARCH))gcc
STRIP := $(CROSS_PREFIX_$(ARCH))strip

CFLAGS := -O2 -pipe -static -Wall -Wextra -Iinit
LDFLAGS := -static

INIT_BIN := $(BUILD_DIR)/fennec-init-$(ARCH)
ROOTFS_DIR := $(BUILD_DIR)/rootfs-$(ARCH)

all: init rootfs

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

init: $(BUILD_DIR) $(INIT_BIN)

$(INIT_BIN): $(INIT_OBJS)
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)
	$(STRIP) $@ || true

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

rootfs: init
	mkdir -p $(ROOTFS_DIR)/bin $(ROOTFS_DIR)/sbin $(ROOTFS_DIR)/usr/bin $(ROOTFS_DIR)/usr/sbin
	mkdir -p $(ROOTFS_DIR)/proc $(ROOTFS_DIR)/sys $(ROOTFS_DIR)/dev $(ROOTFS_DIR)/etc $(ROOTFS_DIR)/run
	mkdir -p $(ROOTFS_DIR)/init/config/services $(ROOTFS_DIR)/init/logs $(ROOTFS_DIR)/var/log
	cp $(INIT_BIN) $(ROOTFS_DIR)/sbin/init
	# placeholder basic tools (expect busybox or toybox externally)
	touch $(ROOTFS_DIR)/etc/profile
	cp -r etc/* $(ROOTFS_DIR)/etc/ 2>/dev/null || true
	cp -r init/config $(ROOTFS_DIR)/init/
	cp -r init/scripts $(ROOTFS_DIR)/init/
	cp -r packages/fpkg $(ROOTFS_DIR)/usr/bin/fpkg || true
	chmod +x $(ROOTFS_DIR)/usr/bin/fpkg || true

run: rootfs
	qemu-system-$(ARCH) -m 512M -kernel path/to/bzImage \
		-initrd $(ROOTFS_DIR).cpio.gz -nographic -append "console=ttyS0"

clean:
	rm -f $(INIT_OBJS) $(INIT_BIN)
	rm -rf $(ROOTFS_DIR)

.PHONY: all init clean rootfs run