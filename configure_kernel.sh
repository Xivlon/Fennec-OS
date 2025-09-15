#!/bin/bash
set -e

# Detect latest 6.6.x kernel version automatically
LATEST=$(curl -s https://www.kernel.org/ | grep -oP '6\.6\.\d+' | sort -V | tail -1)

KERNEL_VERSION=${KERNEL_VERSION:-$LATEST}
KERNEL_DIR="$HOME/Fennec-OS/build/linux-kernel"

echo "[+] Setting up Linux kernel $KERNEL_VERSION in $KERNEL_DIR"

mkdir -p "$KERNEL_DIR"
cd "$KERNEL_DIR"

# Download kernel
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz
tar -xf linux-$KERNEL_VERSION.tar.xz
cd linux-$KERNEL_VERSION

# Configure defaults
make defconfig

# Apply minimal tweaks
scripts/config --disable CONFIG_DEBUG_INFO
scripts/config --disable CONFIG_KALLSYMS
scripts/config --disable CONFIG_MODULES

make olddefconfig

# 6. Build kernel
echo "[+] Building kernel..." make -j"$(nproc)"

echo "[+] Kernel build complete!"

