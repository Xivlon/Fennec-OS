#!/bin/bash
# RootFS manifest validation script
# Compares actual rootfs content against expected manifest

set -euo pipefail

ROOTFS_DIR="${1}"
MANIFEST_FILE="${2}"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <rootfs_dir> <manifest_file>"
    echo "Example: $0 build/rootfs-x86_64 rootfs-manifest.lst"
    exit 1
fi

if [ ! -d "${ROOTFS_DIR}" ]; then
    echo "ERROR: RootFS directory not found: ${ROOTFS_DIR}"
    exit 1
fi

if [ ! -f "${MANIFEST_FILE}" ]; then
    echo "ERROR: Manifest file not found: ${MANIFEST_FILE}"
    exit 1
fi

# Generate current rootfs file list
TEMP_CURRENT=$(mktemp)
find "${ROOTFS_DIR}" -type f -o -type l | sed "s|^${ROOTFS_DIR}||" | sort > "${TEMP_CURRENT}"

# Compare with manifest
echo "Validating rootfs content against manifest..."

TEMP_DIFF=$(mktemp)
if ! diff "${MANIFEST_FILE}" "${TEMP_CURRENT}" > "${TEMP_DIFF}"; then
    echo "ERROR: RootFS content differs from manifest!"
    echo ""
    echo "=== Differences ==="
    cat "${TEMP_DIFF}"
    echo ""
    echo "Files in manifest but missing from rootfs:"
    comm -23 "${MANIFEST_FILE}" "${TEMP_CURRENT}" | sed 's/^/  - /'
    echo ""
    echo "Files in rootfs but not in manifest:"
    comm -13 "${MANIFEST_FILE}" "${TEMP_CURRENT}" | sed 's/^/  + /'
    echo ""
    echo "To update the manifest with current rootfs content, run:"
    echo "  make update-manifest"
    
    # Cleanup
    rm -f "${TEMP_CURRENT}" "${TEMP_DIFF}"
    exit 1
else
    echo "✓ RootFS content matches manifest"
    # Cleanup
    rm -f "${TEMP_CURRENT}" "${TEMP_DIFF}"
    exit 0
fi