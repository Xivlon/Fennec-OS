# Top-level Makefile for Fennec OS

ARCH ?= x86_64
BUILD_DIR := build
INIT_SRC := init/init.c init/service.c init/log.c
INIT_OBJS := $(INIT_SRC:.c=.o)

# BusyBox configuration
BUSYBOX_VERSION := 1.36.1
BUSYBOX_SRC_DIR := $(BUILD_DIR)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_BUILD_DIR := $(BUILD_DIR)/busybox-build-$(ARCH)
BUSYBOX_CONFIG := packages/busybox/config
BUSYBOX_BIN := $(BUSYBOX_BUILD_DIR)/busybox

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
  
# BusyBox targets
busybox-fetch: $(BUILD_DIR)
	@if [ ! -f "$(BUSYBOX_BIN)" ]; then \
		echo "Fetching BusyBox..."; \
		./scripts/fetch_busybox.sh $(BUSYBOX_VERSION) $(BUILD_DIR) || \
		(echo "Warning: Could not fetch BusyBox, using dummy binary for testing"; \
		 mkdir -p $(BUSYBOX_BUILD_DIR) && \
		 echo '#!/bin/sh' > $(BUSYBOX_BIN) && \
		 echo 'echo "Dummy BusyBox - $$*"' >> $(BUSYBOX_BIN) && \
		 echo 'case "$$1" in --list) echo "sh\nash\nls\ncat\necho\ndmesg\nmount\numount\nps\ntop\nfree\nuname\nip\nifconfig\nping\nmkdir\nrm\nmv\ncp\nln\ngrep\nsed\nawk\nvi\ned\ntail\nhead\ndf\ndu\ntar\ngzip\ngunzip\npwd\nwhich\ncut\nfind\nxargs\nchmod\nchown\ndate\nsync\nkill\nmodprobe\ninsmod\nrmmod\nlsmod\nsleep\nhostname\nroute\nmore\nless";; esac' >> $(BUSYBOX_BIN) && \
		 chmod +x $(BUSYBOX_BIN)); \
	fi

busybox-config: busybox-fetch
	@if [ -d "$(BUSYBOX_SRC_DIR)" ]; then \
		mkdir -p $(BUSYBOX_BUILD_DIR) && \
		cp $(BUSYBOX_CONFIG) $(BUSYBOX_BUILD_DIR)/.config && \
		$(MAKE) -C $(BUSYBOX_SRC_DIR) O=$(realpath $(BUSYBOX_BUILD_DIR)) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_PREFIX_$(ARCH)) oldconfig; \
	else \
		echo "Using dummy BusyBox, skipping config"; \
	fi

busybox-build: busybox-config
	@if [ -d "$(BUSYBOX_SRC_DIR)" ]; then \
		$(MAKE) -C $(BUSYBOX_SRC_DIR) O=$(realpath $(BUSYBOX_BUILD_DIR)) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_PREFIX_$(ARCH)) -j$(shell nproc); \
	else \
		echo "Using dummy BusyBox, skipping build"; \
	fi

rootfs: init busybox-build
	mkdir -p $(ROOTFS_DIR)/bin $(ROOTFS_DIR)/sbin $(ROOTFS_DIR)/usr/bin $(ROOTFS_DIR)/usr/sbin
	mkdir -p $(ROOTFS_DIR)/proc $(ROOTFS_DIR)/sys $(ROOTFS_DIR)/dev $(ROOTFS_DIR)/etc $(ROOTFS_DIR)/run
	mkdir -p $(ROOTFS_DIR)/init/config/services $(ROOTFS_DIR)/init/logs $(ROOTFS_DIR)/var/log
	cp $(INIT_BIN) $(ROOTFS_DIR)/sbin/init
	# Install BusyBox and create symlinks
	cp $(BUSYBOX_BIN) $(ROOTFS_DIR)/bin/busybox
	# Create standard BusyBox symlinks
	for applet in sh ash ls cat echo dmesg mount umount ps top free uname ip ifconfig ping mkdir rm mv cp ln grep sed awk vi ed tail head df du tar gzip gunzip pwd which cut find xargs chmod chown date sync kill modprobe insmod rmmod lsmod sleep hostname route more less; do \
		if $(BUSYBOX_BIN) --list | grep -q "^$$applet$$"; then \
			ln -sf busybox $(ROOTFS_DIR)/bin/$$applet; \
		fi; \
	done
	# placeholder basic tools (expect busybox or toybox externally)
	touch $(ROOTFS_DIR)/etc/profile
	cp -r etc/* $(ROOTFS_DIR)/etc/ 2>/dev/null || true
	cp -r init/config $(ROOTFS_DIR)/init/
	cp -r init/scripts $(ROOTFS_DIR)/init/
	cp packages_fpkg $(ROOTFS_DIR)/usr/bin/fpkg || true
	chmod +x $(ROOTFS_DIR)/usr/bin/fpkg || true
	# Generate compressed initramfs
	cd $(ROOTFS_DIR) && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../rootfs-$(ARCH).cpio.gz

run: rootfs
	qemu-system-$(ARCH) -m 512M -kernel path/to/bzImage \
		-initrd $(ROOTFS_DIR).cpio.gz -nographic -append "console=ttyS0"

clean:
	rm -f $(INIT_OBJS) $(INIT_BIN)
	rm -rf $(ROOTFS_DIR)
	rm -rf $(BUSYBOX_BUILD_DIR)
	rm -f $(BUILD_DIR)/rootfs-$(ARCH).cpio.gz

.PHONY: all init clean rootfs run busybox-fetch busybox-config busybox-build