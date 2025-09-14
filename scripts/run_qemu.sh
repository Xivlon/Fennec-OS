#!/usr/bin/env bash
# QEMU runner script for Fennec OS
set -euo pipefail

# Default values
ARCH="${ARCH:-x86_64}"
MEMORY="${MEMORY:-512M}"
CPU_COUNT="${CPU_COUNT:-2}"
ENABLE_NETWORKING="${ENABLE_NETWORKING:-0}"
KERNEL_PATH=""
INITRD_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --arch|-a)
      ARCH="$2"
      shift 2
      ;;
    --memory|-m)
      MEMORY="$2"
      shift 2
      ;;
    --cpu|-c)
      CPU_COUNT="$2"
      shift 2
      ;;
    --networking|-n)
      ENABLE_NETWORKING=1
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --arch, -a ARCH      Target architecture (x86_64, aarch64) [default: x86_64]"
      echo "  --memory, -m SIZE    Memory size [default: 512M]"
      echo "  --cpu, -c COUNT      CPU count [default: 2]"
      echo "  --networking, -n     Enable networking"
      echo "  --help, -h           Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Determine kernel and initrd paths based on architecture
case "$ARCH" in
  x86_64)
    KERNEL_PATH="build/kernel-x86_64/arch/x86/boot/bzImage"
    QEMU_BINARY="qemu-system-x86_64"
    QEMU_MACHINE=""
    QEMU_CPU=""
    ;;
  aarch64)
    KERNEL_PATH="build/kernel-aarch64/arch/arm64/boot/Image"
    QEMU_BINARY="qemu-system-aarch64"
    QEMU_MACHINE="-machine virt"
    QEMU_CPU="-cpu cortex-a53"
    ;;
  *)
    echo "Error: Unsupported architecture: $ARCH"
    echo "Supported architectures: x86_64, aarch64"
    exit 1
    ;;
esac

INITRD_PATH="build/rootfs-${ARCH}.cpio.gz"

# Check if required files exist
if [[ ! -f "$INITRD_PATH" ]]; then
  echo "Error: Initrd not found at $INITRD_PATH"
  echo "Please run 'make ARCH=$ARCH rootfs' first"
  exit 1
fi

# Check if kernel exists (optional warning)
if [[ ! -f "$KERNEL_PATH" ]]; then
  echo "Warning: Kernel not found at $KERNEL_PATH"
  echo "Using dummy kernel path - you may need to build or provide the kernel"
fi

# Check if QEMU binary is available
if ! command -v "$QEMU_BINARY" >/dev/null 2>&1; then
  echo "Error: $QEMU_BINARY not found in PATH"
  echo "Please install QEMU for $ARCH architecture"
  exit 1
fi

# Build QEMU command
QEMU_CMD=(
  "$QEMU_BINARY"
  $QEMU_MACHINE
  $QEMU_CPU
  -m "$MEMORY"
  -smp "$CPU_COUNT"
  -kernel "$KERNEL_PATH"
  -initrd "$INITRD_PATH"
  -nographic
  -append "console=ttyS0 init=/sbin/init"
)

# Add networking if enabled
if [[ "$ENABLE_NETWORKING" -eq 1 ]]; then
  case "$ARCH" in
    x86_64)
      QEMU_CMD+=(
        -netdev user,id=net0,hostfwd=tcp::2222-:22
        -device e1000,netdev=net0
      )
      ;;
    aarch64)
      QEMU_CMD+=(
        -netdev user,id=net0,hostfwd=tcp::2222-:22
        -device virtio-net-pci,netdev=net0
      )
      ;;
  esac
fi

echo "[*] Starting Fennec OS with QEMU"
echo "[*] Architecture: $ARCH"
echo "[*] Memory: $MEMORY"
echo "[*] CPU Count: $CPU_COUNT"
echo "[*] Kernel: $KERNEL_PATH"
echo "[*] Initrd: $INITRD_PATH"
echo "[*] Networking: $([ $ENABLE_NETWORKING -eq 1 ] && echo "enabled" || echo "disabled")"
echo "[*] Command: ${QEMU_CMD[*]}"
echo "[*] Use Ctrl+A, X to exit QEMU"
echo ""

# Execute QEMU
exec "${QEMU_CMD[@]}"