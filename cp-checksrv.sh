#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   CheckServer v1.0.0                                                      ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Author:   Percio Castelo                                                ║
# ║   Contact:  percio@evolya.com.br | contato@perciocastelo.com.br           ║
# ║   Web:      https://perciocastelo.com.br                                  ║
# ║                                                                           ║
# ║   Function: Advanced audit script to parse cPanel/WHM `chkservd` logs     ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

LOG_FILE="/var/log/chkservd.log"
LIMIT=5
SHOW_ALL=0
SHOW_FUNCTIONAL=0
MAX_LINES=5000

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

err_exit() {
    echo -e "${RED}$1${NC}" >&2
    exit 1
}

header() {
    echo "--------------------------------------"
    echo -e "\tChksrvd Log Parser v2.0 (Bash)"
    echo "--------------------------------------"
    echo ""
}

show_help() {
    cat << 'EOF'

   cp-checksrv.sh [OPTIONS]

   Tool to analyze /var/log/chkservd.log services status.

     Options:
        -a, --all        Display all service checks (limit: last 5000 lines)
        -f, --functional Show functional services too (with details)
        -q, --quantity   Sets the number of checks to go back (default: 5)
        -h, --help       Show this page

EOF
}

check_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        err_exit "Error: File $LOG_FILE not found"
    fi
}

# Processes a complete service check line
process_service_line() {
    local line="$1"
    local time=""
    local services=()
    local failed=()
    local ok=()
    
    # Extract timestamp
    if [[ "$line" =~ \[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ -[0-9]{4})\] ]]; then
        time="${BASH_REMATCH[1]}"
    fi
    
    # Remove prefixes and suffixes
    line=$(echo "$line" | sed 's/.*Service check \.\.\.//; s/\.\.\.Service Check Finished//; s/\.\.\.Done$//')
    
    # Split services by delimiter ...
    local IFS_backup="$IFS"
    IFS='...' read -ra parts <<< "$line"
    IFS="$IFS_backup"
    
    for part in "${parts[@]}"; do
        # Trim spaces
        part=$(echo "$part" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$part" ]] && continue
        [[ "$part" == "Done" ]] && continue
        [[ "$part" == *"Loading services"* ]] && continue
        
        # Extract service name (everything before [[)
        local name=$(echo "$part" | sed 's/\[\[.*//; s/[[:space:]]*$//')
        [[ -z "$name" ]] && continue
        
        # Check if it has [[...]]
        if [[ "$part" =~ \[\[(.*)\]\] ]]; then
            local inner="${BASH_REMATCH[1]}"
            local check="N/A"
            local socket="N/A"
            local has_fail=0
            
            # Extract values
            [[ "$inner" =~ check\ command:([^\]]+) ]] && check="${BASH_REMATCH[1]}"
            [[ "$inner" =~ socket\ connect:([^\]]+) ]] && socket="${BASH_REMATCH[1]}"
            
            # Check for failure (:-)
            if [[ "$inner" == *":-"* ]]; then
                has_fail=1
                failed+=("$name")
            else
                ok+=("$name")
            fi
            
            # If functional mode, store details
            if [[ $SHOW_FUNCTIONAL -eq 1 ]]; then
                if [[ $has_fail -eq 1 ]]; then
                    services+=("${RED}[!]${NC} $name [check:$check] [socket:$socket] ${RED}FAILED${NC}")
                else
                    services+=("${GREEN}[✓]${NC} $name [check:$check] [socket:$socket] ${GREEN}OK${NC}")
                fi
            fi
        fi
    done
    
    # Print result
    local total=$(( ${#failed[@]} + ${#ok[@]} ))
    [[ $total -eq 0 ]] && return 1
    
    if [[ $SHOW_FUNCTIONAL -eq 1 ]]; then
        echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}[$time]${NC} Service Check (${total} services)"
        echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
        for svc in "${services[@]}"; do
            echo -e "\t$svc"
        done
        echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
        if [[ ${#failed[@]} -gt 0 ]]; then
            echo -e "\t${RED}Summary: ${#failed[@]} FAILURE(S), ${#ok[@]} OK${NC}"
        else
            echo -e "\t${GREEN}Summary: All ${total} services OK${NC}"
        fi
    else
        # Failures only mode
        if [[ ${#failed[@]} -gt 0 ]]; then
            echo -e "\n${YELLOW}[$time]${NC}"
            for f in "${failed[@]}"; do
                echo -e "\t${RED}[!] $f failed${NC}"
            done
        fi
    fi
    
    return 0
}

# Finds last N complete service checks (multiline)
find_last_checks() {
    local n="$1"
    local count=0
    local buffer=""
    local in_check=0
    
    # Read from bottom to top using tac, but process in blocks
    tac "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
        
        # Detect end of service check
        if [[ "$line" == *"Service Check Finished"* ]] || [[ "$line" == *"...Done"* ]]; then
            in_check=1
            buffer="$line"
            continue
        fi
        
        # Accumulate check lines
        if [[ $in_check -eq 1 ]]; then
            buffer="$line"$'\n'"$buffer"
            
            # Detect start of check
            if [[ "$line" == *"Service check"* ]]; then
                # Print in correct order (reverse buffer)
                echo "$buffer" | tac
                echo "---ENDCHECK---"
                ((count++))
                [[ $count -ge $n ]] && break
                in_check=0
                buffer=""
            fi
        fi
    done
}

# Fast parse for failures only (last N)
parse_last_failures_fast() {
    echo -e "${BLUE}Analyzing last $LIMIT checks...${NC}"
    
    local checks_found=0
    local current_time=""
    local current_fails=()
    
    # Use awk to process efficiently
    awk -v limit="$LIMIT" -v red="$RED" -v yellow="$YELLOW" -v nc="$NC" '
    /Service check \.\.\./ {
        if (count >= limit) exit
        
        # Extract timestamp from current or previous line
        if (match($0, /\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} -[0-9]{4}\]/)) {
            time = substr($0, RSTART, RLENGTH)
        }
        
        # Check if there is failure in this line
        if (/:/) {
            count++
            has_fail = 0
            fails = ""
            
            # Split by ... and check each service
            n = split($0, parts, /\.\.\./)
            for (i=1; i<=n; i++) {
                if (parts[i] ~ /:-/) {
                    # Extract name
                    match(parts[i], /^[[:space:]]*([^[]+)/)
                    name = substr(parts[i], RSTART, RLENGTH)
                    gsub(/[[:space:]]$/, "", name)
                    fails = fails "\n\t" red "[!]" nc " " name " failed"
                    has_fail = 1
                }
            }
            
            if (has_fail) {
                print yellow time nc fails
            }
        }
    }
    ' "$LOG_FILE" | tail -n "$((LIMIT * 20))"
}

# Full functional parse (last N)
parse_last_functional() {
    echo -e "${BLUE}Analyzing last $LIMIT complete checks...${NC}"
    
    # Get last N occurrences of "Service check" with context
    grep -n "Service check" "$LOG_FILE" | tail -n "$LIMIT" | cut -d: -f1 | \
    while read -r start_line; do
        # Get the full line (may be very long and broken)
        local line=$(sed -n "${start_line}p" "$LOG_FILE" 2>/dev/null)
        
        # If the line does not contain "Done", get more lines until complete
        if [[ "$line" != *"Done"* ]]; then
            local next_lines=$(sed -n "$((start_line+1)),$((start_line+50))p" "$LOG_FILE" 2>/dev/null | tr '\n' ' ')
            line="$line $next_lines"
            # Cut at first Done
            line=$(echo "$line" | sed 's/Done.*$/Done/')
        fi
        
        process_service_line "$line"
    done
}

# Parse all (limited)
parse_all() {
    echo -e "${YELLOW}Analyzing last $MAX_LINES lines of the log...${NC}"
    
    tail -n "$MAX_LINES" "$LOG_FILE" | grep "Service check" | \
    while read -r line; do
        process_service_line "$line"
    done
}

show_system_info() {
    echo -e "${CYAN}=== System Information ===${NC}"
    
    # PID
    if [[ -f /var/run/chkservd.pid ]]; then
        local pid=$(cat /var/run/chkservd.pid 2>/dev/null)
        if [[ -n "$pid" && -d /proc/$pid ]]; then
            local uptime=$(ps -o etime= -p $pid 2>/dev/null | xargs)
            echo -e "chkservd: ${GREEN}RUNNING${NC} (PID: $pid, Uptime: $uptime)"
        else
            echo -e "chkservd: ${RED}NOT RUNNING${NC}"
        fi
    fi
    
    # Statistics
    local size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null)
    echo -e "Log: ${YELLOW}$((size / 1024 / 1024)) MB${NC} | Checks: $(grep -c "Service check" "$LOG_FILE" 2>/dev/null || echo "?")"
    
    # Recent failures (fast)
    local fails=$(tail -n 2000 "$LOG_FILE" | grep -c "Service check.*:\-" 2>/dev/null || echo "0")
    echo -e "Failures in the last 2000 lines: ${RED}$fails${NC}"
    echo ""
}

# Arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all) SHOW_ALL=1; shift ;;
        -f|--functional) SHOW_FUNCTIONAL=1; shift ;;
        -q|--quantity) 
            [[ -n "$2" && "$2" =~ ^[0-9]+$ ]] && LIMIT="$2" && shift 2 || err_exit "-q requires a number" ;;
        -h|--help) show_help; exit 0 ;;
        *) err_exit "Unknown option: $1" ;;
    esac
done

# Execution
check_log
header

[[ $SHOW_FUNCTIONAL -eq 1 ]] && show_system_info

if [[ $SHOW_ALL -eq 1 ]]; then
    parse_all
elif [[ $SHOW_FUNCTIONAL -eq 1 ]]; then
    parse_last_functional
else
    parse_last_failures_fast
fi