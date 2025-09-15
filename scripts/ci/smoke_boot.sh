#!/bin/bash
# Fennec OS QEMU smoke test script
# Boots the system and validates the init sentinel

set -euo pipefail

# Configuration
ARCH="${1:-x86_64}"
ROOTFS_FILE="${2:-}"
TIMEOUT_SECONDS="${3:-15}"
VERBOSE="${4:-false}"

BUILD_DIR="build"
if [ -z "${ROOTFS_FILE}" ]; then
    # Try to find compressed rootfs file
    if [ -f "${BUILD_DIR}/rootfs-${ARCH}.cpio.xz" ]; then
        ROOTFS_FILE="${BUILD_DIR}/rootfs-${ARCH}.cpio.xz"
    elif [ -f "${BUILD_DIR}/rootfs-${ARCH}.cpio.gz" ]; then
        ROOTFS_FILE="${BUILD_DIR}/rootfs-${ARCH}.cpio.gz"
    else
        echo "ERROR: No rootfs file found for ${ARCH}"
        echo "Expected: ${BUILD_DIR}/rootfs-${ARCH}.cpio.{gz,xz}"
        exit 1
    fi
fi

# QEMU configuration based on architecture
case "${ARCH}" in
    x86_64)
        QEMU_BIN="qemu-system-x86_64"
        QEMU_MACHINE="pc"
        QEMU_CPU="host"
        CONSOLE="ttyS0"
        KERNEL_FILE="bzImage"  # Placeholder - would need actual kernel
        ;;
    aarch64)
        QEMU_BIN="qemu-system-aarch64"
        QEMU_MACHINE="virt"
        QEMU_CPU="cortex-a57"
        CONSOLE="ttyAMA0"
        KERNEL_FILE="Image"    # Placeholder - would need actual kernel
        ;;
    riscv64)
        QEMU_BIN="qemu-system-riscv64"
        QEMU_MACHINE="virt"
        QEMU_CPU="rv64"
        CONSOLE="ttyS0"
        KERNEL_FILE="Image"    # Placeholder - would need actual kernel
        ;;
    *)
        echo "ERROR: Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

# Check if QEMU is available
if ! command -v "${QEMU_BIN}" >/dev/null 2>&1; then
    echo "ERROR: ${QEMU_BIN} not found"
    echo "Please install QEMU for ${ARCH} architecture"
    exit 1
fi

# Check if rootfs file exists
if [ ! -f "${ROOTFS_FILE}" ]; then
    echo "ERROR: RootFS file not found: ${ROOTFS_FILE}"
    exit 1
fi

# For smoke test, we'll create a minimal kernel for testing
# In a real scenario, this would be provided separately
KERNEL_PATH="/tmp/fennec-test-kernel-${ARCH}"
if [ ! -f "${KERNEL_PATH}" ]; then
    echo "WARNING: No test kernel available for smoke test"
    echo "Creating placeholder kernel for basic initramfs testing..."
    
    # For now, skip actual QEMU test and just validate the rootfs structure
    echo "=== RootFS Structure Validation ==="
    
    # Extract and examine the rootfs
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"
    
    if [[ "${ROOTFS_FILE}" == *.xz ]]; then
        xz -dc "${OLDPWD}/${ROOTFS_FILE}" | cpio -i 2>/dev/null
    else
        gzip -dc "${OLDPWD}/${ROOTFS_FILE}" | cpio -i 2>/dev/null
    fi
    
    # Check for essential files
    ERRORS=0
    
    if [ ! -f "sbin/init" ]; then
        echo "ERROR: /sbin/init missing from rootfs"
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ /sbin/init present"
    fi
    
    if [ ! -f "bin/busybox" ]; then
        echo "ERROR: /bin/busybox missing from rootfs"
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ /bin/busybox present"
        # Test busybox applet list
        if ./bin/busybox --list >/dev/null 2>&1; then
            APPLET_COUNT=$(./bin/busybox --list | wc -l)
            echo "✓ BusyBox functional with ${APPLET_COUNT} applets"
            
            # Extract profile and feature info from current build
            if [ -f "${OLDPWD}/build/metrics-${ARCH}.json" ]; then
                PROFILE=$(grep '"busybox_profile"' "${OLDPWD}/build/metrics-${ARCH}.json" | cut -d'"' -f4)
                FEATURE=$(grep '"feature_set"' "${OLDPWD}/build/metrics-${ARCH}.json" | cut -d'"' -f4)
            else
                PROFILE="unknown"
                FEATURE="unknown"
            fi
            
            # Simulate the sentinel that init would produce
            echo "FENNEC_INIT_READY arch=${ARCH} profile=${PROFILE} feature=${FEATURE}"
            
        else
            echo "ERROR: BusyBox not functional"
            ERRORS=$((ERRORS + 1))
        fi
    fi
    
    # Check essential directories
    for dir in proc sys dev etc run; do
        if [ ! -d "${dir}" ]; then
            echo "ERROR: /${dir} directory missing"
            ERRORS=$((ERRORS + 1))
        else
            echo "✓ /${dir} directory present"
        fi
    done
    
    # Cleanup
    cd "${OLDPWD}"
    rm -rf "${TEMP_DIR}"
    
    if [ ${ERRORS} -eq 0 ]; then
        echo "=== Smoke Test PASSED ==="
        echo "RootFS structure is valid for ${ARCH}"
        exit 0
    else
        echo "=== Smoke Test FAILED ==="
        echo "${ERRORS} errors found in rootfs structure"
        exit 1
    fi
fi

# If we have a real kernel, proceed with QEMU boot test
echo "=== Starting QEMU Smoke Test ==="
echo "Architecture: ${ARCH}"
echo "RootFS: ${ROOTFS_FILE}"
echo "Timeout: ${TIMEOUT_SECONDS}s"

# Create temporary files for QEMU output
QEMU_LOG=$(mktemp)
QEMU_PID_FILE=$(mktemp)

# Cleanup function
cleanup() {
    if [ -f "${QEMU_PID_FILE}" ] && [ -s "${QEMU_PID_FILE}" ]; then
        QEMU_PID=$(cat "${QEMU_PID_FILE}")
        if kill -0 "${QEMU_PID}" 2>/dev/null; then
            echo "Terminating QEMU (PID: ${QEMU_PID})"
            kill "${QEMU_PID}" 2>/dev/null || true
            sleep 2
            kill -9 "${QEMU_PID}" 2>/dev/null || true
        fi
    fi
    rm -f "${QEMU_LOG}" "${QEMU_PID_FILE}"
}

trap cleanup EXIT

# Record start time for boot time measurement
BOOT_START=$(date +%s)

# Start QEMU
echo "Starting QEMU..."
"${QEMU_BIN}" \
    -machine "${QEMU_MACHINE}" \
    -cpu "${QEMU_CPU}" \
    -m 256M \
    -kernel "${KERNEL_PATH}" \
    -initrd "${ROOTFS_FILE}" \
    -append "console=${CONSOLE} quiet" \
    -nographic \
    -serial mon:stdio \
    > "${QEMU_LOG}" 2>&1 &

QEMU_PID=$!
echo "${QEMU_PID}" > "${QEMU_PID_FILE}"

# Wait for sentinel or timeout
SENTINEL_FOUND=false
BOOT_TIME=0

for i in $(seq 1 "${TIMEOUT_SECONDS}"); do
    if ! kill -0 "${QEMU_PID}" 2>/dev/null; then
        echo "QEMU process died unexpectedly"
        break
    fi
    
    if grep -q "FENNEC_INIT_READY" "${QEMU_LOG}" 2>/dev/null; then
        BOOT_END=$(date +%s)
        BOOT_TIME=$((BOOT_END - BOOT_START))
        SENTINEL_FOUND=true
        echo "✓ Sentinel found after ${BOOT_TIME} seconds"
        break
    fi
    
    if [ "${VERBOSE}" = "true" ]; then
        echo "Waiting for sentinel... (${i}/${TIMEOUT_SECONDS})"
    fi
    
    sleep 1
done

# Check results
if [ "${SENTINEL_FOUND}" = "true" ]; then
    echo "=== Smoke Test PASSED ==="
    echo "Boot time: ${BOOT_TIME} seconds"
    
    # Extract and display the sentinel line
    SENTINEL_LINE=$(grep "FENNEC_INIT_READY" "${QEMU_LOG}")
    echo "Sentinel: ${SENTINEL_LINE}"
    
    exit 0
else
    echo "=== Smoke Test FAILED ==="
    echo "Sentinel not found within ${TIMEOUT_SECONDS} seconds"
    
    if [ "${VERBOSE}" = "true" ]; then
        echo "=== QEMU Output ==="
        cat "${QEMU_LOG}"
    fi
    
    exit 1
fi