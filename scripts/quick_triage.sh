#!/usr/bin/env bash
#
# quick_triage.sh - Quick one-shot system snapshot for sharing
#
# This script captures a single snapshot of system state that's easy
# to copy-paste into Slack, GitHub issues, or support tickets.
#
# Usage:
#   ./quick_triage.sh           # Print to stdout
#   ./quick_triage.sh > report.txt  # Save to file

set -euo pipefail

# Safe command execution
safe_cmd() {
    "$@" 2>/dev/null || echo "(unavailable)"
}

# Get battery percentage
get_battery_percent() {
    pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1 || echo "?"
}

# Get power source
get_power_source() {
    local src
    src=$(pmset -g batt 2>/dev/null | head -1)
    if echo "$src" | grep -qi "ac power\|AC Power\|電源アダプタ"; then
        echo "AC Power"
    elif echo "$src" | grep -qi "battery\|バッテリー"; then
        echo "Battery"
    else
        echo "Unknown"
    fi
}

# Get display count and info
get_display_info() {
    local count
    count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution:" || echo "0")
    echo "$count display(s)"
    system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Display Type:|Resolution:|UI Looks like:|Refresh Rate:|Connection Type:" | head -20 | sed 's/^/  /'
}

# Get Zoom version
get_zoom_version() {
    if [[ -d "/Applications/zoom.us.app" ]]; then
        defaults read /Applications/zoom.us.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown"
    else
        echo "not installed"
    fi
}

# Get Zoom CPU/memory
get_zoom_stats() {
    local cpu mem_kb mem_mb
    cpu=$(ps -Ao pcpu,comm 2>/dev/null | grep -iE "zoom|cpthost" | awk '{sum += $1} END {printf "%.1f", sum}')
    mem_kb=$(ps -Ao rss,comm 2>/dev/null | grep -iE "zoom|cpthost" | awk '{sum += $1} END {print sum}')
    if [[ -n "$mem_kb" ]] && [[ "$mem_kb" -gt 0 ]]; then
        mem_mb=$((mem_kb / 1024))
    else
        mem_mb=0
    fi
    echo "CPU: ${cpu:-0}% | Memory: ${mem_mb}MB"
}

# Get WindowServer stats
get_windowserver_stats() {
    local cpu mem_kb mem_mb
    cpu=$(ps -Ao pcpu,comm 2>/dev/null | grep "WindowServer" | awk '{sum += $1} END {printf "%.1f", sum}')
    mem_kb=$(ps -Ao rss,comm 2>/dev/null | grep "WindowServer" | awk '{sum += $1} END {print sum}')
    if [[ -n "$mem_kb" ]] && [[ "$mem_kb" -gt 0 ]]; then
        mem_mb=$((mem_kb / 1024))
    else
        mem_mb=0
    fi
    echo "CPU: ${cpu:-0}% | Memory: ${mem_mb}MB"
}

# Main output
cat <<EOF
============================================================
Zoom Power Audit - Quick Triage
Captured: $(date)
============================================================

SYSTEM
  macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))
  Chip: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")

POWER
  Source: $(get_power_source)
  Battery: $(get_battery_percent)
  Low Power Mode: $(pmset -g 2>/dev/null | grep -i "lowpowermode" | awk '{print $2}' || echo "?")

DISPLAYS
$(get_display_info)

ZOOM
  Version: $(get_zoom_version)
  Stats: $(get_zoom_stats)
  Processes: $(ps aux 2>/dev/null | grep -icE "zoom|cpthost" | tr -d ' ') running

WINDOWSERVER
  Stats: $(get_windowserver_stats)

TOP 5 CPU PROCESSES
$(ps -Arco pcpu,pmem,comm 2>/dev/null | head -6 | tail -5 | awk '{printf "  %5.1f%% CPU | %5.1f%% MEM | %s\n", $1, $2, $3}')

PMSET SETTINGS (selected)
$(pmset -g 2>/dev/null | grep -E "hibernatemode|displaysleep|disksleep|sleep|powernap|proximitywake|tcpkeepalive|lowpowermode" | sed 's/^/  /')

============================================================
Quick Checks:
  [ ] External display at 60Hz? (not higher)
  [ ] Zoom virtual background OFF?
  [ ] Zoom HD video OFF?
  [ ] Zoom low-light adjustment OFF?
  [ ] Browser hardware acceleration ON?
============================================================
EOF
