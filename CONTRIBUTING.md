# Contributing to TankControl

Thank you for your interest in contributing to TankControl!

## Development Setup

Requirements:
- macOS 12.0+ (Apple Silicon recommended)
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.10+
- `libusb` (via Homebrew: `brew install libusb`)

## Building

You can build all C drivers and the SwiftUI app in one command:
```bash
make build
# or: ./build_all.sh --binaries --app
```

## Running Tests

Run the comprehensive 205-test suite:
```bash
make test
# or: python3 -m unittest discover -s tests
```

## Creating Installable Packages

- Official Multi-Language Installer Package (.pkg):
  ```bash
  make pkg
  # or: ./package_dist.sh
  ```

- Official Disk Image (.dmg):
  ```bash
  make dmg
  # or: ./package_dmg.sh
  ```

- Complete Release Pipeline:
  ```bash
  make release
  # or: ./build_all.sh --all
  ```

## Code Guidelines

- Adhere to Apple Human Interface Guidelines (HIG) for SwiftUI components.
- Do not add external network calls, tracking, or cloud dependencies.
- Hardware integrity: Never mock or falsify device readings in production views.
