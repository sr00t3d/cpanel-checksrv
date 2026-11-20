# cPanel CheckSrv (`cp-checksrv.sh`)

![cPanel CheckSrv Cover](./cp-checksrv-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](./cp-checksrv.sh)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel%20%2F%20WHM%20%7C%20chkservd-orange.svg)](#requirements)

> 🇧🇷 **[Leia em Português (README-ptbr.md)](./README-ptbr.md)**

**cPanel CheckSrv** (`cp-checksrv.sh` v2.0.0) is a high-speed Bash + Python3 (stdlib-only) CLI parser for cPanel/WHM `/var/log/chkservd.log`. Designed for production hosting servers where `chkservd.log` routinely grows past 100 MB, it uses **reverse-seek chunked reading** (256 KB blocks from EOF) so auditing the latest service check cycles completes in milliseconds without loading the entire file into RAM.

---

## Features

- **Reverse-Seek Chunked Reader:** Reads from the end of `/var/log/chkservd.log` backwards in 256 KB chunks, analyzing the latest `N` cycles on 100 MB+ logs in milliseconds.
- **Per-Service Uptime Summary (`-S, --summary`):** Aggregates `CHECKS`, `OK`, `FAILED`, `UPTIME%`, and last `check command` / `socket connect` state per service across the audited window.
- **Failure-First & Functional Modes:** Displays only failed services by default, or every monitored daemon (`httpd`, `mysql`, `exim`, `named`, `imap`, `cpsrvd`, `lfd`, `sshd`, etc.) with `-f, --functional`.
- **Service Filter & Custom Log Path:** Isolate a single service with `-s <name>` or audit archived/rotated logs with `-l <path>`.
- **Structured Outputs:** Export reports in aligned `table` (default), `json`, or `csv` format for `cron`, Zabbix, or incident automation.
- **Semantic Exit Codes:** Returns `0` when all audited checks are healthy, `1` on usage/file errors, and `2` when one or more failures are detected (ready for `cp-checksrv.sh -q 1 || mail ...`).

---

## Requirements

- Linux with Bash 4.0+ and Python 3.6+ (standard library only, zero external packages)
- Read access to `/var/log/chkservd.log` (usually `root` or `sudo`)

---

## Installation

```bash
git clone https://github.com/sr00t3d/cpanel-checksrv.git
cd cpanel-checksrv
chmod +x cp-checksrv.sh
```

---

## Usage

```bash
# Default: show failures in the last 5 chkservd check cycles
sudo ./cp-checksrv.sh

# Show per-service uptime summary across the last 20 cycles
sudo ./cp-checksrv.sh -S -q 20

# Full status (OK + FAILED) for the latest 2 cycles
sudo ./cp-checksrv.sh -f -q 2

# Filter history for a specific service (e.g. exim)
sudo ./cp-checksrv.sh -s exim -f -q 10

# Export per-service summary as JSON
sudo ./cp-checksrv.sh -S -q 50 -o json > chkservd-summary.json

# Cron alert on any failure in the latest check cycle
*/5 * * * * /usr/local/bin/cp-checksrv.sh -q 1 --no-color >/dev/null || echo "chkservd failure on $(hostname)" | mail -s "Alert chkservd" ops@example.com
```

### CLI Options

| Flag | Description |
| :--- | :--- |
| `-q, --quantity <N>` | Number of most recent check cycles to analyze (default: `5`) |
| `-f, --functional` | Include healthy (`OK`) services, not only failures |
| `-a, --all` | Scan up to `--max-lines` recent lines (default: `5000`) |
| `--max-lines <N>` | Maximum trailing lines to read in `--all` mode (default: `5000`) |
| `-S, --summary` | Show per-service uptime and failure summary table |
| `-s, --service <name>` | Filter output to a specific service name |
| `-l, --log <path>` | Custom path to `chkservd.log` (default: `/var/log/chkservd.log`) |
| `-o, --output <fmt>` | Output format: `table` (default), `json`, `csv` |
| `--no-color` | Disable ANSI colors |
| `-V, --version` | Show version and exit |
| `-h, --help` | Show help message and exit |

---

## Real Output Example

Captured on an AlmaLinux 8.10 / cPanel test container running `cp-checksrv.sh -S -q 4 --no-color` over 4 check cycles (32 total service checks, 3 transient failures on `exim` and `mysql`):

```text
================================================================================================================
 CPANEL CHECKSRV v2.0.0 - [cpanel-test.local] | Log: /tmp/chkservd-test.log (0.0 MB) | chkservd: NOT_RUNNING
================================================================================================================
SERVICE                | CHECKS |     OK | FAILED |  UPTIME | LAST     | LAST CHECK / SOCKET
----------------------------------------------------------------------------------------------------------------
cpsrvd                 |      4 |      4 |      0 |  100.0% | OK       | cmd:N/A sock:+
exim                   |      4 |      2 |      2 |   50.0% | OK       | cmd:+ sock:+
httpd                  |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
imap                   |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
lfd                    |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:N/A
mysql                  |      4 |      3 |      1 |   75.0% | OK       | cmd:+ sock:+
named                  |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
sshd                   |      4 |      4 |      0 |  100.0% | OK       | cmd:+ sock:+
================================================================================================================
 Summary: 4 cycle(s) | 8 service(s) | Total checks: 32 | Failures: 3
================================================================================================================
```

---

## License

Licensed under the [Apache-2.0 License](./LICENSE). Inspired by the original Perl `checksrv` utility by Matthew Harris (HostGator, 2013).
