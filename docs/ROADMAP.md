# Fennec OS Roadmap

## Hierarchical Progression Chart

Fennec OS follows a structured development approach with clear phases and deliverables. This roadmap aligns with the Hierarchical Progression Chart to ensure systematic advancement toward a production-ready embedded Linux distribution.

## Versioning Policy

### Pre-Release (0.y.z)
- **0.y.z** format during foundational development
- Minor version (y) increments for significant feature additions
- Patch version (z) increments for bug fixes and small improvements
- Breaking changes are acceptable until 1.0.0

### v0.1.0 Release Criteria
- Complete FOUNDATION PHASE implementation
- Successful multi-architecture builds (x86_64, aarch64)
- Reproducible builds with deterministic toolchain
- Basic CI/CD pipeline with smoke testing
- Comprehensive documentation (ARCHITECTURE, BUILDING, ROADMAP)

## Development Phases

### Phase 0: META CONTROL LAYER (Current)
**Objective**: Establish governance and foundational policies

**Exclusions**: The following features are explicitly deferred to maintain focus:
- Full desktop environment components (X11, Wayland, GUI toolkits)
- PAM/authentication systems (beyond basic Unix permissions)
- Complex package management (beyond minimal fpkg script)
- Advanced security hardening (SELinux, AppArmor, grsecurity)
- Container runtime integration
- Advanced networking (complex routing, VPN, firewalls)

**Deliverables**:
- [x] Governance guardrails and documented exclusions
- [x] Reproducibility and regression policy primitives
- [x] Semantic versioning guidance
- [x] Criteria for v0.1.0 tag

### Phase 1: FOUNDATION PHASE (In Progress)
**Objective**: Establish reproducible build system and minimal runtime

#### 1.1 Build & Reproducibility
- [x] Devcontainer finalization for Codespace/devcontainer builds
- [ ] Deterministic toolchain pinning with fingerprint tracking
- [ ] Makefile hardening with strict shell flags
- [ ] Multi-architecture matrix (x86_64, aarch64 active; riscv64 placeholder)

#### 1.2 Minimal RootFS Composition
- [ ] BusyBox profile separation (minimal vs full configurations)
- [ ] File allowlist manifest for rootfs content validation
- [ ] Compression strategy implementation (gzip/xz)
- [ ] Init binary size optimization with debug mode

#### 1.3 Initial CI Layer
- [ ] Build matrix with artifact management
- [ ] BusyBox build caching system
- [ ] QEMU smoke testing with automated validation
- [ ] Metrics collection and size growth controls

**Success Criteria**:
- Reproducible builds across environments
- <15s boot time to userland (QEMU smoke test)
- Minimal profile achieves >=10% size reduction vs full
- All builds pass automated validation

### Phase 2: RUNTIME & SERVICE LAYER (Future)
**Objective**: Enhanced init system and service management

**Planned Features**:
- Advanced service dependency resolution (DAG)
- Socket activation support
- cgroups integration for resource management
- Crash dump capture and analysis
- Enhanced logging with ring buffer and syslog compatibility
- Basic network service templates

**Deferred Items**:
- Systemd compatibility layer
- Complex service orchestration
- Advanced process isolation

### Phase 3: PACKAGING & EXTENSIBILITY (Future)
**Objective**: Package management and system extensibility

**Planned Features**:
- Enhanced fpkg package manager with dependency resolution
- Package repository hosting and distribution
- Atomic updates and rollback capability
- Extension mechanism for optional components
- Cross-compilation package templates

**Deferred Items**:
- Complex dependency resolution algorithms
- Binary package compilation
- Multi-repository federation

## Near-Term Goals (Next 2-4 weeks)

1. **Complete Phase 1 implementation** for v0.1.0 tag
2. **Establish CI baselines** for size and performance regression detection
3. **Documentation completion** with comprehensive build guides
4. **Community feedback integration** from initial release

## Long-Term Vision (6-12 months)

- Production-ready embedded Linux distribution
- Support for IoT and edge computing use cases
- Stable API for custom init system extensions
- Comprehensive testing framework with hardware-in-the-loop
- Performance optimization for resource-constrained environments

## Metrics and Success Indicators

### Build System Health
- Build reproducibility: 100% across environments
- Build time: <5 minutes for full multi-arch matrix
- Artifact size: <10MB compressed rootfs (minimal profile)

### Runtime Performance
- Boot time: <15s to functional userland (QEMU)
- Memory footprint: <32MB RSS for init + essential services
- Service startup: <2s for core services

### Development Velocity
- Documentation coverage: >80% of user-facing features
- CI reliability: >95% green builds on main branch
- Issue resolution: <7 days median for critical bugs

---

*Last updated: [Generated automatically during v0.1.0 preparation]*