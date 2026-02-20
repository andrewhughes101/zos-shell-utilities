#!/bin/sh
#
# zoau_utils.sh - ZOAU command wrappers and utilities
#
# Note: This library expects common.sh to be sourced by the calling script

#
# ZOAU availability checks
#

# Check if ZOAU is available
# Usage: check_zoau
check_zoau() {
    if ! command -v opercmd >/dev/null 2>&1; then
        error_exit "ZOAU is not available or not in PATH. Please ensure ZOAU is properly installed and configured."
    fi
    debug "ZOAU is available"
}

# Check if mvscmd is available
# Usage: check_mvscmd
check_mvscmd() {
    if ! command -v mvscmd >/dev/null 2>&1; then
        error_exit "mvscmd is not available. Please ensure ZOAU is properly installed."
    fi
    debug "mvscmd is available"
}

# Check if mvscmdauth is available
# Usage: check_mvscmdauth
check_mvscmdauth() {
    if ! command -v mvscmdauth >/dev/null 2>&1; then
        error_exit "mvscmdauth is not available. Please ensure ZOAU is properly installed."
    fi
    debug "mvscmdauth is available"
}

#
# Progress indicator
#

# Show a spinner while a command runs
# Usage: show_spinner PID
show_spinner() {
    _pid=$1
    while kill -0 $_pid 2>/dev/null; do
        printf "\r| Processing..."
        sleep 1
        if ! kill -0 $_pid 2>/dev/null; then break; fi
        printf "\r/ Processing..."
        sleep 1
        if ! kill -0 $_pid 2>/dev/null; then break; fi
        printf "\r- Processing..."
        sleep 1
        if ! kill -0 $_pid 2>/dev/null; then break; fi
        printf "\r\\ Processing..."
        sleep 1
    done
    printf "\r                    \r"
}

#
# mvscmd wrappers
#

# Execute mvscmd with error handling
# Usage: execute_mvscmd --pgm=PROGRAM [options]
execute_mvscmd() {
    debug "Executing mvscmd: $*"
    mvscmd "$@"
    _rc=$?
    if [ $_rc -ne 0 ]; then
        warn "mvscmd returned non-zero exit code: $_rc"
    fi
    return $_rc
}

# Execute mvscmdauth with error handling
# Usage: execute_mvscmdauth --pgm=PROGRAM [options]
execute_mvscmdauth() {
    debug "Executing mvscmdauth: $*"
    mvscmdauth "$@"
    _rc=$?
    if [ $_rc -ne 0 ]; then
        warn "mvscmdauth returned non-zero exit code: $_rc"
    fi
    return $_rc
}

# Execute mvscmd with spinner
# Usage: execute_mvscmd_with_spinner --pgm=PROGRAM [options]
execute_mvscmd_with_spinner() {
    mvscmd "$@" > /dev/null 2>&1 &
    _pid=$!
    show_spinner $_pid
    wait $_pid
    return $?
}

# Execute mvscmdauth with spinner
# Usage: execute_mvscmdauth_with_spinner --pgm=PROGRAM [options]
execute_mvscmdauth_with_spinner() {
    mvscmdauth "$@" > /dev/null 2>&1 &
    _pid=$!
    show_spinner $_pid
    wait $_pid
    return $?
}

#
# Dataset validation
#

# Validate dataset name format
# Usage: validate_dataset_name "DATASET.NAME"
validate_dataset_name() {
    _dsn="$1"

    # Check if empty
    if [ -z "$_dsn" ]; then
        return 1
    fi

    # Basic validation: alphanumeric, dots, and hyphens
    # Each qualifier should be 1-8 characters
    # Total length should not exceed 44 characters
    if [ ${#_dsn} -gt 44 ]; then
        warn "Dataset name exceeds 44 characters: $_dsn"
        return 1
    fi

    # Check for valid characters (alphanumeric, dots, hyphens, dollar signs, at signs)
    echo "$_dsn" | grep -qE '^[A-Z0-9@#$]([A-Z0-9@#$.-]*[A-Z0-9@#$])?$'
    if [ $? -ne 0 ]; then
        warn "Invalid dataset name format: $_dsn"
        return 1
    fi

    debug "Dataset name is valid: $_dsn"
    return 0
}

# Check if dataset exists using dls
# Usage: if dataset_exists "DATASET.NAME"; then ...
dataset_exists() {
    _dsn="$1"

    if ! command -v dls >/dev/null 2>&1; then
        debug "dls not available, skipping existence check"
        return 0
    fi

    dls "$_dsn" >/dev/null 2>&1
    return $?
}

#
# UNIX file utilities
#

# Check if path is a UNIX file (not a dataset)
# Usage: if is_unix_path "/path/to/file"; then ...
is_unix_path() {
    _path="$1"
    case "$_path" in
        /*) return 0 ;;  # Absolute path
        ./*) return 0 ;; # Relative path starting with ./
        ../*) return 0 ;; # Relative path starting with ../
        *) return 1 ;;   # Likely a dataset name
    esac
}

# Check if value is a special DD (stdin, stdout, dummy, etc.)
# Usage: if is_special_dd "stdin"; then ...
is_special_dd() {
    _value="$1"
    case "$(to_lowercase "$_value")" in
        stdin|stdout|stderr|dummy|dummy:|\*) return 0 ;;
        *) return 1 ;;
    esac
}
