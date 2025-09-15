![Fennec-OS](https://github.com/Xivlon/Fennec-OS/blob/main/FennecBase.png)

   # Base Operating System For Even The Weakest of Hardware!

## Overview

Fennec OS is a lightweight, embedded-focused Linux distribution that provides:
- Custom init system (PID 1) with service supervision
- BusyBox-based userland utilities
- Minimal kernel configuration optimized for low-resource systems
- QEMU-based testing and development environment

## Quick Start

### Prerequisites

- GCC toolchain for your target architecture
- BusyBox build dependencies (available via package manager)
- QEMU for testing (optional)

For Debian/Ubuntu:
```bash
# Native x86_64 build
sudo apt install build-essential

# Cross-compilation for aarch64
sudo apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu

# QEMU for testing
sudo apt install qemu-system-x86 qemu-system-arm
```

### Building

1. **Build the init system:**
   ```bash
   make ARCH=x86_64 init
   ```

2. **Fetch and build BusyBox:**
   ```bash
   ./scripts/fetch_busybox.sh  # Downloads BusyBox 1.36.1
   make ARCH=x86_64 busybox-build
   ```

3. **Generate root filesystem:**
   ```bash
   make ARCH=x86_64 rootfs
   ```
   This creates:
   - `build/rootfs-x86_64/` - Root filesystem directory
   - `build/rootfs-x86_64.cpio.gz` - Compressed initramfs

### Testing with QEMU

Run the built system using QEMU:

```bash
# Basic run (requires kernel image)
ARCH=x86_64 scripts/run_qemu.sh

# With networking enabled
ARCH=x86_64 scripts/run_qemu.sh --networking

# Custom memory and CPU count
ARCH=x86_64 scripts/run_qemu.sh --memory 1G --cpu 4
```

**Note:** You need to provide a kernel image at `build/kernel-x86_64/arch/x86/boot/bzImage` or modify the script for your kernel location.

## Architecture Support

- **x86_64** - Primary target, fully supported
- **aarch64** - Cross-compilation support, QEMU testing
- **riscv64** - Toolchain preparation (future support)

## BusyBox Integration

Fennec OS includes a statically-linked BusyBox installation providing essential Unix utilities:

### Available Commands
The build automatically creates symlinks for commonly used commands:
- **Shell:** `sh`, `ash`
- **File operations:** `ls`, `cat`, `echo`, `mkdir`, `rm`, `mv`, `cp`, `ln`
- **Text processing:** `grep`, `sed`, `awk`, `vi`, `ed`, `tail`, `head`
- **System:** `dmesg`, `mount`, `umount`, `ps`, `top`, `free`, `uname`
- **Network:** `ip`, `ifconfig`, `ping`, `hostname`, `route`
- **Archive:** `tar`, `gzip`, `gunzip`
- **Other:** `find`, `xargs`, `chmod`, `chown`, `date`, `sync`, `kill`, `pwd`, `which`

### Customization
- BusyBox configuration: `packages/busybox/config`
- Version setting: `BUSYBOX_VERSION` in `Makefile`
- Applet selection: Modify the symlink loop in the rootfs target

## Init System

Fennec's custom init (PID 1) provides:
- Pseudo-filesystem mounting (`/proc`, `/sys`, `/dev`, `/run`)
- Kernel module loading from `/init/config/modules.list`
- Service supervision with simple dependency handling
- Logging to `/init/logs/init.log`

### Service Configuration
Services are defined in `/init/config/services/` with simple key=value format:
```
NAME=network
CMD=/init/scripts/start_network.sh
RESTART=on-failure
AFTER=logger
```

## Development

### File Structure
```
Fennec-OS/
├── init/                   # Init system source code
│   ├── init.c             # Main init process (PID 1)
│   ├── service.c          # Service management
│   ├── log.c              # Logging utilities
│   ├── config/            # System configuration
│   └── scripts/           # System scripts
├── packages/              # Package configurations
│   └── busybox/           # BusyBox configuration
├── scripts/               # Build and utility scripts
│   ├── fetch_busybox.sh   # BusyBox download script
│   └── run_qemu.sh        # QEMU launcher
└── docs/                  # Documentation
```

### Build Targets
- `make init` - Build init system only
- `make busybox-fetch` - Download BusyBox source
- `make busybox-config` - Configure BusyBox
- `make busybox-build` - Build BusyBox
- `make rootfs` - Build complete root filesystem
- `make clean` - Clean build artifacts

### Cross-compilation
```bash
# For aarch64
make ARCH=aarch64 rootfs

# For custom toolchain prefix
make ARCH=custom CROSS_PREFIX_custom=my-toolchain- rootfs
```

## Package Management

Fennec includes a minimal package script (`fpkg`) for basic package operations:
```bash
fpkg list                    # List installed packages
fpkg install <package>       # Install package (placeholder)
fpkg add-repo <url>          # Add package repository
```

## Contributing

1. Follow the existing code style and structure
2. Test changes on multiple architectures when possible
3. Update documentation for user-facing changes
4. Keep the system lightweight and embedded-focused

## License

See LICENSE file for licensing information.
