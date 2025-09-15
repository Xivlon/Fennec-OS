#!/bin/bash
# Fennec OS metrics reporting script
# Collects and reports build metrics in JSON format

set -euo pipefail

ARCH="${1:-x86_64}"
BUSYBOX_PROFILE="${2:-min}"
FEATURE_SET="${3:-minimal}"
ROOTFS_COMPRESS="${4:-gzip}"

BUILD_DIR="build"
ROOTFS_DIR="${BUILD_DIR}/rootfs-${ARCH}"
INIT_BIN="${BUILD_DIR}/fennec-init-${ARCH}"
BUSYBOX_BIN="${BUILD_DIR}/busybox-build-${ARCH}/busybox"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

# Get toolchain fingerprint
TOOLCHAIN_FINGERPRINT=""
if command -v gcc >/dev/null 2>&1; then
    if [ "${ARCH}" = "aarch64" ]; then
        TOOLCHAIN_FINGERPRINT=$(aarch64-linux-gnu-gcc --version | head -1 | sha256sum | cut -d' ' -f1)
    elif [ "${ARCH}" = "riscv64" ]; then
        TOOLCHAIN_FINGERPRINT=$(riscv64-linux-gnu-gcc --version | head -1 | sha256sum | cut -d' ' -f1)
    else
        TOOLCHAIN_FINGERPRINT=$(gcc --version | head -1 | sha256sum | cut -d' ' -f1)
    fi
fi

INIT_SIZE=0
if [ -f "${INIT_BIN}" ]; then
    if stat -f%z "${INIT_BIN}" >/dev/null 2>&1; then
        # BSD stat (macOS)
        INIT_SIZE=$(stat -f%z "${INIT_BIN}")
    else
        # GNU stat (Linux)
        INIT_SIZE=$(stat -c%s "${INIT_BIN}")
    fi
fi

# Calculate BusyBox applet count
BUSYBOX_APPLET_COUNT=0
if [ -f "${BUSYBOX_BIN}" ]; then
    BUSYBOX_APPLET_COUNT=$(${BUSYBOX_BIN} --list 2>/dev/null | wc -l || echo "0")
fi

# Calculate rootfs sizes
ROOTFS_UNCOMPRESSED_SIZE=0
ROOTFS_COMPRESSED_SIZE=0
ROOTFS_FILE=""

if [ -d "${ROOTFS_DIR}" ]; then
    # Calculate uncompressed size (sum of all files) - try both stat formats
    if stat -f%z "${ROOTFS_DIR}" >/dev/null 2>&1; then
        # BSD stat (macOS)
        ROOTFS_UNCOMPRESSED_SIZE=$(find "${ROOTFS_DIR}" -type f -exec stat -f%z {} + | awk '{sum+=$1} END {print sum+0}')
    else
        # GNU stat (Linux)
        ROOTFS_UNCOMPRESSED_SIZE=$(find "${ROOTFS_DIR}" -type f -exec stat -c%s {} + | awk '{sum+=$1} END {print sum+0}')
    fi
fi

# Find compressed rootfs file
if [ "${ROOTFS_COMPRESS}" = "xz" ]; then
    ROOTFS_FILE="${BUILD_DIR}/rootfs-${ARCH}.cpio.xz"
else
    ROOTFS_FILE="${BUILD_DIR}/rootfs-${ARCH}.cpio.gz"
fi

if [ -f "${ROOTFS_FILE}" ]; then
    if stat -f%z "${ROOTFS_FILE}" >/dev/null 2>&1; then
        # BSD stat (macOS)
        ROOTFS_COMPRESSED_SIZE=$(stat -f%z "${ROOTFS_FILE}")
    else
        # GNU stat (Linux)
        ROOTFS_COMPRESSED_SIZE=$(stat -c%s "${ROOTFS_FILE}")
    fi
fi

# Calculate build duration (placeholder - would need to be passed from build system)
BUILD_DURATION_SECONDS=0

# Boot time placeholder (would be measured by smoke test)
BOOT_TIME_SECONDS=0

# Generate metrics JSON
METRICS_FILE="${BUILD_DIR}/metrics-${ARCH}.json"
cat > "${METRICS_FILE}" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "arch": "${ARCH}",
  "busybox_profile": "${BUSYBOX_PROFILE}",
  "feature_set": "${FEATURE_SET}",
  "compression": "${ROOTFS_COMPRESS}",
  "toolchain_fingerprint": "${TOOLCHAIN_FINGERPRINT}",
  "init_size_bytes": ${INIT_SIZE},
  "busybox_applet_count": ${BUSYBOX_APPLET_COUNT},
  "rootfs_uncompressed_bytes": ${ROOTFS_UNCOMPRESSED_SIZE},
  "rootfs_compressed_bytes": ${ROOTFS_COMPRESSED_SIZE},
  "build_duration_seconds": ${BUILD_DURATION_SECONDS},
  "boot_time_seconds": ${BOOT_TIME_SECONDS}
}
EOF

# Display metrics summary
echo "=== Fennec OS Build Metrics ==="
echo "Architecture: ${ARCH}"
echo "BusyBox Profile: ${BUSYBOX_PROFILE}"
echo "Feature Set: ${FEATURE_SET}"
echo "Compression: ${ROOTFS_COMPRESS}"
echo "Init Binary Size: $(printf "%'d" ${INIT_SIZE}) bytes"
echo "BusyBox Applets: ${BUSYBOX_APPLET_COUNT}"
echo "RootFS Uncompressed: $(printf "%'d" ${ROOTFS_UNCOMPRESSED_SIZE}) bytes ($(echo "scale=1; ${ROOTFS_UNCOMPRESSED_SIZE}/1024/1024" | bc)MB)"
echo "RootFS Compressed: $(printf "%'d" ${ROOTFS_COMPRESSED_SIZE}) bytes ($(echo "scale=1; ${ROOTFS_COMPRESSED_SIZE}/1024/1024" | bc)MB)"
if [ "${ROOTFS_UNCOMPRESSED_SIZE}" -gt 0 ]; then
    COMPRESSION_RATIO=$(echo "scale=1; ${ROOTFS_COMPRESSED_SIZE}*100/${ROOTFS_UNCOMPRESSED_SIZE}" | bc)
    echo "Compression Ratio: ${COMPRESSION_RATIO}%"
fi
echo "Metrics saved to: ${METRICS_FILE}"

# GitHub Actions summary if running in CI
if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    {
        echo "## 📊 Build Metrics"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| Architecture | ${ARCH} |"
        echo "| BusyBox Profile | ${BUSYBOX_PROFILE} |"
        echo "| Init Binary Size | $(printf "%'d" ${INIT_SIZE}) bytes |"
        echo "| BusyBox Applets | ${BUSYBOX_APPLET_COUNT} |"
        echo "| RootFS Compressed | $(printf "%'d" ${ROOTFS_COMPRESSED_SIZE}) bytes |"
        if [ "${ROOTFS_UNCOMPRESSED_SIZE}" -gt 0 ]; then
            echo "| Compression Ratio | ${COMPRESSION_RATIO}% |"
        fi
    } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
fi

# Output metrics file path for potential use by CI
echo "${METRICS_FILE}"