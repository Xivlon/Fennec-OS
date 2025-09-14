# Fennec OS Development Container

This directory contains the development container configuration for Fennec OS, providing a ready-to-use development environment with all necessary build tools and dependencies.

## Features Included

- **Base Image**: Ubuntu with common development tools
- **Build Tools**: GCC, cross-compilation toolchains, make, cmake
- **Development Tools**: Git, Python, shell utilities
- **Cross-compilation**: aarch64-linux-gnu toolchain for ARM64 builds
- **Emulation**: QEMU for x86_64 and ARM system emulation
- **VS Code Extensions**: C/C++ tools, Makefile support, shell script linting

## Package Dependencies

The dev container automatically installs:
- `qemu-system-x86` and `qemu-system-arm` for emulation
- `gcc-aarch64-linux-gnu` and `binutils-aarch64-linux-gnu` for cross-compilation
- `cpio`, `bc`, `flex`, `bison`, `libssl-dev` for kernel and build support
- Various utilities: `wget`, `curl`, `xz-utils`, `file`, `rsync`, `patch`

## Environment Variables

- `FENNEC_DEV=1` - Marker indicating development container environment

## Optional Features (Currently Disabled)

To enable additional features, uncomment the relevant sections in `devcontainer.json`:

### Docker-in-Docker Support
```json
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {}
}
```

Add this VS Code extension when docker feature is enabled:
```json
"ms-azuretools.vscode-docker"
```

## Future Enhancements

- **RISC-V Support**: Add `qemu-system-misc` and `gcc-riscv64-linux-gnu` when RISC-V architecture support is implemented
- **Verification Script**: Add `scripts/devcontainer-verify.sh` for automated build testing
- **Secondary Container**: Consider docker-compose setup for additional services

## Testing Instructions

After the container is built and started:

1. Test x86_64 build:
   ```bash
   make ARCH=x86_64 rootfs
   ```

2. Test cross-compilation for ARM64:
   ```bash
   make ARCH=aarch64 rootfs
   ```

3. Verify QEMU installation:
   ```bash
   qemu-system-x86_64 --version
   qemu-system-aarch64 --version
   ```

## Usage in GitHub Codespaces

1. Navigate to the repository on GitHub
2. Click "Code" → "Codespaces" → "Create codespace on main"
3. Wait for the dev container to build and initialize
4. Start developing with all tools pre-configured