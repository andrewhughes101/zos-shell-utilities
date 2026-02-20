#!/bin/sh
#
# common.sh - Common utility functions for zos-shell tools
#

# Global variables for verbose/debug mode
VERBOSE=${VERBOSE:-0}
DEBUG=${DEBUG:-0}

#
# Error handling functions
#

# Print error message and exit
# Usage: error_exit "message" [exit_code]
error_exit() {
    _msg="$1"
    _code="${2:-1}"
    echo "Error: $_msg" >&2
    exit "$_code"
}

# Print warning message
# Usage: warn "message"
warn() {
    echo "Warning: $1" >&2
}

# Print debug message if debug mode is enabled
# Usage: debug "message"
debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "DEBUG: $1" >&2
    fi
}

# Print verbose message if verbose mode is enabled
# Usage: verbose "message"
verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "$1" >&2
    fi
}

#
# String utility functions
#

# Convert string to uppercase
# Usage: result=$(to_uppercase "string")
to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Convert string to lowercase
# Usage: result=$(to_lowercase "string")
to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Trim leading and trailing whitespace
# Usage: result=$(trim_whitespace "  string  ")
trim_whitespace() {
    echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Split string by delimiter and return nth element (1-based)
# Usage: result=$(split_string "a:b:c" ":" 2)  # returns "b"
split_string() {
    _str="$1"
    _delim="$2"
    _index="$3"
    echo "$_str" | awk -F"$_delim" "{print \$$_index}"
}

#
# Temporary file management
#

# Global variable to track temp files
_TEMP_FILES=""

# Create temporary file and track it for cleanup
# Usage: tmpfile=$(create_temp_file "prefix")
create_temp_file() {
    _prefix="${1:-tmp}"
    _tmpdir="${TMPDIR:-/tmp}"
    _tmpfile="$_tmpdir/${_prefix}_$$.tmp"
    touch "$_tmpfile" || error_exit "Failed to create temporary file: $_tmpfile"
    _TEMP_FILES="$_TEMP_FILES $_tmpfile"
    echo "$_tmpfile"
}

# Cleanup all tracked temporary files
# Usage: cleanup_temp_files
cleanup_temp_files() {
    if [ -n "$_TEMP_FILES" ]; then
        for _file in $_TEMP_FILES; do
            if [ -f "$_file" ]; then
                rm -f "$_file"
                debug "Removed temporary file: $_file"
            fi
        done
        _TEMP_FILES=""
    fi
}

# Setup trap for cleanup on exit
# Usage: setup_trap
setup_trap() {
    trap cleanup_temp_files EXIT INT TERM
}

#
# Validation functions
#

# Check if a value is empty
# Usage: validate_required "value" "parameter_name"
validate_required() {
    _value="$1"
    _name="$2"
    if [ -z "$_value" ]; then
        error_exit "$_name is required"
    fi
}

# Check if a file exists
# Usage: validate_file_exists "path"
validate_file_exists() {
    _path="$1"
    if [ ! -f "$_path" ]; then
        error_exit "File not found: $_path"
    fi
}

# Check if a directory exists
# Usage: validate_dir_exists "path"
validate_dir_exists() {
    _path="$1"
    if [ ! -d "$_path" ]; then
        error_exit "Directory not found: $_path"
    fi
}

#
# Argument parsing helpers
#

# Check if argument is a flag (starts with -)
# Usage: if is_flag "$arg"; then ...
is_flag() {
    case "$1" in
        -*) return 0 ;;
        *) return 1 ;;
    esac
}

# Extract value from --key=value format
# Usage: value=$(extract_value "--key=value")
extract_value() {
    echo "$1" | cut -d= -f2-
}

# Check if argument has value (--key=value format)
# Usage: if has_value "$arg"; then ...
has_value() {
    echo "$1" | grep -q '='
}
