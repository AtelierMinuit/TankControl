<p align="center">
  <img src="Brand/README-header.png" alt="TankControl — HP Smart Tank 500 on macOS" width="100%" />
</p>

<h1 align="center">TankControl</h1>

<p align="center">
  Native macOS tooling for the <strong>HP Smart Tank 500 series</strong> on Apple Silicon.<br>
  Printing, scanning, device control and diagnostics — local-first and open source.
</p>

<p align="center">
  <a href="https://github.com/giorgiogpt/TankControl/actions/workflows/ci.yml"><img src="https://github.com/giorgiogpt/TankControl/actions/workflows/ci.yml/badge.svg" alt="Build status"></a>
  <a href="https://github.com/giorgiogpt/TankControl/releases/tag/v1.1.0"><img src="https://img.shields.io/badge/release-v1.1.0-4D6BFF" alt="Release v1.1.0"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-E8E5DD" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-Apple%20Silicon-0B0D10" alt="macOS Apple Silicon">
</p>

> **Independent project.** TankControl is not affiliated with, sponsored by or endorsed by HP Inc. HP and Smart Tank are trademarks of their respective owner.

## Overview

TankControl is an independent macOS project focused on interoperability with the HP Smart Tank 500 series (`0x03F0:0x2B54`). The repository combines native SwiftUI tooling, C/CUPS components, USB helpers and local diagnostic utilities.

The project is designed around three principles:

- **local-first operation** — no cloud account is required for the core tooling;
- **technical transparency** — capabilities and limitations should be inspectable in source;
- **hardware caution** — maintenance operations that can consume ink or affect the device must remain explicit and user-confirmed.

## Public project status

| Area | Status |
| --- | --- |
| Native ARM64 build | ✅ Reproducible in GitHub Actions |
| App bundle integrity | ✅ Verified in CI |
| HP Smart Tank 500 target | ✅ Project target |
| Release | ✅ `v1.1.0` published |
| License | ✅ MIT |
| Full local test suite | ⚠️ Includes hardware/corpus/package fixtures not versioned in the public repository |
| Apple notarization | ⚠️ Current distribution is not notarized |

The public CI intentionally validates the reproducible source build, bundle signature integrity and ARM64 linkage. The complete local suite contains additional integration fixtures and hardware-oriented material that are not currently suitable for the public GitHub runner.

## Main capabilities

### Printing

- CUPS-oriented native printing components.
- PCL3GUI raster tooling written in C.
- Print presets and local queue management.
- Local raster processing and ink-density controls.

### Scanning

- Dedicated USB scanner helper.
- eSCL/AirScan bridge components.
- Integration work targeting standard macOS scanning workflows.

### TankControl app

- Native SwiftUI interface for Apple Silicon.
- Printer status, diagnostics and maintenance surfaces.
- Ink-related controls and local presets.
- Mock/offline mode for development and interface testing.

### Privacy model

TankControl is designed to perform its core functions locally. See [`SECURITY.md`](SECURITY.md) for the current security and vulnerability-reporting policy.

## Screenshots

| Dashboard | Ink / maintenance |
| :---: | :---: |
| ![Dashboard](Brand/screenshots/dashboard_mockup.png) | ![InkSaver](Brand/screenshots/inksaver_mockup.png) |

Additional screenshots and design assets are kept under [`Brand/`](Brand/).

## Installation

Use the published assets from the current release:

**[Download TankControl v1.1.0 →](https://github.com/giorgiogpt/TankControl/releases/tag/v1.1.0)**

The current package is **unsigned/not notarized with an Apple Developer ID**. Review the release notes before installation. Avoid disabling Gatekeeper globally; use macOS's normal per-app approval flow when required.

## Build from source

### Requirements

- Apple Silicon Mac (`arm64`)
- macOS 12 or newer for the application target
- Xcode Command Line Tools (`swiftc`, `clang`)
- `libusb`
- Python 3 for the test tooling

### Build

```bash
brew install libusb
make build
```

The build produces the native C helpers and `TankControl.app` under the project's build workspace.

### Local test suite

```bash
make test
```

The full suite currently contains 205 tests. Some tests depend on local corpus, packaging, sanitizer or hardware-validation fixtures that are deliberately excluded from the public repository, so `make test` is not used as the public CI success criterion yet.

### Packaging

```bash
make pkg
make dmg
```

Release artifacts should be distributed through **GitHub Releases**, not committed as binary build output in the repository.

## Repository map

```text
apps/                 Native macOS application
src/                  Core source components
tools/                Driver / hardware tooling
tests/                Automated test suite
docs/                 Technical and design documentation
Brand/                Product identity and screenshots
.github/              CI, issue templates and repository metadata
research/             Engineering fixtures and supporting material
```

Build products, private captures, large corpora and local staging directories are excluded through `.gitignore`.

## Documentation

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — system architecture
- [`CHANGELOG.md`](CHANGELOG.md) — release history
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contribution workflow
- [`SECURITY.md`](SECURITY.md) — security policy
- [`.github/SUPPORT.md`](.github/SUPPORT.md) — support scope
- [`docs/BRAND-GUIDE.md`](docs/BRAND-GUIDE.md) — product visual system
- [`docs/TROUBLESHOOTING-TREE.md`](docs/TROUBLESHOOTING-TREE.md) — troubleshooting flow

## Contributing

Issues and pull requests are welcome when they are reproducible and within project scope. Use the provided issue templates and remove personal information, printer serial numbers, document contents, credentials and other sensitive material from logs or screenshots.

For security vulnerabilities, **do not open a public issue containing exploit details**. Follow [`SECURITY.md`](SECURITY.md).

## License

TankControl is distributed under the [`MIT License`](LICENSE).

---

<p align="center">
  <strong>ATELIER MINUIT</strong><br>
  <sub>Independent software, tools & experiments. · 00:00</sub>
</p>
