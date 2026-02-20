# zos-shell-utilities

A collection of z/OS shell utilities for mainframe system administration.

## Installation

### Quick Install (Latest Version)

```bash
curl -fsSL https://raw.githubusercontent.com/andrewhughes/zos-shell/main/install.sh | bash
```

### Install Specific Version

```bash
curl -fsSL https://raw.githubusercontent.com/andrewhughes/zos-shell/main/install.sh | bash -s v1.0.0
```

### Install from Main Branch (Development)

```bash
curl -fsSL https://raw.githubusercontent.com/andrewhughes/zos-shell/main/install.sh | bash -s main
```

### Manual Installation

1. Download the installer:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/andrewhughes/zos-shell/main/install.sh -o install.sh
   ```

2. Review the script (optional but recommended):
   ```bash
   cat install.sh
   ```

3. Run the installer:
   ```bash
   bash install.sh
   ```

### Custom Installation Directory

```bash
INSTALL_DIR=/path/to/bin curl -fsSL https://raw.githubusercontent.com/andrewhughes/zos-shell/main/install.sh | bash
```

## Tools

### [inuse](bin/inuse)
Check which jobs/systems are using a z/OS dataset.

**Features:**
- Display LPAR, job name, ASID, TCB address, and lock status
- JSON output support
- GRS (Global Resource Serialization) integration

**Usage:**
```bash
inuse SOME.LOAD.LIB
inuse --json MY.DATASET.NAME
```

**Requirements:** ZOAU (Z Open Automation Utilities)

### [logr_manager](bin/logr_manager)
Manage LOGR structures and log streams using IXCMIAPU.

**Features:**
- List LOGR structures with pattern matching
- Delete log streams (single or wildcard patterns)
- Interactive confirmation for bulk deletions

**Usage:**
```bash
logr_manager list
logr_manager list 'LOG_PROD_*'
logr_manager delete MYCICS.DFHLOG
logr_manager delete 'MYCICS.*'
```

**Requirements:** IXCMIAPU utility

## Requirements

- z/OS with USS (Unix System Services)
- bash or compatible shell
- curl (for installation)
- ZOAU

## Version History

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
