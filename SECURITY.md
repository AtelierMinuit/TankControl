# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Architecture & Privacy Model

- **100% Local Execution**: TankControl and its printing/scanning filters run entirely locally on macOS. No telemetry, cloud analytics, or external phone-home requests are performed.
- **Hardware Isolation**: High-consumption or destructive printhead maintenance operations (deep purges, RAW injection) require confirmation and are locked behind Developer Mode.
- **Direct Process Execution**: Helpers communicate directly via standard UNIX primitives without invoking intermediate shell interpreters (`/bin/sh -c`).

## Reporting a Vulnerability

If you discover a security vulnerability or privilege escalation issue:
1. Please open an issue with the `security` label or contact the repository maintainer privately.
2. Provide a minimal reproduction script or demonstration.
3. Vulnerabilities will be triaged and addressed promptly.
