#!/bin/sh
#
# LOGR Structure Manager for z/OS
# Manages LOGR structures and log streams using IXCMIAPU
#

# Set temporary directory
TMPDIR="${TMPDIR:-/tmp}"

# Function to show a spinner while a command runs
show_spinner() {
    PID=$1
    while kill -0 $PID 2>/dev/null; do
        printf "\r| Processing..."
        sleep 1
        if ! kill -0 $PID 2>/dev/null; then break; fi
        printf "\r/ Processing..."
        sleep 1
        if ! kill -0 $PID 2>/dev/null; then break; fi
        printf "\r- Processing..."
        sleep 1
        if ! kill -0 $PID 2>/dev/null; then break; fi
        printf "\r\\ Processing..."
        sleep 1
    done
    printf "\r                    \r"
}

# Function to display usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list [pattern]           - List LOGR structures (default: LOG_*_A*)"
    echo "  delete <logstream>       - Delete log stream(s) by name or pattern"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 list 'LOG_PROD_*'"
    echo "  $0 delete IYCWEED1.DFHLOG"
    echo "  $0 delete 'IYCWEED1.*'"
    echo "  $0 delete 'IYCW*'"
    exit 1
}

# Function to execute IXCMIAPU command with spinner
execute_ixcmiapu() {
    SYSIN_FILE="$1"
    OUTPUT_FILE="$2"
    MESSAGE="$3"

    if [ -n "$MESSAGE" ]; then
        printf "$MESSAGE"
    fi

    mvscmdauth --pgm=IXCMIAPU --sysin="$SYSIN_FILE" --sysprint="$OUTPUT_FILE" > /dev/null 2>&1 &
    CMDPID=$!
    show_spinner $CMDPID
    wait $CMDPID

    if [ -n "$MESSAGE" ]; then
        printf "\r                                    \r"
    fi

    return $?
}

# Function to parse log streams from IXCMIAPU output
parse_logstreams() {
    OUTFILE="$1"
    PATTERN="$2"

    IN_LOGSTREAM_LIST=0
    RESULT=""

    while IFS= read -r line; do
        if echo "$line" | grep -q "LOGSTREAM NAME.*CONNECTION"; then
            IN_LOGSTREAM_LIST=1
            continue
        fi

        if echo "$line" | grep -q "LOGSTREAMS CURRENTLY DEFINED"; then
            IN_LOGSTREAM_LIST=0
            continue
        fi

        if [ $IN_LOGSTREAM_LIST -eq 1 ]; then
            STREAM=$(echo "$line" | awk '{print $1}' | grep -v "^$" | grep -v "^-" | grep -v "LOGSTREAM")
            if [ -n "$STREAM" ] && [ "$STREAM" != "CONNECTION" ]; then
                if [ -z "$PATTERN" ] || echo "$STREAM" | grep -qE "$PATTERN"; then
                    RESULT="$RESULT$STREAM
"
                fi
            fi
        fi
    done < "$OUTFILE"

    echo "$RESULT"
}

# Function to get list of log streams matching pattern
get_matching_logstreams() {
    PATTERN="$1"

    TEMPIN="$TMPDIR/logr_sysin_$$.txt"
    TEMPOUT="$TMPDIR/logr_output_$$.txt"

    cat > "$TEMPIN" << EOF
  DATA TYPE(LOGR) REPORT(NO)
  LIST STRUCTURE NAME(LOG_*) DETAIL(YES)
EOF

    execute_ixcmiapu "$TEMPIN" "$TEMPOUT" "Searching for matching log streams..."

    GREP_PATTERN=$(echo "$PATTERN" | sed 's/\*/\.\*/g')
    LOGSTREAMS=$(parse_logstreams "$TEMPOUT" "$GREP_PATTERN")

    rm -f "$TEMPIN" "$TEMPOUT"
    echo "$LOGSTREAMS"
}

# Function to list LOGR structures
list_structures() {
    PATTERN="${1:-LOG_*}"

    echo "Listing LOGR structures matching: $PATTERN"
    echo ""

    TEMPIN="$TMPDIR/logr_sysin_$$.txt"
    TEMPOUT="$TMPDIR/logr_output_$$.txt"

    cat > "$TEMPIN" << EOF
  DATA TYPE(LOGR) REPORT(NO)
  LIST STRUCTURE NAME($PATTERN) DETAIL(YES)
EOF

    execute_ixcmiapu "$TEMPIN" "$TEMPOUT"

    # Format output
    echo ""
    echo "=========================================="
    echo "LOGR STRUCTURES AND LOG STREAMS"
    echo "=========================================="
    printf "%-30s %-40s\n" "STRUCTURE NAME" "LOG STREAM NAME"
    echo "------------------------------------------"

    CURRENT_STRUCT=""
    IN_LOGSTREAM_LIST=0

    while IFS= read -r line; do
        if echo "$line" | grep -q "STRUCTURE NAME("; then
            CURRENT_STRUCT=$(echo "$line" | sed 's/.*STRUCTURE NAME(\([^)]*\)).*/\1/')
            IN_LOGSTREAM_LIST=0
        fi

        if echo "$line" | grep -q "LOGSTREAM NAME.*CONNECTION"; then
            IN_LOGSTREAM_LIST=1
            continue
        fi

        if echo "$line" | grep -q "LOGSTREAMS CURRENTLY DEFINED"; then
            IN_LOGSTREAM_LIST=0
            continue
        fi

        if [ $IN_LOGSTREAM_LIST -eq 1 ] && [ -n "$CURRENT_STRUCT" ]; then
            LOGSTREAM=$(echo "$line" | awk '{print $1}' | grep -v "^$" | grep -v "^-" | grep -v "^+" | grep -v "LOGSTREAM")
            if [ -n "$LOGSTREAM" ] && [ "$LOGSTREAM" != "CONNECTION" ]; then
                # Filter out IXCMIAPU administrative headers and formatting lines
                if ! echo "$LOGSTREAM" | grep -qE "^[0-9]+ADMINISTRATIVE$|^LOG_.*[0-9]+$"; then
                    printf "%-30s %-40s\n" "$CURRENT_STRUCT" "$LOGSTREAM"
                fi
            fi
        fi
    done < "$TEMPOUT"

    echo "=========================================="

    rm -f "$TEMPIN" "$TEMPOUT"
}

# Function to delete log streams
delete_logstream() {
    LOGSTREAM="$1"

    if [ -z "$LOGSTREAM" ]; then
        echo "Error: Log stream name required"
        usage
    fi

    # Check if wildcard is used
    if echo "$LOGSTREAM" | grep -q '\*'; then
        # Wildcard pattern - expand to explicit names
        echo "Wildcard detected in pattern: $LOGSTREAM"
        echo "Expanding to explicit log stream names..."
        echo ""

        LOGSTREAMS=$(get_matching_logstreams "$LOGSTREAM")

        if [ -z "$LOGSTREAMS" ]; then
            echo "No log streams found matching pattern: $LOGSTREAM"
            return 1
        fi

        STREAM_COUNT=$(echo "$LOGSTREAMS" | grep -c "^")
        echo "Found $STREAM_COUNT log stream(s) matching pattern:"
        echo "$LOGSTREAMS"
        echo ""

        # Confirm deletion
        echo "WARNING: This will delete $STREAM_COUNT log stream(s)!"
        printf "Continue? (yes/no): "
        read CONFIRM

        if [ "$CONFIRM" != "yes" ]; then
            echo "Deletion cancelled"
            return 0
        fi
    else
        # Single explicit log stream
        LOGSTREAMS="$LOGSTREAM"
        STREAM_COUNT=1
    fi

    # Build delete command
    TEMPIN="$TMPDIR/logr_sysin_$$.txt"
    TEMPOUT="$TMPDIR/logr_delout_$$.txt"

    echo "  DATA TYPE(LOGR) REPORT(NO)" > "$TEMPIN"
    echo "$LOGSTREAMS" | while IFS= read -r stream; do
        if [ -n "$stream" ]; then
            echo "  DELETE LOGSTREAM NAME($stream)" >> "$TEMPIN"
        fi
    done

    # Execute delete
    if [ $STREAM_COUNT -eq 1 ]; then
        printf "Deleting log stream: $LOGSTREAM..."
    else
        printf "Deleting $STREAM_COUNT log stream(s)..."
    fi
    echo ""

    execute_ixcmiapu "$TEMPIN" "$TEMPOUT"
    RC=$?

    echo ""
    if [ $RC -eq 0 ]; then
        [ $STREAM_COUNT -eq 1 ] && echo "Successfully deleted log stream: $LOGSTREAM" || echo "Successfully deleted $STREAM_COUNT log stream(s)"
    else
        [ $STREAM_COUNT -eq 1 ] && echo "Error deleting log stream: $LOGSTREAM (RC=$RC)" || echo "Error during deletion (RC=$RC)"
        grep "IXG.*E" "$TEMPOUT" 2>/dev/null
    fi

    rm -f "$TEMPIN" "$TEMPOUT"
    return $RC
}

# Main script logic
if [ $# -lt 1 ]; then
    usage
fi

COMMAND="$1"
shift

case "$COMMAND" in
    list)
        list_structures "$@"
        ;;
    delete)
        if [ $# -lt 1 ]; then
            echo "Error: Log stream name or pattern required"
            usage
        fi
        delete_logstream "$1"
        ;;
    *)
        echo "Error: Unknown command: $COMMAND"
        usage
        ;;
esac

exit $?
