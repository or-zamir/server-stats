#!/usr/bin/env bash
#
# server-stats.sh - Analyse basic server performance stats on any Linux server.
# Project: https://roadmap.sh/projects/server-stats
#
# Usage: ./server-stats.sh

set -o pipefail
export LC_ALL=C

if [[ $(uname -s) != Linux || ! -r /proc/stat ]]; then
    printf 'Error: run this script on Linux with /proc mounted.\n' >&2
    exit 1
fi

for dependency in awk df ps nproc hostname uptime who wc sleep sed grep; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Error: required command not found: %s\n' "$dependency" >&2
        exit 1
    fi
done

BOLD=$'\e[1m'; CYAN=$'\e[36m'; RESET=$'\e[0m'
[[ -t 1 ]] || { BOLD=""; CYAN=""; RESET=""; }

section() {
    printf '\n%s%s== %s ==%s\n' "$BOLD" "$CYAN" "$1" "$RESET"
}

# ---------------------------------------------------------------- System info
section "System"
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "OS:            ${PRETTY_NAME:-$NAME}"
fi
echo "Hostname:      $(hostname)"
echo "Kernel:        $(uname -r)"
echo "Uptime:        $(uptime -p 2>/dev/null || awk '{printf "%d days, %d hours, %d minutes\n", $1/86400, ($1%86400)/3600, ($1%3600)/60}' /proc/uptime)"
echo "Load average:  $(awk '{print $1", "$2", "$3" (1, 5, 15 min)"}' /proc/loadavg)"
echo "Logged in:     $(who | wc -l) user session(s)"

# ---------------------------------------------------------------- CPU usage
section "CPU Usage"
# Sample /proc/stat twice, 1 second apart, and compute busy % from the delta.
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
idle=$(( (i2 + w2) - (i1 + w1) ))
total=$(( (u2+n2+s2+i2+w2+q2+sq2+st2) - (u1+n1+s1+i1+w1+q1+sq1+st1) ))
awk -v idle="$idle" -v total="$total" \
    'BEGIN { printf "Total CPU usage: %.1f%%  (%d cores)\n", (total ? 100*(total-idle)/total : 0), '"$(nproc)"' }'

# ---------------------------------------------------------------- Memory usage
section "Memory Usage"
awk '
    /^MemTotal:/     { total=$2 }
    /^MemAvailable:/ { avail=$2 }
    END {
        used = total - avail
        printf "Total: %.2f GiB\n", total/1048576
        printf "Used:  %.2f GiB (%.1f%%)\n", used/1048576,  100*used/total
        printf "Available: %.2f GiB (%.1f%%)\n", avail/1048576, 100*avail/total
    }' /proc/meminfo

# ---------------------------------------------------------------- Disk usage
section "Disk Usage"
df -P -k -l -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk '
    NR == 1 { printf "%-25s %10s %10s %10s %7s %7s\n", "Mount", "Size (GiB)", "Used (GiB)", "Free (GiB)", "Used%", "Free%"; next }
    {
        size+=$2; used+=$3; free+=$4
        printf "%-25s %10.1f %10.1f %10.1f %6.1f%% %6.1f%%\n", $6, $2/1048576, $3/1048576, $4/1048576, ($2 ? 100*$3/$2 : 0), ($2 ? 100*$4/$2 : 0)
    }
    END {
        if (size) printf "%-25s %10.1f %10.1f %10.1f %6.1f%% %6.1f%%\n", "TOTAL", size/1048576, used/1048576, free/1048576, 100*used/size, 100*free/size
    }'

# ---------------------------------------------------------------- Top processes
section "Top 5 Processes by CPU"
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | sed -n '1,6p'

section "Top 5 Processes by Memory"
ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | sed -n '1,6p'

# ---------------------------------------------------------------- Security
section "Failed Login Attempts"
if command -v journalctl >/dev/null 2>&1 && [[ -n $(journalctl -q -n 1 2>/dev/null) ]]; then
    count=$(journalctl -q _COMM=sshd 2>/dev/null | grep -c "Failed password")
    echo "Failed SSH password attempts (journal): $count"
elif [[ -r /var/log/auth.log ]]; then
    echo "Failed password attempts (auth.log): $(grep -c "Failed password" /var/log/auth.log)"
elif [[ -r /var/log/secure ]]; then
    echo "Failed password attempts (secure): $(grep -c "Failed password" /var/log/secure)"
else
    echo "Unavailable (run with sudo to read auth logs)"
fi
echo
