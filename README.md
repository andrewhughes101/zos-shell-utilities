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

### [jcl2mvscmd](bin/jcl2mvscmd)
Translate JCL batch jobs to shell scripts using mvscmd.

**Features:**
- Converts JCL EXEC/DD statements to mvscmd commands
- Maps SYSOUT to Unix log files
- Supports JCL symbols as script parameters
- Handles concatenated datasets and inline data
- Proper DISP parameter mapping (SHR, OLD, MOD, NEW)
- Extracts inline data (DD *) to files in ./sysin/ directory
- Smart input detection (MVS datasets or Unix files)
- Authorization support (--auth flag for mvscmdauth)
- Dry-run mode for preview
- Verbose mode for debugging

**Usage:**
```bash
# Translate JCL file to shell script
jcl2mvscmd myjob.jcl -o myjob.sh

# Translate MVS dataset
jcl2mvscmd 'MY.JCL.LIB(MYJOB)' -o myjob.sh

# Use authorized programs
jcl2mvscmd myjob.jcl -o myjob.sh --auth

# Preview translation without writing file
jcl2mvscmd myjob.jcl --dry-run

# Custom log directory
jcl2mvscmd myjob.jcl -o myjob.sh --log-dir /var/log/batch

# Override JCL symbols
jcl2mvscmd myjob.jcl --symbol INFILE=MY.DATA --symbol OUTFILE=MY.OUT
```

**Supported JCL Features:**
- EXEC PGM= and PARM= parameters
- DD statements (DSN, DISP, SYSOUT, DUMMY)
- DISP parameters (SHR, OLD, MOD, NEW) mapped to mvscmd options
- Concatenated datasets (colon-separated)
- Inline data (DD *) - extracted to ./sysin/ directory
- JCL symbols (SET statements) - mapped to script parameters
- Unnamed steps (auto-generated as STEP1, STEP2, etc.)

**Generated Script Structure:**
- Creates ./logs/ directory for SYSOUT output
- Creates ./sysin/ directory for inline data files
- Inline data files named: `{job}_{step}_{ddname}.txt`
- Error handling with return code checking
- Timestamped logging

**DISP Parameter Mapping:**
- `DISP=SHR` -> `--ddname=dsn,shr` (shared access)
- `DISP=OLD` -> `--ddname=dsn,old` (exclusive access)
- `DISP=MOD` -> `--ddname=dsn,mod` (modify/append)
- `DISP=NEW` -> `--ddname=dsn,new` (create new)

**Inline Data Handling:**
```jcl
//SYSIN DD *
DATA LINE 1
DATA LINE 2
/*
```
Becomes:
```bash
cat > "$SYSIN_DIR/myjob_step1_sysin.txt" << 'INLINE_DATA_EOF'
DATA LINE 1
DATA LINE 2
INLINE_DATA_EOF

mvscmd --pgm=myprog --sysin=./sysin/myjob_step1_sysin.txt
```

**Limitations:**
- Does not support JCL procedures (PROC)
- Does not support conditional logic (IF/THEN/ELSE, COND)
- Does not support GDG references or tape datasets
- Does not support JCLLIB or INCLUDE statements

**Requirements:** ZOAU with mvscmd/mvscmdauth

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
