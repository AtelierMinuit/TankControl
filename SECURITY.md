# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.1.x | ✅ |
| 1.0.x | ✅ |
| < 1.0 | ❌ |

## Architecture and privacy model

TankControl is designed as a local-first macOS project. Printing, scanning and device-management components are intended to operate locally, without requiring a cloud account. Hardware-affecting maintenance operations should remain explicit and user-confirmed.

## Reporting a vulnerability

**Do not disclose a security vulnerability in a public issue.**

If GitHub shows a **Report a vulnerability** option in the repository's **Security** tab, use that channel so the report can be handled privately. If private vulnerability reporting is not available, open a minimal issue that contains no exploit details and asks the maintainer to establish a private contact channel.

Please include, through the private channel when available:

- affected TankControl version and macOS version;
- affected component;
- impact and prerequisites;
- minimal reproduction steps;
- logs or proof of concept with secrets and personal data removed.

Security reports will be assessed before public disclosure. Where appropriate, a GitHub Security Advisory can be used to coordinate a fix and disclosure.
