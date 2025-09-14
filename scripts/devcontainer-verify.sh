#!/usr/bin/env bash
set -euo pipefail

echo "=== Fennec OS Development Container Verification ==="
echo

# Check environment variable
echo "1. Checking environment..."
if [[ "${FENNEC_DEV:-}" == "1" ]]; then
    echo "✅ FENNEC_DEV environment variable is set"
else
    echo "❌ FENNEC_DEV environment variable not set"
    exit 1
fi

# Check basic build tools
echo "2. Checking build tools..."
tools=(gcc make strip)
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool is available"
    else
        echo "❌ $tool is not available"
        exit 1
    fi
done

# Check cross-compilation toolchain
echo "3. Checking cross-compilation toolchain..."
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    echo "✅ aarch64-linux-gnu-gcc is available"
else
    echo "❌ aarch64-linux-gnu-gcc is not available"
    exit 1
fi

# Check QEMU
echo "4. Checking QEMU emulation..."
qemu_tools=(qemu-system-x86_64 qemu-system-aarch64)
for tool in "${qemu_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool is available"
        "$tool" --version | head -1
    else
        echo "❌ $tool is not available"
        exit 1
    fi
done

# Test x86_64 build
echo "5. Testing x86_64 build..."
if make ARCH=x86_64 clean >/dev/null 2>&1; then
    echo "✅ Clean successful"
else
    echo "❌ Clean failed"
    exit 1
fi

if make ARCH=x86_64 rootfs >/dev/null 2>&1; then
    echo "✅ x86_64 build successful"
else
    echo "❌ x86_64 build failed"
    exit 1
fi

# Test aarch64 cross-compilation
echo "6. Testing aarch64 cross-compilation..."
if make ARCH=aarch64 clean >/dev/null 2>&1; then
    echo "✅ aarch64 clean successful"
else
    echo "❌ aarch64 clean failed"
    exit 1
fi

if make ARCH=aarch64 rootfs >/dev/null 2>&1; then
    echo "✅ aarch64 cross-compilation successful"
else
    echo "❌ aarch64 cross-compilation failed"
    exit 1
fi

# Check common build dependencies
echo "7. Checking additional build dependencies..."
deps=(cpio bc flex bison)
for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
        echo "✅ $dep is available"
    else
        echo "❌ $dep is not available"
        exit 1
    fi
done

echo
echo "🎉 All verification checks passed!"
echo "The Fennec OS development container is properly configured."