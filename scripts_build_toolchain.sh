#!/usr/bin/env bash
set -euo pipefail
ARCH="${1:-x86_64}"

echo "[*] (Placeholder) Ensure cross toolchain for $ARCH installed."
echo "    For Debian/Ubuntu:"
case "$ARCH" in
  x86_64) echo "    sudo apt install build-essential" ;;
  aarch64) echo "    sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu" ;;
  riscv64) echo "    sudo apt install gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu" ;;
esac