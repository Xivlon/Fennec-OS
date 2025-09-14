# Fennec OS Architecture

## Layers

1. Bootloader: GRUB or syslinux loads Linux LTS kernel + initramfs.
2. Kernel: Minimal configuration (see configs) with only essential built-ins.
3. Init (PID 1): Custom static binary `fennec-init`:
   - Mount pseudo FS
   - Load modules (config/modules.list)
   - Parse services (config/services/*.service)
   - Supervision & logging
4. Userland:
   - BusyBox / Toybox for core utilities
   - Optional packages via `fpkg` script
5. Configuration:
   - service definitions
   - modules list
   - shell environment in /etc

## Service Supervision

Simplistic dependency (single AFTER target). Future improvement:
- DAG resolution
- Parallel startup
- Explicit states: inactive -> starting -> active -> failed

## Logging

Currently appends to /init/logs/init.log (early root). Future:
- Move to /var/log once pivot_root
- Ring buffer viewer
- syslog compatibility

## Planned Extensions

- cgroups & resource limits
- Socket activation
- Crash dump capture
- Pluggable restart strategies (backoff)