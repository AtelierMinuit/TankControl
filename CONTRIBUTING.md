# Contributing to TankControl

Thank you for your interest in contributing to TankControl!

## Development Setup

Requirements:
- macOS 12.0+ (Apple Silicon recommended)
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3.10+
- `libusb` (via Homebrew: `brew install libusb`)

## Building

To build the native SwiftUI application and helper tools:
```bash
./apps/HPSmartTankUtility/build_app.sh
```

To compile the C RIP filter:
```bash
clang -Wall -Wextra -O2 tools/rastertopcl3gui.c -lcups -o tools/rastertopcl3gui
```

## Running Tests

Run the comprehensive test suite:
```bash
python3 -m unittest discover -s tests
```

## Creating Installable Packages

- Official Installer Package (.pkg):
  ```bash
  ./package_dist.sh
  ```

- Disk Image (.dmg):
  ```bash
  ./package_dmg.sh
  ```

## Code Guidelines

- Adhere to Apple Human Interface Guidelines (HIG) for SwiftUI components.
- Do not add external network calls, tracking, or cloud dependencies.
- Hardware integrity: Never mock or falsify device readings in production views.
