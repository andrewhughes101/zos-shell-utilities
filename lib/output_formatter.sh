#!/bin/sh
#
# output_formatter.sh - Output formatting functions for zos-shell tools
#
# Note: This library expects common.sh to be sourced by the calling script

#
# JSON formatting functions
#

# Escape special characters for JSON strings
# Usage: escaped=$(escape_json_string "string with \"quotes\"")
escape_json_string() {
    _str="$1"
    # Escape backslashes first, then quotes, newlines, tabs, etc.
    echo "$_str" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/	/\\t/g' \
        -e ':a;N;$!ba;s/\n/\\n/g'
}

# Format output as JSON
# This is a generic helper - specific tools should implement their own JSON structure
# Usage: format_json_field "key" "value"
format_json_field() {
    _key="$1"
    _value="$2"
    _escaped=$(escape_json_string "$_value")
    echo "  \"$_key\": \"$_escaped\""
}

# Format output as JSON array element
# Usage: format_json_array_element "value"
format_json_array_element() {
    _value="$1"
    _escaped=$(escape_json_string "$_value")
    echo "    \"$_escaped\""
}

# Start JSON object
# Usage: json_start
json_start() {
    echo "{"
}

# End JSON object
# Usage: json_end
json_end() {
    echo "}"
}

# Start JSON array
# Usage: json_array_start "key"
json_array_start() {
    _key="$1"
    echo "  \"$_key\": ["
}

# End JSON array
# Usage: json_array_end [comma]
json_array_end() {
    _comma="${1:-}"
    if [ -n "$_comma" ]; then
        echo "  ],"
    else
        echo "  ]"
    fi
}

#
# Human-readable formatting functions
#

# Print a horizontal line
# Usage: print_line [width] [char]
print_line() {
    _width="${1:-80}"
    _char="${2:--}"
    printf '%*s\n' "$_width" '' | tr ' ' "$_char"
}

# Print a header with separator
# Usage: print_header "Title"
print_header() {
    _title="$1"
    echo ""
    echo "$_title"
    print_line "${#_title}" "="
}

# Print a section header
# Usage: print_section "Section Name"
print_section() {
    _section="$1"
    echo ""
    echo "$_section"
    print_line "${#_section}" "-"
}

# Format a table row with fixed-width columns
# Usage: format_table_row "col1" "col2" "col3" ...
format_table_row() {
    printf "%-20s %-30s %-20s\n" "$1" "$2" "$3"
}

# Format a key-value pair
# Usage: format_key_value "Key" "Value"
format_key_value() {
    _key="$1"
    _value="$2"
    printf "%-20s: %s\n" "$_key" "$_value"
}

#
# Error and warning formatting
#

# Format error message
# Usage: format_error "message"
format_error() {
    echo "ERROR: $1" >&2
}

# Format warning message
# Usage: format_warning "message"
format_warning() {
    echo "WARNING: $1" >&2
}

# Format info message
# Usage: format_info "message"
format_info() {
    echo "INFO: $1"
}

# Format success message
# Usage: format_success "message"
format_success() {
    echo "SUCCESS: $1"
}

#
# Progress indicators
#

# Print a simple progress message
# Usage: print_progress "Processing..."
print_progress() {
    printf "%s" "$1" >&2
}

# Clear progress message
# Usage: clear_progress
clear_progress() {
    printf "\r%*s\r" 80 "" >&2
}
