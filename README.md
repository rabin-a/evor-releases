# Evor releases

Prebuilt binaries of [Evor](https://evor.live), project memory and coordination for coding agents.
This repository only holds releases and the install script. It contains no source code.

## Install

```bash
curl -fsSL https://evor.live/install.sh | bash
```

macOS (arm64, x86_64) and Linux (x86_64, arm64). The script picks the binary for your platform from the
latest release, checks its SHA-256 and installs it to `~/.local/bin` (or next to an existing `evor`).

- `EVOR_VERSION=v0.2.0` installs a specific release
- `EVOR_INSTALL_DIR=/path` picks the install directory

Update later with `evor update`.
