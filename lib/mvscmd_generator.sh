#!/bin/sh
#
# mvscmd_generator.sh - Generate mvscmd commands from parsed JCL
#
# Note: This library expects common.sh and zoau_utils.sh to be sourced by the calling script

# Default log directory
DEFAULT_LOG_DIR="./logs"

#
# DISP mapping functions
#

# Map JCL DISP to mvscmd options
# Usage: options=$(map_disp_to_options "SHR")
map_disp_to_options() {
    _disp="$1"

    # Handle DISP=(status,normal,abnormal) format
    _status=$(echo "$_disp" | sed 's/[()]//g' | cut -d, -f1)

    case "$_status" in
        OLD) echo "old" ;;
        MOD) echo "mod" ;;
        NEW) echo "new" ;;
        SHR) echo "shr" ;;
        *) echo "shr" ;;  # Default to shared access if not specified
    esac
}

#
# DD to mvscmd option mapping
#

# Map DD statement to mvscmd option
# Usage: option=$(map_dd_to_option "$ddname" "$dsn" "$disp" "$sysout" "$dummy" "$inline" "$stepname")
map_dd_to_option() {
    _ddname="$1"
    _dsn="$2"
    _disp="$3"
    _sysout="$4"
    _dummy="$5"
    _inline="$6"
    _stepname="${7:-step}"

    _ddname_lower=$(to_lowercase "$_ddname")

    # Handle DUMMY
    if [ -n "$_dummy" ]; then
        echo "--${_ddname_lower}=dummy:"
        return
    fi

    # Handle inline data (DD *) - SYSIN uses stdin, others use absolute file paths
    if [ -n "$_inline" ]; then
        if [ "$_ddname_lower" = "sysin" ]; then
            # SYSIN must use stdin
            echo "--${_ddname_lower}=stdin"
        else
            # Other inline DDs use absolute file paths with $SYSIN_DIR
            _jobname="${JOB_NAME:-job}"
            _stepname_lower=$(to_lowercase "$_stepname")
            _inline_file="\$SYSIN_DIR/${_jobname}_${_stepname_lower}_${_ddname_lower}.txt"
            echo "--${_ddname_lower}=${_inline_file}"
        fi
        return
    fi

    # Handle SYSOUT - map to log file
    if [ -n "$_sysout" ]; then
        _logfile=$(map_sysout_to_logfile "$_ddname")
        echo "--${_ddname_lower}=${_logfile}"
        return
    fi

    # Handle DSN
    if [ -n "$_dsn" ]; then
        _options=$(map_disp_to_options "$_disp")
        if [ -n "$_options" ]; then
            echo "--${_ddname_lower}=${_dsn},${_options}"
        else
            echo "--${_ddname_lower}=${_dsn}"
        fi
        return
    fi

    # Default: empty DD
    echo "--${_ddname_lower}=dummy:"
}

#
# SYSOUT to log file mapping
#

# Map SYSOUT to log file path (absolute path using $LOG_DIR variable)
# Usage: logfile=$(map_sysout_to_logfile "$ddname")
map_sysout_to_logfile() {
    _ddname="$1"
    _jobname="${JOB_NAME:-job}"
    _stepname="${STEP_NAME:-step}"
    _ddname_lower=$(to_lowercase "$_ddname")

    echo "\$LOG_DIR/${_jobname}_${_stepname}_${_ddname_lower}.log"
}

# Generate log file path
# Usage: logpath=$(generate_log_path "$jobname" "$stepname" "$ddname")
generate_log_path() {
    _jobname="$1"
    _stepname="$2"
    _ddname="$3"
    _logdir="${LOG_DIR:-$DEFAULT_LOG_DIR}"
    _ddname_lower=$(to_lowercase "$_ddname")

    echo "${_logdir}/${_jobname}_${_stepname}_${_ddname_lower}.log"
}

#
# Concatenation handling
#

# Generate concatenated dataset string
# Usage: concat=$(generate_concatenation "DSN1:DSN2:DSN3")
generate_concatenation() {
    _datasets="$1"
    # Already in correct format (colon-separated)
    echo "$_datasets"
}

#
# mvscmd command generation
#

# Generate complete mvscmd command for a step
# Usage: cmd=$(generate_mvscmd_command "$stepname" "$pgm" "$parm" "$dd_options" "$jobname")
generate_mvscmd_command() {
    _stepname="$1"
    _pgm="$2"
    _parm="$3"
    _jobname="$4"
    shift 4
    _dd_options="$*"

    # Use mvscmdauth if USE_AUTH is set, otherwise use mvscmd
    if [ "${USE_AUTH:-0}" -eq 1 ]; then
        _cmd="mvscmdauth --pgm=$(to_lowercase "$_pgm")"
    else
        _cmd="mvscmd --pgm=$(to_lowercase "$_pgm")"
    fi

    # Add PARM if present
    if [ -n "$_parm" ]; then
        # Remove quotes if present
        _parm_clean=$(echo "$_parm" | sed "s/'//g")
        _cmd="$_cmd --args='$_parm_clean'"
    fi

    # Add DD options
    if [ -n "$_dd_options" ]; then
        _cmd="$_cmd $_dd_options"
    fi

    # Wrap with nohup and add shell redirection for stdout/stderr capture (JES-like messages)
    # Note: Redirection must come before & for background processes
    _stepname_lower=$(to_lowercase "$_stepname")
    _cmd="nohup $_cmd >> \$LOG_DIR/${_jobname}_${_stepname_lower}_stdout.log 2>> \$LOG_DIR/${_jobname}_${_stepname_lower}_stderr.log &"

    echo "$_cmd"
}

#
# Script generation functions
#

# Generate script header
# Usage: generate_script_header "$jobname" "$jcl_file"
generate_script_header() {
    _jobname="$1"
    _jcl_file="$2"
    _timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat << EOF
#!/bin/bash
#
# Generated from: $_jcl_file
# Job name: $_jobname
# Generated on: $_timestamp
#

# Exit on error
set -e

# Log directory (absolute path)
LOG_DIR="\${LOG_DIR:-\$(pwd)/logs}"
mkdir -p "\$LOG_DIR"

# Inline data directory (absolute path)
SYSIN_DIR="\${SYSIN_DIR:-\$(pwd)/sysin}"
mkdir -p "\$SYSIN_DIR"

# Function to log messages
log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1"
}

# Function to check return code
check_rc() {
    RC=\$?
    STEP="\$1"
    if [ \$RC -ne 0 ]; then
        log "ERROR: Step \$STEP failed with RC=\$RC"
        exit \$RC
    fi
    log "Step \$STEP completed successfully (RC=\$RC)"
}

log "Starting job: $_jobname"
EOF
}

# Generate script footer
# Usage: generate_script_footer "$jobname"
generate_script_footer() {
    _jobname="$1"

    cat << EOF

log "Job $_jobname completed successfully"
exit 0
EOF
}

# Generate parameter section for JCL symbols
# Usage: generate_parameter_section "$symbols"
generate_parameter_section() {
    _symbols="$1"

    if [ -z "$_symbols" ]; then
        return
    fi

    echo ""
    echo "# JCL Symbols (command-line parameters)"

    _index=1
    echo "$_symbols" | while IFS='=' read -r _sym _val; do
        if [ -n "$_sym" ]; then
            echo "${_sym}=\"\${${_index}:-${_val}}\""
            _index=$((_index + 1))
        fi
    done
}

# Generate step execution block
# Usage: generate_step_block "$stepname" "$mvscmd_command" "$log_files" "$sysin_content"
generate_step_block() {
    _stepname="$1"
    _mvscmd_cmd="$2"
    _log_files="$3"
    _sysin_content="$4"

    cat << EOF

# Job Step: $_stepname
log "Executing step: $_stepname"
EOF

    # Create log files before executing mvscmd
    if [ -n "$_log_files" ]; then
        echo "$_log_files" | while IFS= read -r _logfile; do
            if [ -n "$_logfile" ]; then
                echo "touch \"$_logfile\""
            fi
        done
    fi

    # If SYSIN content exists, pipe it to mvscmd
    if [ -n "$_sysin_content" ]; then
        echo "cat << 'SYSIN_DATA_EOF' | $_mvscmd_cmd"
        echo "$_sysin_content"
        echo "SYSIN_DATA_EOF"
    else
        # No SYSIN, just run the command
        echo "$_mvscmd_cmd"
    fi

    cat << 'EOF'
STEP_PID=$!
log "Step running in background (PID: $STEP_PID)"
log "Monitor with: ps -p $STEP_PID"
log "Stop with: kill $STEP_PID"
EOF
}

# Generate inline data file creation
# Usage: generate_inline_data_file "$jobname" "$stepname" "$ddname" "$content"
generate_inline_data_file() {
    _jobname="$1"
    _stepname="$2"
    _ddname="$3"
    _content="$4"

    _stepname_lower=$(to_lowercase "$_stepname")
    _ddname_lower=$(to_lowercase "$_ddname")
    _filename="${_jobname}_${_stepname_lower}_${_ddname_lower}.txt"

    cat << EOF

# Create inline data file for $_stepname/$_ddname
cat > "\$SYSIN_DIR/$_filename" << 'INLINE_DATA_EOF'
$_content
INLINE_DATA_EOF
EOF
}

#
# High-level generation function
#

# Generate complete shell script from JCL
# Usage: generate_script "$jcl_file" "$job_data" "$symbols" "$steps"
generate_script() {
    _jcl_file="$1"
    _jobname="$2"
    _symbols="$3"
    _steps="$4"

    # Generate header
    generate_script_header "$_jobname" "$_jcl_file"

    # Generate parameter section
    generate_parameter_section "$_symbols"

    # Generate step blocks
    echo "$_steps" | while read -r _step; do
        if [ -n "$_step" ]; then
            # Parse step data and generate block
            # This will be implemented in the main tool
            echo "# Step: $_step"
        fi
    done

    # Generate footer
    generate_script_footer "$_jobname"
}
