#!/usr/bin/env bash
#
# zoom-power-audit.sh - Monitor power/CPU/memory during Zoom meetings
# https://github.com/stomita/zoom-power-audit
#
# Usage:
#   ./zoom-power-audit.sh --duration-min 60 --interval-sec 10
#   ./zoom-power-audit.sh -d 30 -i 5
#
# Output: ~/zoom_power_audit_YYYYmmdd_HHMMSS/
#   - baseline.txt: System info snapshot at start
#   - samples.csv: Time-series data (CPU, memory, battery)
#   - after.txt: System info snapshot at end + pmset log

set -euo pipefail

# ============================================================================
# Defaults
# ============================================================================
DURATION_MIN=60
INTERVAL_SEC=10
OUTPUT_DIR=""

# ============================================================================
# Parse arguments
# ============================================================================
print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Monitor power consumption, CPU, and memory during Zoom meetings.

OPTIONS:
  -d, --duration-min NUM   Duration in minutes (default: 60)
  -i, --interval-sec NUM   Sampling interval in seconds (default: 10)
  -o, --output-dir PATH    Custom output directory (default: ~/zoom_power_audit_YYYYmmdd_HHMMSS)
  -h, --help               Show this help message

EXAMPLES:
  $(basename "$0") --duration-min 120 --interval-sec 10
  $(basename "$0") -d 30 -i 5
  $(basename "$0")  # Use defaults: 60 min, 10 sec interval

OUTPUT:
  baseline.txt   System info at start (OS, power, displays, Zoom version, etc.)
  samples.csv    Time-series samples (timestamp, battery, CPU, memory)
  after.txt      System info at end + pmset log tail

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration-min)
            DURATION_MIN="$2"
            shift 2
            ;;
        -i|--interval-sec)
            INTERVAL_SEC="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

# Validate numeric inputs
if ! [[ "$DURATION_MIN" =~ ^[0-9]+$ ]] || [[ "$DURATION_MIN" -lt 1 ]]; then
    echo "Error: --duration-min must be a positive integer" >&2
    exit 1
fi

if ! [[ "$INTERVAL_SEC" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_SEC" -lt 1 ]]; then
    echo "Error: --interval-sec must be a positive integer" >&2
    exit 1
fi

# ============================================================================
# Setup output directory
# ============================================================================
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$HOME/zoom_power_audit_${TIMESTAMP}"
fi

mkdir -p "$OUTPUT_DIR"
BASELINE_FILE="$OUTPUT_DIR/baseline.txt"
SAMPLES_FILE="$OUTPUT_DIR/samples.csv"
AFTER_FILE="$OUTPUT_DIR/after.txt"

echo "=== Zoom Power Audit ==="
echo "Output directory: $OUTPUT_DIR"
echo "Duration: ${DURATION_MIN} minutes"
echo "Interval: ${INTERVAL_SEC} seconds"
echo ""

# ============================================================================
# Helper functions
# ============================================================================

# Safe command execution - returns empty string on failure
safe_cmd() {
    "$@" 2>/dev/null || echo ""
}

# Get battery percentage (works on both English and Japanese macOS)
get_battery_percent() {
    local pct
    pct=$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
    echo "${pct:-}"
}

# Get power source (AC or Battery)
get_power_source() {
    local src
    src=$(pmset -g batt 2>/dev/null | head -1)
    if echo "$src" | grep -qi "ac power\|AC Power\|電源アダプタ"; then
        echo "AC"
    elif echo "$src" | grep -qi "battery\|バッテリー"; then
        echo "Battery"
    else
        echo "Unknown"
    fi
}

# Get CPU % for processes matching a pattern (sum of all matching)
get_process_cpu() {
    local pattern="$1"
    local total
    # Use ps with keywords to avoid locale issues
    total=$(ps -Ao pcpu,comm 2>/dev/null | grep -i "$pattern" | awk '{sum += $1} END {printf "%.1f", sum}')
    echo "${total:-0.0}"
}

# Get memory MB for processes matching a pattern (sum of all matching)
get_process_mem_mb() {
    local pattern="$1"
    local total_kb
    # rss is in KB
    total_kb=$(ps -Ao rss,comm 2>/dev/null | grep -i "$pattern" | awk '{sum += $1} END {print sum}')
    if [[ -n "$total_kb" ]] && [[ "$total_kb" -gt 0 ]]; then
        echo "$((total_kb / 1024))"
    else
        echo "0"
    fi
}

# Get WindowServer stats
get_windowserver_cpu() {
    get_process_cpu "WindowServer"
}

get_windowserver_mem_mb() {
    get_process_mem_mb "WindowServer"
}

# Get Zoom stats (handles various Zoom process names)
get_zoom_cpu() {
    local total
    # Zoom may appear as "zoom.us", "Zoom", "CptHost", etc.
    total=$(ps -Ao pcpu,comm 2>/dev/null | grep -iE "zoom|cpthost" | awk '{sum += $1} END {printf "%.1f", sum}')
    echo "${total:-0.0}"
}

get_zoom_mem_mb() {
    local total_kb
    total_kb=$(ps -Ao rss,comm 2>/dev/null | grep -iE "zoom|cpthost" | awk '{sum += $1} END {print sum}')
    if [[ -n "$total_kb" ]] && [[ "$total_kb" -gt 0 ]]; then
        echo "$((total_kb / 1024))"
    else
        echo "0"
    fi
}

# Get top energy consumers from top command (if available)
# Returns comma-separated list of top 3 processes by CPU
get_top_energy_processes() {
    local result
    result=$(ps -Arco pcpu,comm 2>/dev/null | head -4 | tail -3 | awk '{printf "%s(%.1f%%) ", $2, $1}' | sed 's/ $//')
    echo "${result:-}"
}

# ============================================================================
# Collect baseline information
# ============================================================================
collect_baseline() {
    echo "Collecting baseline information..."
    {
        echo "=========================================="
        echo "Zoom Power Audit - Baseline"
        echo "Collected at: $(date)"
        echo "=========================================="
        echo ""

        echo "--- macOS Version ---"
        safe_cmd sw_vers
        echo ""

        echo "--- Hardware ---"
        safe_cmd sysctl -n machdep.cpu.brand_string
        safe_cmd sysctl -n hw.memsize | awk '{printf "Memory: %.0f GB\n", $1/1024/1024/1024}'
        echo ""

        echo "--- Power Source ---"
        safe_cmd pmset -g batt
        echo ""

        echo "--- Battery Health (if available) ---"
        { safe_cmd system_profiler SPPowerDataType 2>/dev/null | grep -A 20 "Battery Information" | head -25 || true; }
        echo ""

        echo "--- Energy Saver Settings ---"
        safe_cmd pmset -g
        echo ""

        echo "--- Display Configuration ---"
        safe_cmd system_profiler SPDisplaysDataType
        echo ""

        echo "--- USB Devices ---"
        { safe_cmd system_profiler SPUSBDataType 2>/dev/null | head -50 || true; }
        echo ""

        echo "--- Thunderbolt Devices ---"
        { safe_cmd system_profiler SPThunderboltDataType 2>/dev/null | head -30 || true; }
        echo ""

        echo "--- Zoom Version ---"
        if [[ -d "/Applications/zoom.us.app" ]]; then
            safe_cmd defaults read /Applications/zoom.us.app/Contents/Info.plist CFBundleShortVersionString
        else
            echo "Zoom not found in /Applications"
        fi
        echo ""

        echo "--- Running Zoom Processes ---"
        { ps aux 2>/dev/null | grep -iE "zoom|cpthost" | grep -v grep || true; } | { grep . || echo "(none)"; }
        echo ""

        echo "--- Top CPU Processes at Baseline ---"
        { ps -Arco pid,pcpu,pmem,comm 2>/dev/null | head -11 || true; }
        echo ""

    } > "$BASELINE_FILE"
    echo "  -> $BASELINE_FILE"
}

# ============================================================================
# Collect end-of-run information
# ============================================================================
collect_after() {
    echo ""
    echo "Collecting end-of-run information..."
    {
        echo "=========================================="
        echo "Zoom Power Audit - After"
        echo "Collected at: $(date)"
        echo "=========================================="
        echo ""

        echo "--- Power Source ---"
        safe_cmd pmset -g batt
        echo ""

        echo "--- Running Zoom Processes ---"
        { ps aux 2>/dev/null | grep -iE "zoom|cpthost" | grep -v grep || true; } | { grep . || echo "(none)"; }
        echo ""

        echo "--- Top CPU Processes at End ---"
        { ps -Arco pid,pcpu,pmem,comm 2>/dev/null | head -11 || true; }
        echo ""

        echo "--- pmset Log (last 100 lines) ---"
        # pmset log shows power events
        safe_cmd pmset -g log 2>/dev/null | tail -100
        echo ""

        echo "--- System Log Power Events (last 50) ---"
        safe_cmd log show --predicate 'subsystem == "com.apple.powerd"' --last 30m --style compact 2>/dev/null | tail -50
        echo ""

    } > "$AFTER_FILE"
    echo "  -> $AFTER_FILE"
}

# ============================================================================
# Sampling loop
# ============================================================================
run_sampling() {
    local total_samples
    total_samples=$(( (DURATION_MIN * 60) / INTERVAL_SEC ))
    local sample_count=0

    # CSV header
    echo "timestamp,power_source,battery_percent,zoom_cpu_percent,zoom_mem_mb,windowserver_cpu_percent,windowserver_mem_mb,top_processes" > "$SAMPLES_FILE"

    echo ""
    echo "Starting sampling (${total_samples} samples expected)..."
    echo "Press Ctrl+C to stop early (data will be saved)"
    echo ""

    local start_battery
    start_battery=$(get_battery_percent)

    while [[ $sample_count -lt $total_samples ]]; do
        local ts power_src batt_pct zoom_cpu zoom_mem ws_cpu ws_mem top_procs

        ts=$(date "+%Y-%m-%d %H:%M:%S")
        power_src=$(get_power_source)
        batt_pct=$(get_battery_percent)
        zoom_cpu=$(get_zoom_cpu)
        zoom_mem=$(get_zoom_mem_mb)
        ws_cpu=$(get_windowserver_cpu)
        ws_mem=$(get_windowserver_mem_mb)
        top_procs=$(get_top_energy_processes)

        # Escape quotes in top_procs for CSV
        top_procs="${top_procs//\"/\"\"}"

        echo "${ts},${power_src},${batt_pct},${zoom_cpu},${zoom_mem},${ws_cpu},${ws_mem},\"${top_procs}\"" >> "$SAMPLES_FILE"

        sample_count=$((sample_count + 1))

        # Progress indicator
        local elapsed_min=$(( (sample_count * INTERVAL_SEC) / 60 ))
        local current_battery
        current_battery=$(get_battery_percent)
        local drain=""
        if [[ -n "$start_battery" ]] && [[ -n "$current_battery" ]]; then
            drain=$((start_battery - current_battery))
        fi

        printf "\r[%d/%d] %s | Battery: %s%% | Drain: %s%% | Zoom CPU: %s%% | WS CPU: %s%%    " \
            "$sample_count" "$total_samples" "$ts" "${current_battery:-?}" "${drain:-?}" "$zoom_cpu" "$ws_cpu"

        sleep "$INTERVAL_SEC"
    done

    echo ""
    echo ""
    echo "Sampling complete: $sample_count samples collected"
    echo "  -> $SAMPLES_FILE"
}

# ============================================================================
# Cleanup on interrupt
# ============================================================================
cleanup() {
    echo ""
    echo ""
    echo "Interrupted! Saving collected data..."
    collect_after
    echo ""
    echo "=== Summary ==="
    echo "Output saved to: $OUTPUT_DIR"
    echo "  - baseline.txt: System info at start"
    echo "  - samples.csv: $(wc -l < "$SAMPLES_FILE" | tr -d ' ') lines of time-series data"
    echo "  - after.txt: System info at end"
    exit 0
}

trap cleanup INT TERM

# ============================================================================
# Main
# ============================================================================
main() {
    # Check for macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "Error: This script is designed for macOS only" >&2
        exit 1
    fi

    collect_baseline
    run_sampling
    collect_after

    echo ""
    echo "=== Complete ==="
    echo "Output saved to: $OUTPUT_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Open samples.csv in Numbers or Excel to analyze trends"
    echo "  2. Compare zoom_cpu_percent vs windowserver_cpu_percent"
    echo "  3. Check baseline.txt for display/power settings"
    echo "  4. Share the folder (zip) for collaborative debugging"
    echo ""
    echo "Tip: Check README.md for common causes of battery drain"
}

main "$@"
