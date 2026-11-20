#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   cPanel CheckSrv (cp-checksrv.sh) v2.0.0                                 ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: percio@evolya.com.br | contato@perciocastelo.com.br            ║
# ║   Web:     https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  High-speed parser for cPanel/WHM /var/log/chkservd.log using   ║
# ║            reverse-seek chunked reading (handles 100MB+ logs in ms),      ║
# ║            per-service uptime summaries, and table/JSON/CSV outputs.      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -uo pipefail
export LC_ALL=C

readonly VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

# =============================================================================
# Defaults
# =============================================================================
LOG_FILE="/var/log/chkservd.log"
LIMIT=5
SHOW_ALL=false
SHOW_FUNCTIONAL=false
SUMMARY_MODE=false
SERVICE_FILTER=""
MAX_LINES=5000
OUTPUT_FORMAT="table"    # table | json | csv
NO_COLOR=false

# =============================================================================
# Colors
# =============================================================================
C_RESET=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_CYAN=""
C_DIM=""

init_colors() {
    if [[ "$NO_COLOR" == false && "$OUTPUT_FORMAT" == "table" && -t 1 ]]; then
        C_RESET=$'\033[0m'
        C_DIM=$'\033[2m'
        C_RED=$'\033[0;31m'
        C_GREEN=$'\033[0;32m'
        C_YELLOW=$'\033[0;33m'
        C_CYAN=$'\033[0;36m'
    fi
}

log_err() {
    echo -e "${C_RED}[x] Error:${C_RESET} $*" >&2
}

# =============================================================================
# Help
# =============================================================================
show_help() {
    cat <<EOF
cPanel CheckSrv (cp-checksrv.sh) v${VERSION}
High-speed reverse-seek parser for cPanel/WHM chkservd service logs (100MB+ ready).

Usage:
  ${SCRIPT_NAME} [OPTIONS]

Options:
  -q, --quantity <N>       Number of most recent check cycles to analyze (default: 5)
  -f, --functional         Include healthy (OK) services, not only failures
  -a, --all                Scan up to --max-lines recent lines (default: 5000)
      --max-lines <N>      Maximum trailing lines to read in --all mode (default: 5000)
  -S, --summary            Show per-service uptime & failure summary table
  -s, --service <name>     Filter results to a specific service (e.g. httpd, mysql, exim)
  -l, --log <path>         Path to chkservd.log (default: /var/log/chkservd.log)
  -o, --output <fmt>       Output format: table (default), json, csv
      --no-color           Disable ANSI colors
  -V, --version            Show version and exit
  -h, --help               Show this help message and exit

Exit Codes:
  0  All audited service checks passed cleanly
  1  Usage or runtime error (e.g. log file not found)
  2  One or more service failures detected in the audited window

Examples:
  ${SCRIPT_NAME}                        # Failures in the last 5 check cycles
  ${SCRIPT_NAME} -f -q 2                # Full status (OK + FAIL) for last 2 cycles
  ${SCRIPT_NAME} -S -q 50               # Per-service uptime summary over last 50 cycles
  ${SCRIPT_NAME} -s exim -f -q 10       # Last 10 checks for exim only
  ${SCRIPT_NAME} -q 1 || mail -s "chkservd FAIL" ops@example.com
  ${SCRIPT_NAME} -S -q 20 -o json > chkservd-summary.json
EOF
}

# =============================================================================
# Argument Parser
# =============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)          SHOW_ALL=true; shift ;;
            -f|--functional)   SHOW_FUNCTIONAL=true; shift ;;
            -S|--summary)      SUMMARY_MODE=true; shift ;;
            -q|--quantity)
                [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -lt 1 ]] && { log_err "$1 requires a positive integer"; exit 1; }
                LIMIT="$2"; shift 2 ;;
            --max-lines)
                [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -lt 1 ]] && { log_err "$1 requires a positive integer"; exit 1; }
                MAX_LINES="$2"; shift 2 ;;
            -s|--service)
                [[ $# -lt 2 ]] && { log_err "$1 requires a service name"; exit 1; }
                SERVICE_FILTER="$2"; shift 2 ;;
            -l|--log)
                [[ $# -lt 2 ]] && { log_err "$1 requires a file path"; exit 1; }
                LOG_FILE="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && { log_err "$1 requires a format (table|json|csv)"; exit 1; }
                OUTPUT_FORMAT="$2"; shift 2 ;;
            --no-color)        NO_COLOR=true; shift ;;
            -V|--version)      echo "cPanel CheckSrv v${VERSION}"; exit 0 ;;
            -h|--help)         show_help; exit 0 ;;
            *)                 log_err "Unknown option: $1 (use --help)"; exit 1 ;;
        esac
    done

    case "$OUTPUT_FORMAT" in
        table|json|csv) ;;
        *) log_err "--output must be table, json, or csv"; exit 1 ;;
    esac

    if [[ ! -f "$LOG_FILE" ]]; then
        log_err "Log file not found: ${LOG_FILE}"
        exit 1
    fi
    if [[ ! -r "$LOG_FILE" ]]; then
        log_err "Log file is not readable: ${LOG_FILE} (try running with sudo)"
        exit 1
    fi
}

# =============================================================================
# Daemon Status Helper
# =============================================================================
get_daemon_status() {
    if [[ -f /var/run/chkservd.pid ]]; then
        local pid
        pid=$(cat /var/run/chkservd.pid 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$pid" && -d "/proc/${pid}" ]]; then
            local up
            up=$(ps -o etime= -p "$pid" 2>/dev/null | xargs || echo "?")
            echo "RUNNING (PID ${pid}, up ${up})"
            return
        fi
    fi
    if pgrep -x chkservd >/dev/null 2>&1; then
        local pid
        pid=$(pgrep -x chkservd | head -n 1)
        echo "RUNNING (PID ${pid})"
    else
        echo "NOT_RUNNING"
    fi
}

# =============================================================================
# High-Speed Reverse-Seek Parser (Python3 stdlib, 3.6+ compatible)
# =============================================================================
run_parser() {
    local host daemon_status
    host=$(hostname 2>/dev/null || echo "unknown")
    daemon_status=$(get_daemon_status)

    if ! command -v python3 >/dev/null 2>&1; then
        log_err "python3 is required for high-speed chkservd log parsing."
        exit 1
    fi

    python3 - "$VERSION" "$host" "$LOG_FILE" "$LIMIT" "$SHOW_ALL" "$SHOW_FUNCTIONAL" \
        "$SUMMARY_MODE" "$SERVICE_FILTER" "$MAX_LINES" "$OUTPUT_FORMAT" "$daemon_status" \
        "$C_RESET" "$C_GREEN" "$C_YELLOW" "$C_RED" "$C_CYAN" <<'PYEOF'
import csv
import datetime
import io
import json
import os
import re
import sys

(version, host, log_file, limit_s, show_all_s, show_func_s, summary_s,
 svc_filter, max_lines_s, fmt, daemon_status,
 c_rst, c_grn, c_yel, c_red, c_cyn) = sys.argv[1:17]

limit = int(limit_s)
max_lines = int(max_lines_s)
show_all = show_all_s == "true"
show_func = show_func_s == "true"
summary_mode = summary_s == "true"
svc_filter_l = svc_filter.strip().lower()

file_size = os.path.getsize(log_file)
size_mb = round(file_size / (1024.0 * 1024.0), 2)

def tail_lines_fast(path, target_cycles, all_mode, max_l):
    """Reverse-seek chunked reader: avoids loading 100MB+ logs into memory."""
    chunk_size = 262144  # 256 KB
    collected = bytearray()
    line_count = 0
    cycle_count = 0
    with open(path, "rb") as fh:
        fh.seek(0, os.SEEK_END)
        pos = fh.tell()
        while pos > 0:
            read_sz = min(chunk_size, pos)
            pos -= read_sz
            fh.seek(pos)
            chunk = fh.read(read_sz)
            collected[:0] = chunk
            line_count += chunk.count(b"\n")
            cycle_count += chunk.count(b"Service check")
            if all_mode:
                if line_count >= max_l:
                    break
            else:
                if cycle_count >= target_cycles + 2:
                    break
    text = collected.decode("utf-8", errors="replace")
    lines = text.splitlines()
    if all_mode and len(lines) > max_l:
        lines = lines[-max_l:]
    return lines

raw_lines = tail_lines_fast(log_file, limit, show_all, max_lines)

# Merge multiline service check blocks into discrete cycles
TS_RE = re.compile(r"\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+[+-]\d{4})\]")
SVC_RE = re.compile(r"([A-Za-z0-9_.:/-]+)\s*\[\[(.*?)\]\]")
CHECK_RE = re.compile(r"check command:([^\]\[]+)", re.I)
SOCK_RE = re.compile(r"socket connect:([^\]\[]+)", re.I)

cycles = []
buf = None
cur_ts = ""

for ln in raw_lines:
    if "Service check" in ln and "Service Check Finished" not in ln:
        # Flush any unclosed previous cycle
        if buf is not None:
            cycles.append((cur_ts, buf))
        m_ts = TS_RE.search(ln)
        cur_ts = m_ts.group(1) if m_ts else "unknown"
        buf = ln
        if "Service Check Finished" in ln or ln.rstrip().endswith("...Done"):
            cycles.append((cur_ts, buf))
            buf = None
    elif buf is not None:
        buf += " " + ln.strip()
        if "Service Check Finished" in ln or ln.rstrip().endswith("...Done"):
            cycles.append((cur_ts, buf))
            buf = None
    elif "Service check" in ln:
        m_ts = TS_RE.search(ln)
        cycles.append((m_ts.group(1) if m_ts else "unknown", ln))

if buf is not None:
    cycles.append((cur_ts, buf))

if not show_all and len(cycles) > limit:
    cycles = cycles[-limit:]

parsed_cycles = []
svc_stats = {}
total_failures = 0
total_checks = 0

for ts, block in cycles:
    services = []
    for m in SVC_RE.finditer(block):
        name = m.group(1).strip(".")
        if not name or name.lower() in ("loading", "done"):
            continue
        if svc_filter_l and svc_filter_l not in name.lower():
            continue
        inner = m.group(2)
        m_chk = CHECK_RE.search(inner)
        m_sck = SOCK_RE.search(inner)
        chk_val = m_chk.group(1).strip() if m_chk else "N/A"
        sck_val = m_sck.group(1).strip() if m_sck else "N/A"
        failed = (":-" in inner) or (chk_val == "-") or (sck_val == "-")
        status = "FAILED" if failed else "OK"

        total_checks += 1
        if failed:
            total_failures += 1

        services.append({
            "service": name,
            "check_command": chk_val,
            "socket_connect": sck_val,
            "status": status,
        })

        st = svc_stats.setdefault(name, {
            "service": name,
            "checks": 0,
            "ok": 0,
            "failed": 0,
            "last_status": status,
            "last_seen": ts,
            "last_check": chk_val,
            "last_socket": sck_val,
        })
        st["checks"] += 1
        if failed:
            st["failed"] += 1
        else:
            st["ok"] += 1
        st["last_status"] = status
        st["last_seen"] = ts
        st["last_check"] = chk_val
        st["last_socket"] = sck_val

    if services:
        fail_cnt = sum(1 for s in services if s["status"] == "FAILED")
        parsed_cycles.append({
            "timestamp": ts,
            "total": len(services),
            "ok": len(services) - fail_cnt,
            "failed": fail_cnt,
            "services": services,
        })

summary_rows = []
for name in sorted(svc_stats.keys()):
    st = svc_stats[name]
    uptime = round((st["ok"] / float(st["checks"])) * 100.0, 1) if st["checks"] else 0.0
    st["uptime_pct"] = uptime
    summary_rows.append(st)

if fmt == "json":
    payload = {
        "version": version,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "hostname": host,
        "log_file": log_file,
        "log_size_mb": size_mb,
        "daemon": daemon_status,
        "cycles_analyzed": len(parsed_cycles),
        "total_service_checks": total_checks,
        "total_failures": total_failures,
        "summary": summary_rows,
        "cycles": parsed_cycles if not summary_mode else [],
    }
    print(json.dumps(payload, indent=2))
elif fmt == "csv":
    buf_io = io.StringIO()
    w = csv.writer(buf_io)
    if summary_mode:
        w.writerow(["service", "checks", "ok", "failed", "uptime_pct", "last_status", "last_check", "last_socket", "last_seen"])
        for r in summary_rows:
            w.writerow([r["service"], r["checks"], r["ok"], r["failed"], r["uptime_pct"],
                        r["last_status"], r["last_check"], r["last_socket"], r["last_seen"]])
    else:
        w.writerow(["timestamp", "service", "status", "check_command", "socket_connect"])
        for cyc in parsed_cycles:
            for s in cyc["services"]:
                if not show_func and s["status"] != "FAILED":
                    continue
                w.writerow([cyc["timestamp"], s["service"], s["status"], s["check_command"], s["socket_connect"]])
    sys.stdout.write(buf_io.getvalue())
else:
    bar = "=" * 112
    sep = "-" * 112
    print(bar)
    print(f" CPANEL CHECKSRV v{version} - [{host}] | Log: {log_file} ({size_mb} MB) | chkservd: {daemon_status}")
    print(bar)

    if not parsed_cycles:
        print(" No chkservd service check cycles found in the scanned window.")
        print(bar)
        sys.exit(0)

    if summary_mode:
        print(f"{'SERVICE':<22} | {'CHECKS':>6} | {'OK':>6} | {'FAILED':>6} | {'UPTIME':>7} | {'LAST':<8} | {'LAST CHECK / SOCKET'}")
        print(sep)
        for r in summary_rows:
            col = c_red if r["failed"] > 0 else c_grn
            detail = f"cmd:{r['last_check']} sock:{r['last_socket']}"
            print(f"{r['service'][:22]:<22} | {r['checks']:>6} | {r['ok']:>6} | {r['failed']:>6} | {r['uptime_pct']:>6.1f}% | {col}{r['last_status']:<8}{c_rst} | {detail}")
        print(bar)
        print(f" Summary: {len(parsed_cycles)} cycle(s) | {len(summary_rows)} service(s) | Total checks: {total_checks} | Failures: {total_failures}")
        print(bar)
    else:
        print(f"{'TIMESTAMP':<26} | {'SERVICE':<20} | {'CHECK CMD':<12} | {'SOCKET':<12} | {'STATUS'}")
        print(sep)
        printed = 0
        for cyc in parsed_cycles:
            for s in cyc["services"]:
                if not show_func and s["status"] != "FAILED":
                    continue
                col = c_red if s["status"] == "FAILED" else c_grn
                print(f"{cyc['timestamp'][:26]:<26} | {s['service'][:20]:<20} | {s['check_command'][:12]:<12} | {s['socket_connect'][:12]:<12} | {col}{s['status']}{c_rst}")
                printed += 1
        if printed == 0:
            print(f" {c_grn}All {total_checks} service check(s) across the last {len(parsed_cycles)} cycle(s) passed cleanly (0 failures).{c_rst}")
        print(bar)
        print(f" Summary: {len(parsed_cycles)} cycle(s) | Total checks: {total_checks} | OK: {total_checks - total_failures} | FAILED: {total_failures}")
        print(bar)

sys.exit(2 if total_failures > 0 else 0)
PYEOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    parse_args "$@"
    init_colors
    run_parser
}

main "$@"
