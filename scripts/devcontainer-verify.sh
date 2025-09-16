#!/bin/bash
# Devcontainer verification script for Fennec OS
# Validates the development environment and performs a quick build test

set -euo pipefail

echo "=== Fennec OS Devcontainer Verification ==="
echo "Checking development environment..."

# Check for required tools
REQUIRED_TOOLS=(
    "gcc"
    "make" 
    "cpio"
    "gzip"
    "sha256sum"
    "wget"
    "tar"
    "xz"
)

MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        MISSING_TOOLS+=("${tool}")
    else
        echo "✓ ${tool} available"
    fi
done

# Check for cross-compilation toolchains
CROSS_TOOLS=(
    "aarch64-linux-gnu-gcc:aarch64"
    "riscv64-linux-gnu-gcc:riscv64"
)

for entry in "${CROSS_TOOLS[@]}"; do
    tool=$(echo "${entry}" | cut -d: -f1)
    arch=$(echo "${entry}" | cut -d: -f2)
    if command -v "${tool}" >/dev/null 2>&1; then
        echo "✓ ${arch} cross-compiler available"
    else
        echo "⚠ ${arch} cross-compiler not available (${tool})"
    fi
done

# Check for QEMU (optional)
QEMU_TOOLS=(
    "qemu-system-x86_64:x86_64"
    "qemu-system-aarch64:aarch64"
    "qemu-system-riscv64:riscv64"
)

QEMU_AVAILABLE=false
for entry in "${QEMU_TOOLS[@]}"; do
    tool=$(echo "${entry}" | cut -d: -f1)
    arch=$(echo "${entry}" | cut -d: -f2)
    if command -v "${tool}" >/dev/null 2>&1; then
        echo "✓ QEMU ${arch} available"
        QEMU_AVAILABLE=true
    else
        echo "⚠ QEMU ${arch} not available (${tool})"
    fi
done

# Report missing tools
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo "ERROR: Missing required tools:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - ${tool}"
    done
    echo ""
    echo "Please install missing tools before proceeding."
    exit 1
fi

echo ""
echo "=== Environment Validation Complete ==="
echo ""

# Quick build test
echo "=== Quick Build Test ==="
echo "Building minimal x86_64 rootfs..."

# Ensure we're in the right directory
if [ ! -f "Makefile" ]; then
    echo "ERROR: Not in Fennec OS root directory (Makefile not found)"
    exit 1
fi

# Clean any previous builds
echo "Cleaning previous builds..."
make clean >/dev/null 2>&1 || true

# Build with minimal profile
echo "Building init system..."
if ! make ARCH=x86_64 init; then
    echo "ERROR: Failed to build init system"
    exit 1
fi

echo "Fetching and configuring BusyBox..."
if ! make ARCH=x86_64 BUSYBOX_PROFILE=min busybox-build; then
    echo "ERROR: Failed to build BusyBox"
    exit 1
fi

echo "Building rootfs..."
if ! make ARCH=x86_64 BUSYBOX_PROFILE=min ROOTFS_COMPRESS=gzip rootfs; then
    echo "ERROR: Failed to build rootfs"
    exit 1
fi

# Generate metrics
echo "Generating metrics..."
if ! make ARCH=x86_64 metrics; then
    echo "ERROR: Failed to generate metrics"
    exit 1
fi

echo ""
echo "=== Build Test Results ==="
if [ -f "build/metrics-x86_64.json" ]; then
    # Display key metrics
    INIT_SIZE=$(grep '"init_size_bytes"' build/metrics-x86_64.json | cut -d: -f2 | tr -d ' ,')
    APPLET_COUNT=$(grep '"busybox_applet_count"' build/metrics-x86_64.json | cut -d: -f2 | tr -d ' ,')
    COMPRESSED_SIZE=$(grep '"rootfs_compressed_bytes"' build/metrics-x86_64.json | cut -d: -f2 | tr -d ' ,')
    
    echo "Init binary size: ${INIT_SIZE} bytes"
    echo "BusyBox applets: ${APPLET_COUNT}"
    echo "Compressed rootfs: ${COMPRESSED_SIZE} bytes"
    
    # Basic sanity checks
    if [ ${INIT_SIZE} -lt 50000 ]; then
        echo "⚠ Init binary seems unusually small"
    fi
    
    if [ ${APPLET_COUNT} -lt 20 ]; then
        echo "⚠ BusyBox applet count seems low for minimal profile"
    fi
    
    if [ ${COMPRESSED_SIZE} -lt 100000 ]; then
        echo "⚠ Compressed rootfs seems unusually small"
    fi
else
    echo "ERROR: Metrics file not generated"
    exit 1
fi

# Optional smoke test if QEMU is available
if [ "${QEMU_AVAILABLE}" = "true" ] && command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo ""
    echo "=== Optional Smoke Test ==="
    echo "Running quick smoke test with QEMU..."
    
    if ./scripts/ci/smoke_boot.sh x86_64 build/rootfs-x86_64.cpio.gz 10; then
        echo "✓ Smoke test passed"
    else
        echo "⚠ Smoke test failed (this may be expected without a proper kernel)"
    fi
fi

echo ""
echo "=== Devcontainer Verification Complete ==="
echo "✓ Environment is ready for Fennec OS development"
echo ""
echo "Next steps:"
echo "  - Run 'make help' to see available targets"
echo "  - Try building for other architectures: 'make ARCH=aarch64 rootfs'"
echo "  - Experiment with profiles: 'make BUSYBOX_PROFILE=full rootfs'"
echo "  - Test compression options: 'make ROOTFS_COMPRESS=xz rootfs'"