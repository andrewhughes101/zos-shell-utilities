#!/bin/sh
#
# jcl_parser.sh - JCL parsing and extraction functions
#
# Note: This library expects common.sh to be sourced by the calling script

# Global variables for parser state
_JCL_JOB_NAME=""
_JCL_SYMBOLS=""
_JCL_CURRENT_STEP=""
_JCL_STEPS=""

#
# JCL tokenization and line processing
#

# Check if line is a JCL comment
# Usage: if is_jcl_comment "$line"; then ...
is_jcl_comment() {
    case "$1" in
        //*) return 0 ;;
        *) return 1 ;;
    esac
}

# Check if line is a JCL continuation
# Usage: if is_jcl_continuation "$line"; then ...
is_jcl_continuation() {
    # Check if line starts with // and has content in column 72 (continuation)
    echo "$1" | grep -qE '^//[^*].*[^ ]$'
}

# Remove JCL comment prefix (//)
# Usage: content=$(strip_jcl_prefix "$line")
strip_jcl_prefix() {
    echo "$1" | sed 's|^//[* ]*||'
}

# Extract JCL statement name (first word after //)
# Usage: name=$(get_jcl_statement_name "$line")
get_jcl_statement_name() {
    _line=$(strip_jcl_prefix "$1")
    # Get first word and remove any parenthesized parameters
    echo "$_line" | awk '{print $1}' | sed 's/(.*//'
}

# Extract JCL statement operation (second word)
# Usage: op=$(get_jcl_operation "$line")
get_jcl_operation() {
    _line=$(strip_jcl_prefix "$1")
    echo "$_line" | awk '{print $2}'
}

# Extract parameter value from JCL statement
# Usage: value=$(extract_jcl_param "$line" "PGM")
extract_jcl_param() {
    _line="$1"
    _param="$2"
    echo "$_line" | sed -n "s/.*${_param}=\([^, ]*\).*/\1/p"
}

#
# JCL job parsing
#

# Parse JCL job card and extract job name
# Usage: parse_jcl_job "$jcl_content"
parse_jcl_job() {
    _content="$1"

    # Find first JOB statement (use head -1 instead of grep -m1 for z/OS compatibility)
    # Allow multiple spaces between job name and JOB keyword
    _job_line=$(echo "$_content" | grep "^//[^ ]*  *JOB" | head -1)

    if [ -z "$_job_line" ]; then
        warn "No JOB statement found in JCL"
        return 1
    fi

    # Extract job name (first word after //)
    _JCL_JOB_NAME=$(echo "$_job_line" | sed 's|^//||' | awk '{print $1}')
    debug "Found job: $_JCL_JOB_NAME"

    echo "$_JCL_JOB_NAME"
}

#
# JCL symbol parsing
#

# Parse SET statements and extract symbols
# Usage: parse_jcl_symbols "$jcl_content"
parse_jcl_symbols() {
    _content="$1"
    _symbols=""

    # Find all SET statements
    echo "$_content" | grep "^// SET " | while read -r _line; do
        # Extract symbol=value
        _assignment=$(echo "$_line" | sed 's|^// SET ||')
        _symbol=$(echo "$_assignment" | cut -d= -f1)
        _value=$(echo "$_assignment" | cut -d= -f2-)

        debug "Found symbol: $_symbol=$_value"
        echo "$_symbol=$_value"
    done
}

# Resolve symbolic parameters in a string
# Usage: resolved=$(resolve_symbols "$string" "$symbols")
resolve_symbols() {
    _string="$1"
    _symbols="$2"
    _result="$_string"

    # Replace each &SYMBOL with its value
    echo "$_symbols" | while IFS='=' read -r _sym _val; do
        _result=$(echo "$_result" | sed "s/&${_sym}/${_val}/g")
    done

    echo "$_result"
}

#
# JCL step parsing
#

# Parse EXEC statement and extract program name and parameters
# Usage: parse_jcl_step "$step_line"
parse_jcl_step() {
    _line="$1"

    # Extract step name
    _step_name=$(get_jcl_statement_name "$_line")

    # Extract program name
    _pgm=$(extract_jcl_param "$_line" "PGM")

    # Extract PARM if present
    _parm=$(extract_jcl_param "$_line" "PARM")

    # Extract COND if present
    _cond=$(extract_jcl_param "$_line" "COND")

    debug "Step: $_step_name, PGM: $_pgm, PARM: $_parm"

    # Return as pipe-delimited string
    echo "${_step_name}|${_pgm}|${_parm}|${_cond}"
}

#
# DD statement parsing
#

# Parse DD statement and extract parameters
# Usage: parse_dd_statement "$dd_line"
parse_dd_statement() {
    _line="$1"

    # Extract DD name
    _ddname=$(get_jcl_statement_name "$_line")

    # Check for DSN parameter
    _dsn=$(extract_jcl_param "$_line" "DSN")

    # Check for DISP parameter
    _disp=$(extract_jcl_param "$_line" "DISP")

    # Check for SYSOUT parameter
    _sysout=$(extract_jcl_param "$_line" "SYSOUT")

    # Check for DUMMY
    _dummy=""
    echo "$_line" | grep -q "DUMMY" && _dummy="DUMMY"

    # Check for inline data (DD *)
    _inline=""
    echo "$_line" | grep -q "DD \*" && _inline="INLINE"

    debug "DD: $_ddname, DSN: $_dsn, DISP: $_disp, SYSOUT: $_sysout"

    # Return as pipe-delimited string
    echo "${_ddname}|${_dsn}|${_disp}|${_sysout}|${_dummy}|${_inline}"
}

# Check if DD is a continuation (no DD name, starts with //)
# Usage: if is_dd_continuation "$line"; then ...
is_dd_continuation() {
    _line="$1"
    # Line starts with // but has no name before DD
    echo "$_line" | grep -qE '^//[ ]+DD '
}

# Parse concatenated DD statements
# Usage: parse_dd_concatenation "$jcl_content" "$ddname"
parse_dd_concatenation() {
    _content="$1"
    _ddname="$2"
    _datasets=""
    _in_concat=0

    echo "$_content" | while read -r _line; do
        # Check if this is the start of our DD
        if echo "$_line" | grep -q "^//${_ddname} "; then
            _in_concat=1
            _dsn=$(extract_jcl_param "$_line" "DSN")
            [ -n "$_dsn" ] && _datasets="${_datasets}${_dsn}:"
        elif [ $_in_concat -eq 1 ] && is_dd_continuation "$_line"; then
            _dsn=$(extract_jcl_param "$_line" "DSN")
            [ -n "$_dsn" ] && _datasets="${_datasets}${_dsn}:"
        elif [ $_in_concat -eq 1 ]; then
            # End of concatenation
            break
        fi
    done

    # Remove trailing colon
    echo "$_datasets" | sed 's/:$//'
}

#
# Inline data parsing
#

# Extract inline data from DD *
# Usage: data=$(parse_inline_data "$jcl_content" "$ddname")
# Returns the inline data content (lines between DD * and /*)
parse_inline_data() {
    _content="$1"
    _ddname="$2"
    _data=""
    _in_data=0
    _result=""

    # Use here-document to avoid subshell issues
    while IFS= read -r _line; do
        # Check if this is the start of inline data (allow multiple spaces)
        if echo "$_line" | grep -q "^//${_ddname}  *DD \*"; then
            _in_data=1
            continue
        fi

        # Check for end of inline data (/* or next JCL statement starting with //)
        if [ $_in_data -eq 1 ]; then
            if echo "$_line" | grep -q "^/\*"; then
                break
            fi
            if echo "$_line" | grep -q "^//"; then
                break
            fi
            # Collect data lines as-is (inline data has no // prefix)
            if [ -z "$_result" ]; then
                _result="$_line"
            else
                _result="$_result
$_line"
            fi
        fi
    done <<EOF
$_content
EOF

    echo "$_result"
}

# Check if DD has inline data
# Usage: if has_inline_data "$jcl_content" "$ddname"; then ...
has_inline_data() {
    _content="$1"
    _ddname="$2"
    echo "$_content" | grep -q "^//${_ddname} DD \*"
}

#
# JCL validation
#

# Basic JCL syntax validation
# Usage: if validate_jcl "$jcl_content"; then ...
validate_jcl() {
    _content="$1"

    # Check for JOB statement
    if ! echo "$_content" | grep -q "^//[^ ]* JOB"; then
        error_exit "No JOB statement found in JCL"
    fi

    # Check for at least one EXEC statement
    if ! echo "$_content" | grep -q " EXEC "; then
        error_exit "No EXEC statement found in JCL"
    fi

    debug "JCL validation passed"
    return 0
}

#
# High-level parsing function
#

# Parse entire JCL file and return structured data
# Usage: parse_jcl_file "$filepath"
parse_jcl_file() {
    _file="$1"

    validate_file_exists "$_file"

    # Read file content
    _content=$(cat "$_file")

    # Validate JCL
    validate_jcl "$_content"

    # Parse job name
    _job=$(parse_jcl_job "$_content")

    # Parse symbols
    _symbols=$(parse_jcl_symbols "$_content")

    debug "Parsed JCL file: $_file"
    debug "Job: $_job"

    # Return job name (symbols and steps will be parsed separately)
    echo "$_job"
}
