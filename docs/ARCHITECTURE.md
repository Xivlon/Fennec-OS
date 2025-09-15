# Fennec OS Architecture

## Overview

Fennec OS is a lightweight, embedded-focused Linux distribution designed for resource-constrained environments. It provides a complete but minimal system with a custom init system, BusyBox-based utilities, and reproducible builds.

## Layered Architecture Model

```
┌─────────────────────────────────────────────────────────────┐
│                    USER APPLICATIONS                        │
│                  (Future Extensions)                       │
├─────────────────────────────────────────────────────────────┤
│                     USER SPACE                             │
│  ┌─────────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │   BusyBox       │  │   fpkg       │  │   Services     │  │
│  │   Utilities     │  │   Package    │  │   (Optional)   │  │
│  │                 │  │   Manager    │  │                │  │
│  └─────────────────┘  └──────────────┘  └────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     INIT SYSTEM (PID 1)                    │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  Fennec Init: Service Supervision & System Mgmt       │  │
│  │  • Filesystem mounting (/proc, /sys, /dev, /run)      │  │
│  │  • Module loading (config/modules.list)               │  │
│  │  • Service lifecycle management                       │  │
│  │  • Logging and monitoring                             │  │
│  └─────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      KERNEL SPACE                          │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │    Linux Kernel (LTS, Minimally Configured)           │  │
│  │    • Essential drivers and subsystems only            │  │
│  │    • Optimized for boot time and memory usage         │  │
│  └─────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      BOOTLOADER                            │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │    GRUB / syslinux / U-Boot                           │  │
│  │    • Loads kernel + initramfs                         │  │
│  │    • Minimal configuration                            │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Boot Flow

```
Power On / Reset
       │
       ▼
┌─────────────────┐
│   Bootloader    │  ← GRUB/syslinux loads kernel + initramfs
│                 │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Linux Kernel    │  ← Minimal LTS kernel initializes hardware
│ Initialization  │    and mounts initramfs as rootfs
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Fennec Init     │  ← PID 1 starts and performs:
│ (PID 1)         │    1. Mount pseudo filesystems
│                 │    2. Load kernel modules  
│                 │    3. Parse service definitions
│                 │    4. Start supervised services
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│   Userland      │  ← BusyBox utilities and services
│   Services      │    System ready for user interaction
│                 │
└─────────────────┘
     │
     ▼
FENNEC_INIT_READY arch=<ARCH> profile=<PROFILE> feature=<FEATURE>
```

## Current vs Future Responsibilities

### Current Implementation (v0.1.0)
- **Kernel**: Minimal configuration with essential drivers
- **Init System**: Basic service supervision with simple dependencies
- **Userland**: BusyBox utilities with static linking
- **Package Management**: Minimal fpkg script (placeholder)
- **Networking**: Basic interface configuration via BusyBox
- **Storage**: Initramfs-based root filesystem

### Future Enhancements (Post v1.0.0)
- **Advanced Service Management**: DAG-based dependency resolution
- **Resource Management**: cgroups integration and limits
- **Security**: Optional hardening features (capabilities, namespaces)
- **Package System**: Enhanced dependency resolution and repositories
- **Storage**: Optional pivot to persistent storage
- **Networking**: Advanced networking templates and configurations

## Component Details

### Fennec Init System
The custom init system provides:

#### Core Responsibilities
- **Process 1 (PID 1)**: System initialization and supervision
- **Filesystem Setup**: Mount essential pseudo filesystems
- **Module Loading**: Load kernel modules from configuration
- **Service Management**: Start, monitor, and restart services
- **Logging**: Centralized logging to /init/logs/

#### Service Supervision
- **Simple Dependencies**: Single AFTER directive per service
- **Restart Policies**: on-failure, always, never
- **State Tracking**: inactive → starting → active → failed
- **Resource Monitoring**: Basic process lifecycle management

#### Configuration Format
```ini
NAME=service_name
CMD=/path/to/executable
RESTART=on-failure
AFTER=dependency_service
```

### BusyBox Integration
- **Static Linking**: Self-contained utilities
- **Profile-Based**: Minimal and full configurations
- **Symlink Management**: Automatic applet symlink creation
- **Size Optimization**: Configurable feature sets

### Build System
- **Reproducible**: Deterministic builds with toolchain fingerprinting
- **Multi-Architecture**: x86_64, aarch64 (active); riscv64 (planned)
- **Configurable**: Profile, compression, and debug options
- **Cached**: Intelligent caching based on configuration hashes

## Explicit Deferrals

The following features are intentionally excluded from the current scope to maintain focus and simplicity:

### Packaging Complexity
- Complex dependency resolution algorithms
- Binary package compilation
- Multi-repository federation
- Atomic update mechanisms

### Authentication & Security
- PAM (Pluggable Authentication Modules)
- SELinux/AppArmor mandatory access control
- Advanced security hardening
- User namespace isolation

### Hardware Support
- RISC-V active CI builds (toolchain ready, builds disabled)
- Exotic architecture support
- Hardware-specific optimizations
- Bootloader customization

### Desktop Environment
- X11/Wayland display servers
- GUI toolkits and applications
- Desktop environment components
- Graphics driver integration

## Performance Targets

### Boot Time
- **Target**: <15 seconds to functional userland (QEMU)
- **Measurement**: From kernel start to FENNEC_INIT_READY sentinel
- **Optimization**: Minimal kernel config, parallel service startup

### Memory Usage
- **Target**: <32MB RSS for init + essential services
- **Measurement**: Peak resident memory during normal operation
- **Optimization**: Static linking, minimal service set

### Storage Footprint
- **Target**: <10MB compressed rootfs (minimal profile)
- **Measurement**: Final .cpio.gz artifact size
- **Optimization**: BusyBox minimal config, optimized binaries

### Build Performance
- **Target**: <5 minutes full multi-arch matrix build
- **Measurement**: CI pipeline duration end-to-end
- **Optimization**: Intelligent caching, parallel builds