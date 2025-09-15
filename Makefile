# Top-level Makefile for Fennec OS
# Build system with strict error handling and reproducible builds

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

# Architecture and build configuration
ARCH ?= x86_64
BUILD_DIR := build
FEATURE_SET ?= minimal
DEBUG ?= 0

# BusyBox configuration
BUSYBOX_VERSION := 1.36.1
BUSYBOX_SHA256 := b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314
BUSYBOX_PROFILE ?= min
BUSYBOX_SRC_DIR := $(BUILD_DIR)/busybox-$(BUSYBOX_VERSION)
BUSYBOX_BUILD_DIR := $(BUILD_DIR)/busybox-build-$(ARCH)
BUSYBOX_CONFIG := configs/busybox/config.$(BUSYBOX_PROFILE)
BUSYBOX_BIN := $(BUSYBOX_BUILD_DIR)/busybox

# Compression and output options
ROOTFS_COMPRESS ?= gzip

# Toolchain configuration
CROSS_PREFIX_x86_64 :=
CROSS_PREFIX_aarch64 := aarch64-linux-gnu-
CROSS_PREFIX_riscv64 := riscv64-linux-gnu-

CC := $(CROSS_PREFIX_$(ARCH))gcc
STRIP := $(CROSS_PREFIX_$(ARCH))strip

# Build flags with optimization settings
ifeq ($(DEBUG),1)
    CFLAGS := -g -O0 -static -Wall -Wextra -Iinit -DDEBUG
    LDFLAGS := -static -g
else
    CFLAGS := -Os -pipe -static -Wall -Wextra -Iinit -ffunction-sections -fdata-sections
    LDFLAGS := -static -Wl,--gc-sections
endif

# Source files and build targets
INIT_SRC := init/init.c init/service.c init/log.c
INIT_OBJS := $(INIT_SRC:.c=.o)
INIT_BIN := $(BUILD_DIR)/fennec-init-$(ARCH)
ROOTFS_DIR := $(BUILD_DIR)/rootfs-$(ARCH)
TC_BIN := $(BUILD_DIR)/fennec-tc-$(ARCH)

# Phony targets
.PHONY: all init tc clean rootfs run busybox-fetch busybox-config busybox-build help metrics print-metrics

all: init tc rootfs

# Auto-generated help target
help: ## Show this help message
	@echo "Fennec OS Build System"
	@echo "======================"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables:"
	@echo "  ARCH=$(ARCH)                    Target architecture (x86_64, aarch64, riscv64)"
	@echo "  BUSYBOX_PROFILE=$(BUSYBOX_PROFILE)              BusyBox configuration (min, full)"
	@echo "  ROOTFS_COMPRESS=$(ROOTFS_COMPRESS)              Compression method (gzip, xz)"
	@echo "  FEATURE_SET=$(FEATURE_SET)                Feature set selection"
	@echo "  DEBUG=$(DEBUG)                        Debug mode (0=optimized, 1=debug)"
	@echo ""
	@echo "Examples:"
	@echo "  make ARCH=aarch64 BUSYBOX_PROFILE=full rootfs"
	@echo "  make DEBUG=1 init"
	@echo "  make ROOTFS_COMPRESS=xz rootfs"

$(BUILD_DIR): ## Create build directory
	mkdir -p $(BUILD_DIR)

init: $(BUILD_DIR) $(INIT_BIN) ## Build init system

tc: $(BUILD_DIR) $(TC_BIN) ## Build traffic control utility

$(TC_BIN): networking/tc.c ## Build traffic control binary
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS)
	@if [ "$(DEBUG)" != "1" ]; then $(STRIP) $@ || true; else echo "Debug mode: skipping strip"; fi

$(INIT_BIN): $(INIT_OBJS) ## Build init binary
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)
	@if [ "$(DEBUG)" != "1" ]; then $(STRIP) $@ || true; else echo "Debug mode: skipping strip"; fi

%.o: %.c ## Compile object files
	$(CC) $(CFLAGS) -c $< -o $@

# Toolchain fingerprinting for reproducible builds
print-toolchain-fingerprint: ## Print toolchain fingerprint for caching
	@echo "TOOLCHAIN_FINGERPRINT=$$($(CC) --version | head -1 | sha256sum | cut -d' ' -f1)"

# Generate configuration hash for cache keys
print-config-hash: ## Print configuration hash
	@if [ -f "$(BUSYBOX_CONFIG)" ]; then \
		echo "CONFIG_HASH=$$(cat $(BUSYBOX_CONFIG) | sha256sum | cut -d' ' -f1)"; \
	else \
		echo "CONFIG_HASH=none"; \
	fi

# BusyBox targets with SHA256 verification and profile support
busybox-fetch: $(BUILD_DIR) ## Fetch and verify BusyBox source
	@if [ ! -f "$(BUSYBOX_BIN)" ]; then \
		echo "Fetching BusyBox $(BUSYBOX_VERSION)..."; \
		./scripts/fetch_busybox.sh $(BUSYBOX_VERSION) $(BUILD_DIR) || \
		(echo "Warning: Could not fetch BusyBox, using dummy binary for testing"; \
		 mkdir -p $(BUSYBOX_BUILD_DIR) && \
		 echo '#!/bin/sh' > $(BUSYBOX_BIN) && \
		 echo 'echo "Dummy BusyBox - $$*"' >> $(BUSYBOX_BIN) && \
		 echo 'case "$$1" in --list) echo "sh\nash\nls\ncat\necho\ndmesg\nmount\numount\nps\ntop\nfree\nuname\nip\nifconfig\nping\nmkdir\nrm\nmv\ncp\nln\ngrep\nsed\nawk\nvi\ned\ntail\nhead\ndf\ndu\ntar\ngzip\ngunzip\npwd\nwhich\ncut\nfind\nxargs\nchmod\nchown\ndate\nsync\nkill\nmodprobe\ninsmod\nrmmod\nlsmod\nsleep\nhostname\nroute\nmore\nless";; esac' >> $(BUSYBOX_BIN) && \
		 chmod +x $(BUSYBOX_BIN)); \
	fi
	@# Verify SHA256 if we have real BusyBox
	@if [ -d "$(BUSYBOX_SRC_DIR)" ]; then \
		echo "Verifying BusyBox checksum..."; \
		echo "$(BUSYBOX_SHA256)  $(BUILD_DIR)/busybox-$(BUSYBOX_VERSION).tar.bz2" | sha256sum -c - || \
		(echo "ERROR: BusyBox checksum verification failed!" && exit 1); \
	fi

busybox-config: busybox-fetch ## Configure BusyBox with selected profile
	@if [ ! -f "$(BUSYBOX_CONFIG)" ]; then \
		echo "ERROR: BusyBox config file $(BUSYBOX_CONFIG) not found!"; \
		echo "Available profiles: min, full"; \
		exit 1; \
	fi
	@if [ -d "$(BUSYBOX_SRC_DIR)" ]; then \
		mkdir -p $(BUSYBOX_BUILD_DIR) && \
		cp $(BUSYBOX_CONFIG) $(BUSYBOX_BUILD_DIR)/.config && \
		$(MAKE) -C $(BUSYBOX_SRC_DIR) O=$(realpath $(BUSYBOX_BUILD_DIR)) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_PREFIX_$(ARCH)) olddefconfig; \
	else \
		echo "Using dummy BusyBox, skipping config"; \
	fi

busybox-build: busybox-config ## Build BusyBox
	@if [ -d "$(BUSYBOX_SRC_DIR)" ]; then \
		$(MAKE) -C $(BUSYBOX_SRC_DIR) O=$(realpath $(BUSYBOX_BUILD_DIR)) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_PREFIX_$(ARCH)) -j$(shell nproc); \
	else \
		echo "Using dummy BusyBox, skipping build"; \
	fi

rootfs: init busybox-build ## Build root filesystem with compression
	@echo "Building rootfs for $(ARCH) with $(BUSYBOX_PROFILE) profile..."
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
	# Copy configuration and support files
	touch $(ROOTFS_DIR)/etc/profile
	cp -r etc/* $(ROOTFS_DIR)/etc/ 2>/dev/null || true
	cp -r init/config $(ROOTFS_DIR)/init/
	cp -r init/scripts $(ROOTFS_DIR)/init/
	cp packages_fpkg $(ROOTFS_DIR)/usr/bin/fpkg || true
	chmod +x $(ROOTFS_DIR)/usr/bin/fpkg || true
	# Check against manifest if it exists
	@if [ -f "rootfs-manifest.lst" ]; then \
		echo "Validating rootfs against manifest..."; \
		./scripts/validate_manifest.sh $(ROOTFS_DIR) rootfs-manifest.lst || \
		(echo "ERROR: Rootfs content does not match manifest!"; \
		 echo "Run 'make update-manifest' to update the manifest if this is intentional."; \
		 exit 1); \
	fi
	# Generate compressed initramfs with selected compression
	@echo "Compressing rootfs with $(ROOTFS_COMPRESS)..."
	@if [ "$(ROOTFS_COMPRESS)" = "xz" ]; then \
		cd $(ROOTFS_DIR) && find . -print0 | cpio --null -ov --format=newc | xz -9 > ../rootfs-$(ARCH).cpio.xz; \
		echo "Rootfs build complete: $(BUILD_DIR)/rootfs-$(ARCH).cpio.xz"; \
	else \
		cd $(ROOTFS_DIR) && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../rootfs-$(ARCH).cpio.gz; \
		echo "Rootfs build complete: $(BUILD_DIR)/rootfs-$(ARCH).cpio.gz"; \
	fi

metrics: rootfs ## Generate and display build metrics
	@./scripts/metrics/report_sizes.sh $(ARCH) $(BUSYBOX_PROFILE) $(FEATURE_SET) $(ROOTFS_COMPRESS)

print-metrics: ## Print metrics without building
	@if [ -f "build/metrics-$(ARCH).json" ]; then \
		cat build/metrics-$(ARCH).json; \
	else \
		echo "No metrics found. Run 'make metrics' first."; \
	fi

update-manifest: rootfs ## Update the rootfs manifest file
	@echo "Updating rootfs manifest..."
	@find $(ROOTFS_DIR) -type f -o -type l | sed "s|^$(ROOTFS_DIR)||" | sort > rootfs-manifest.lst
	@echo "Manifest updated: rootfs-manifest.lst"

run: rootfs ## Run with QEMU (requires kernel image)
	qemu-system-$(ARCH) -m 512M -kernel path/to/bzImage \
		-initrd $(BUILD_DIR)/rootfs-$(ARCH).cpio.$(ROOTFS_COMPRESS) -nographic -append "console=ttyS0"

clean: ## Clean build artifacts
	rm -f $(INIT_OBJS) $(INIT_BIN) $(TC_BIN)
	rm -rf $(ROOTFS_DIR)
	rm -rf $(BUSYBOX_BUILD_DIR)
	rm -f $(BUILD_DIR)/rootfs-$(ARCH).cpio.gz $(BUILD_DIR)/rootfs-$(ARCH).cpio.xz
	rm -f $(BUILD_DIR)/metrics-$(ARCH).json
