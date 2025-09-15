# Building Fennec OS

This guide provides comprehensive instructions for building Fennec OS in a deterministic and reproducible manner.

## Prerequisites

### System Requirements

- Linux-based system (Ubuntu 20.04+ recommended)
- At least 4GB RAM
- 10GB free disk space
- Internet connection (for downloading dependencies)

### Required Tools

```bash
# Essential build tools
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cpio \
    gzip \
    xz-utils \
    wget \
    bc \
    file

# Cross-compilation toolchains (optional)
sudo apt-get install -y \
    gcc-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    gcc-riscv64-linux-gnu \
    binutils-riscv64-linux-gnu

# QEMU for testing (optional)
sudo apt-get install -y \
    qemu-system-x86 \
    qemu-system-arm \
    qemu-system-misc
```

## Quick Start

### 1. Basic Build

Build a minimal x86_64 rootfs:

```bash
# Clone the repository
git clone https://github.com/Xivlon/Fennec-OS.git
cd Fennec-OS

# Build minimal profile for x86_64
make ARCH=x86_64 BUSYBOX_PROFILE=min rootfs

# View build metrics
make metrics
```

This creates:
- `build/fennec-init-x86_64` - Init system binary
- `build/rootfs-x86_64.cpio.gz` - Compressed root filesystem
- `build/metrics-x86_64.json` - Build metrics

### 2. Cross-compilation

Build for ARM64:

```bash
make ARCH=aarch64 BUSYBOX_PROFILE=min rootfs
```

Build for RISC-V (experimental):

```bash
make ARCH=riscv64 BUSYBOX_PROFILE=min rootfs
```

## Build Configuration

### Architecture Selection

- `ARCH=x86_64` - Intel/AMD 64-bit (default)
- `ARCH=aarch64` - ARM 64-bit  
- `ARCH=riscv64` - RISC-V 64-bit (placeholder)

### BusyBox Profiles

- `BUSYBOX_PROFILE=min` - Minimal utilities (~40-50 applets, <1MB)
- `BUSYBOX_PROFILE=full` - Comprehensive utilities (~100+ applets, ~1.5-2MB)

Profile differences:
- **Minimal**: Essential commands only, optimized for size
- **Full**: Development tools, advanced networking, editors

### Compression Options

- `ROOTFS_COMPRESS=gzip` - Fast compression, widely supported (default)
- `ROOTFS_COMPRESS=xz` - Better compression ratio, slower

### Debug Mode

- `DEBUG=0` - Optimized build with stripped binaries (default)
- `DEBUG=1` - Debug symbols, no optimization, no stripping

### Feature Sets

- `FEATURE_SET=minimal` - Base system only (default)
- `FEATURE_SET=embedded` - Embedded systems focus (future)
- `FEATURE_SET=development` - Development tools included (future)

## Build Examples

### Development Build

```bash
# Debug build with full BusyBox
make ARCH=x86_64 BUSYBOX_PROFILE=full DEBUG=1 rootfs
```

### Production Build

```bash
# Optimized minimal build with XZ compression
make ARCH=x86_64 BUSYBOX_PROFILE=min ROOTFS_COMPRESS=xz rootfs
```

### Multi-architecture Build

```bash
# Build for all supported architectures
for arch in x86_64 aarch64; do
    make ARCH=${arch} BUSYBOX_PROFILE=min rootfs
done
```

## Build Targets

### Core Targets

- `make init` - Build init system only
- `make busybox-build` - Build BusyBox only
- `make rootfs` - Build complete root filesystem
- `make clean` - Clean all build artifacts

### Utility Targets

- `make help` - Show available targets and variables
- `make metrics` - Generate and display build metrics
- `make print-metrics` - Show existing metrics
- `make update-manifest` - Update rootfs content manifest

### BusyBox Targets

- `make busybox-fetch` - Download and verify BusyBox source
- `make busybox-config` - Configure BusyBox with selected profile
- `make busybox-build` - Build BusyBox binary

## Deterministic Builds

Fennec OS implements several measures to ensure reproducible builds:

### Toolchain Fingerprinting

The build system captures toolchain versions:

```bash
# View toolchain fingerprint
make print-toolchain-fingerprint
```

### Configuration Hashing

BusyBox configurations are hashed for cache validation:

```bash
# View configuration hash
make print-config-hash
```

### Build Caching

BusyBox builds are cached based on:
- Architecture
- Profile (min/full)
- Configuration hash
- Toolchain fingerprint

Cache key format: `busybox-${ARCH}-${PROFILE}-${CONFIG_HASH}-${TOOLCHAIN_HASH}`

### Manifest Validation

The rootfs content is validated against a manifest:

```bash
# Generate initial manifest
make update-manifest

# Validate rootfs against manifest
./scripts/validate_manifest.sh build/rootfs-x86_64 rootfs-manifest.lst
```

## Testing

### Smoke Testing

Basic functionality test without a full kernel:

```bash
# Run smoke test (validates rootfs structure)
./scripts/ci/smoke_boot.sh x86_64 build/rootfs-x86_64.cpio.gz 15
```

### QEMU Testing

Full boot test with QEMU (requires kernel image):

```bash
# Run with QEMU (requires kernel)
ARCH=x86_64 scripts/run_qemu.sh
```

### Development Environment Verification

Validate the complete development environment:

```bash
# Run comprehensive environment check
./scripts/devcontainer-verify.sh
```

## Size Optimization

### Init Binary Optimization

The init system uses several optimization techniques:

- `-Os` - Optimize for size
- `-ffunction-sections -fdata-sections` - Separate functions/data
- `-Wl,--gc-sections` - Remove unused sections
- Static linking - Self-contained binary

### BusyBox Optimization

Profile selection affects size:

```bash
# Compare profile sizes
make BUSYBOX_PROFILE=min metrics
make BUSYBOX_PROFILE=full metrics
```

### Compression Comparison

```bash
# Test compression methods
make ROOTFS_COMPRESS=gzip rootfs
make ROOTFS_COMPRESS=xz rootfs
```

## Troubleshooting

### Common Issues

**BusyBox download fails:**
```bash
# The build will fall back to a dummy BusyBox for testing
# Check internet connectivity or use cached version
```

**Cross-compilation errors:**
```bash
# Install required toolchain
sudo apt-get install gcc-aarch64-linux-gnu
```

**Permission errors:**
```bash
# Ensure scripts are executable
chmod +x scripts/*.sh scripts/*/*.sh
```

### Build Verification

```bash
# Verify build outputs
ls -la build/
file build/fennec-init-*
```

### Debug Mode

```bash
# Build with debug information
make DEBUG=1 init

# Check binary info
file build/fennec-init-x86_64
readelf -h build/fennec-init-x86_64
```

## Integration with CI/CD

### GitHub Actions

The repository includes a comprehensive CI pipeline:

- Multi-architecture builds (x86_64, aarch64)
- Profile matrix (min, full)
- Artifact caching
- Smoke testing
- Size regression detection

### Local CI Simulation

```bash
# Simulate CI build locally
make clean
make ARCH=x86_64 BUSYBOX_PROFILE=min rootfs
make metrics
./scripts/ci/smoke_boot.sh x86_64 build/rootfs-x86_64.cpio.gz 15
```

## Performance Targets

### Build Performance

- Full multi-arch build: <5 minutes
- Single architecture: <2 minutes  
- Cached BusyBox build: <30 seconds

### Runtime Performance

- Boot time: <15 seconds (QEMU x86_64)
- Memory usage: <32MB RSS
- Rootfs size: <10MB compressed (minimal)

### Size Targets

- Init binary: ~900KB optimized
- Minimal rootfs: <500KB compressed
- Full rootfs: <2MB compressed

## Advanced Configuration

### Custom BusyBox Configuration

1. Start with existing profile:
```bash
cp configs/busybox/config.min configs/busybox/config.custom
```

2. Modify configuration:
```bash
# Edit configs/busybox/config.custom
```

3. Build with custom profile:
```bash
make BUSYBOX_PROFILE=custom rootfs
```

### Custom Init Features

Modify init system behavior:
- Edit `init/init.c` for core functionality
- Modify `init/service.c` for service management
- Update `init/log.c` for logging behavior

### Environment Variables

The build system respects several environment variables:

```bash
export CC=clang                    # Use different compiler
export CFLAGS="-march=native"      # Custom compiler flags
export MAKEFLAGS="-j8"             # Parallel build jobs
```

---

For more information, see:
- [Architecture Documentation](ARCHITECTURE.md)
- [Project Roadmap](ROADMAP.md)
- [README](../README.md)