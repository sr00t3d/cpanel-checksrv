# cPanel Check Server

Readme: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/cpanel-checksrv) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="cp-checksrv-cover.webp" />

> **Bash rewrite of the original Perl checksrv utility by Matthew Harris (HostGator) - Converted using Kimi**

A fast and efficient Bash script to parse cPanel/WHM `chkservd` logs, designed to handle large log files (100MB+) without performance issues.

## About

This project is a **Bash rewrite** of the original Perl script `checksrv` created by **Matthew Harris** at HostGator in 2013. The original script was designed to make `/var/log/chkservd.log` human-readable by parsing service check results from cPanel's monitoring daemon.

### Why a Bash Rewrite?

- **Performance**: The original Perl script struggled with large log files (100MB+)
- **Portability**: No Perl dependencies required
- **Speed**: Optimized for modern systems using native Unix tools (`grep`, `awk`, `sed`)
- **Colors**: Enhanced terminal output with color coding

## Original Reference

```perl
#!/usr/bin/perl
# $Date: 2013-02-15 $
# $Revision: 1.0 $
# $Source: /root/bin/checksrv $
# $Author: Matthew Harris $
# Make /var/log/chkservd.log pretty
# https://gatorwiki.hostgator.com/Admin/RootBin#checkserv 
# http://git.toolbox.hostgator.com/checkserv 
# Please submit all bug reports at projects.hostgator.com
# https://projects.hostbox.hostgator.com/projects/script-checkserv/issues/new
```

**Original Author**: Matthew Harris (HostGator)
**Original Date**: 2013-02-15
**Original Purpose**: Parse `/var/log/chkservd.log` for service monitoring

## Features


| Feature              | Description                              | Original | This Version |
| ---------------------- | ------------------------------------------ | ---------- | -------------- |
| Parse chkservd logs  | Read cPanel service monitor logs         | ✅       | ✅           |
| Show failed services | Display only services with errors        | ✅       | ✅           |
| Show all services    | Display functional services too          | ❌       | ✅ (`-f`)    |
| Color output         | Terminal colors for better readability   | ❌       | ✅           |
| Large file support   | Handle 100MB+ logs efficiently           | ❌       | ✅           |
| System info          | Show chkservd PID, uptime, log size      | ❌       | ✅           |
| Fast execution       | Optimized with`grep`/`tail` vs full read | ❌       | ✅           |
| Quantity limit       | Adjustable number of checks to display   | ✅       | ✅ (`-q`)    |

## Requirements

- **Bash** 4.0+
- **cPanel/WHM** (for `/var/log/chkservd.log`)
- Standard Unix tools: `grep`, `sed`, `awk`, `stat`, `ps`, `tac` (optional)

## Installation

```bash
# Clone or download
curl -O https://raw.githubusercontent.com/sr00t3d/cpanel-checksrv/refs/heads/main/checksrv.sh

# Make executable
chmod +x checksrv.sh

# Optional: move to PATH
sudo mv checksrv.sh /usr/local/bin/checksrv
```

## Usage

```bash
./checksrv.sh [OPTIONS]
```

### Options


| Option | Long Form      | Description                                      |
| -------- | ---------------- | -------------------------------------------------- |
| `-a`   | `--all`        | Display all service checks (last 5000 lines max) |
| `-f`   | `--functional` | Show functional services too (with details)      |
| `-q N` | `--quantity N` | Show last N service checks (default: 5)          |
| `-h`   | `--help`       | Show help message                                |

## Examples

### 1. Check for Failures (Default)

Show only failed services from last 5 checks:

```bash
./checksrv.sh
```

**Output when healthy:**

```bash
--------------------------------------
        Chksrvd Log Parser v2.0 (Bash)
--------------------------------------

Analisando últimas 5 verificações...
Nenhuma falha encontrada nas últimas verificações.
```

**Output with failures:**

```bash
[2026-03-03 09:45:12 -0300]
        [!] httpd failed
        [!] mysql failed
```

### 2. Detailed Service Status

Show all services (functional + failed) with details:

```bash
./checksrv.sh -f -q 2
```

**Output:**

```bash
--------------------------------------
        Chksrvd Log Parser v2.0 (Bash)
--------------------------------------

=== Informações do Sistema ===
chkservd: RUNNING (PID: 1234, Uptime: 15-03:45:12)
Log: 99 MB | Checks: 53571
Falhas nas últimas 2000 linhas: 0

Analisando últimos 2 checks completos...

═══════════════════════════════════════════════════════════════
[2026-03-03 09:45:12 -0300] Service Check (24 serviços)
───────────────────────────────────────────────────────────────
        [✓] queueprocd [check:+] [socket:N/A] OK
        [✓] sshd [check:+] [socket:N/A] OK
        [✓] spamd [check:+] [socket:N/A] OK
        [✓] rsyslogd [check:+] [socket:N/A] OK
        [✓] pop [check:+] [socket:+] OK
        [✓] p0f [check:+] [socket:N/A] OK
        [✓] nscd [check:+] [socket:N/A] OK
        [✓] named [check:+] [socket:N/A] OK
        [✓] mysql [check:+] [socket:N/A] OK
        [✓] mailman [check:+] [socket:N/A] OK
        [✓] lmtp [check:+] [socket:+] OK
        [✓] lfd [check:+] [socket:N/A] OK
        [✓] ipaliases [check:+] [socket:N/A] OK
        [✓] imap [check:+] [socket:+] OK
        [✓] httpd [check:N/A] [socket:+] OK
        [✓] exim [check:+] [socket:+] OK
        [✓] dnsadmin [check:+] [socket:+] OK
        [✓] crond [check:+] [socket:N/A] OK
        [✓] cpsrvd [check:N/A] [socket:+] OK
        [✓] cphulkd [check:+] [socket:+] OK
        [✓] cpdavd [check:+] [socket:N/A] OK
        [✓] cpanellogd [check:+] [socket:N/A] OK
        [✓] cpanel_php_fpm [check:+] [socket:N/A] OK
        [✓] apache_php_fpm [check:+] [socket:N/A] OK
───────────────────────────────────────────────────────────────
        Resumo: Todos 24 serviços OK

═══════════════════════════════════════════════════════════════
[2026-03-03 09:36:36 -0300] Service Check (24 serviços)
───────────────────────────────────────────────────────────────
        ...
        Resumo: Todos 24 serviços OK
```

### 3. View All Recent Checks

Show all checks from the last 5000 log lines:

```bash
./checksrv.sh -f -a
```

### 4. Custom Quantity

Show last 10 checks with full details:

```bash
./checksrv.sh -f -q 10
```

### 5. Minimal Check (for Cron)

Silent check - only outputs if there are failures:

```bash
./checksrv.sh -q 1
```

**Perfect for cron monitoring:**

```bash
# Add to crontab
*/5 * * * * /usr/local/bin/checksrv -q 1 || echo "Service failure detected on $(hostname)" | mail -s "Alert" admin@example.com
```

## Output Formats

### Color Coding


| Color     | Meaning                |
| ----------- | ------------------------ |
| 🟢 Green  | Service OK             |
| 🔴 Red    | Service Failed         |
| 🟡 Yellow | Timestamps and headers |
| 🔵 Blue   | Processing messages    |
| Cyan      | Section separators     |

### Status Indicators


| Symbol | Status         | Description                          |
| -------- | ---------------- | -------------------------------------- |
| `[✓]` | OK             | Service passed check                 |
| `[!]`  | FAILED         | Service failed check                 |
| `+`    | Success        | Command/Socket test passed           |
| `-`    | Failure        | Command/Socket test failed           |
| `N/A`  | Not Applicable | Check not available for this service |

## ⚡ Performance

Optimized for large log files:


| Metric         | Original Perl    | This Version    |
| ---------------- | ------------------ | ----------------- |
| 100MB log file | ~30-60s          | ~1-3s           |
| Memory usage   | High (full read) | Low (streaming) |
| 1000 checks    | Slow             | Instant         |
| 50000+ checks  | Very slow        | < 5s            |

**Techniques used:**

- `grep` + `tail` instead of full file read
- `awk` for efficient parsing
- Streaming processing (no full file in memory)
- `tac` for reverse reading (when needed)

## Troubleshooting

### No output at all

```bash
# Check if log exists
ls -la /var/log/chkservd.log

# Check if chkservd is running
systemctl status chkservd
# or
service chkservd status
```

### Permission denied

```bash
# Run as root or with sudo
sudo ./checksrv.sh
```

### Script hangs

The log file may be extremely large. The script limits `-a` mode to 5000 lines. Use `-q` for specific quantities.

### No colors in output

Colors are enabled by default. If your terminal doesn't support colors, they won't show (but output still works).

## Monitored Services

Typical cPanel/WHM services checked:

| Category       | Services                                          |
| ---------------- | --------------------------------------------------- |
| **Web Server** | httpd, apache_php_fpm, cpanel_php_fpm             |
| **Mail**       | exim, imap, pop, lmtp, mailman, spamd             |
| **Database**   | mysql                                             |
| **DNS**        | named, dnsadmin                                   |
| **Security**   | cphulkd, lfd, p0f                                 |
| **System**     | sshd, crond, rsyslogd, nscd                       |
| **cPanel**     | cpsrvd, cpdavd, cpanellogd, ipaliases, queueprocd |

## Credits

- **Original Author**: Matthew Harris (HostGator)
- **Original Date**: 2013-02-15
- **Bash Rewrite**: 2026
- **Purpose**: System administration tool for cPanel/WHM servers

## Links

- Original HostGator Wiki: `https://gatorwiki.hostgator.com/Admin/RootBin#checkserv`
- Original Repository: `http://git.toolbox.hostgator.com/checkserv`

## Legal Notice

> [!WARNING]
> This software is provided "as is." Always ensure you have explicit permission before executing it. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## Detailed Tutorial

For a complete, step-by-step guide, check out my full article:

👉 [**Check services failures on cPanel**](https://perciocastelo.com.br/blog/check-services-failures-on-cpanel.html)

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.

---

**Note**: This is an unofficial rewrite and not supported/sponsored by HostGator.