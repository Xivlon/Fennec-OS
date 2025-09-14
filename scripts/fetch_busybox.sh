#!/usr/bin/env bash
# BusyBox fetch script for Fennec OS
set -euo pipefail

BUSYBOX_VERSION="${1:-1.36.1}"
BUILD_DIR="${2:-build}"
TARBALL="busybox-${BUSYBOX_VERSION}.tar.bz2"
URL="https://busybox.net/downloads/${TARBALL}"
SHA256_FILE="$(dirname "$0")/busybox-${BUSYBOX_VERSION}.sha256"

echo "[*] Fetching BusyBox ${BUSYBOX_VERSION}"

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"

# Check if tarball already exists and is valid
if [[ -f "${BUILD_DIR}/${TARBALL}" ]]; then
    if [[ -f "${SHA256_FILE}" ]]; then
        echo "[*] Verifying existing tarball..."
        if (cd "${BUILD_DIR}" && sha256sum -c "../${SHA256_FILE}"); then
            echo "[*] Tarball already exists and checksum matches"
        else
            echo "[*] Checksum mismatch, re-downloading..."
            rm -f "${BUILD_DIR}/${TARBALL}"
        fi
    else
        echo "[*] No checksum file found, assuming existing tarball is valid"
    fi
fi

# Download if not present
if [[ ! -f "${BUILD_DIR}/${TARBALL}" ]]; then
    echo "[*] Downloading ${URL}"
    if command -v wget >/dev/null 2>&1; then
        wget -O "${BUILD_DIR}/${TARBALL}" "${URL}"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "${BUILD_DIR}/${TARBALL}" "${URL}"
    else
        echo "Error: Neither wget nor curl found. Please install one of them."
        exit 1
    fi
fi

# Extract if source directory doesn't exist
SRC_DIR="${BUILD_DIR}/busybox-${BUSYBOX_VERSION}"
if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[*] Extracting ${TARBALL}"
    tar -xjf "${BUILD_DIR}/${TARBALL}" -C "${BUILD_DIR}"
    echo "[*] BusyBox source extracted to ${SRC_DIR}"
else
    echo "[*] BusyBox source already exists at ${SRC_DIR}"
fi

echo "[*] BusyBox fetch completed"