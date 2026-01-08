#!/usr/bin/env bash
#
# collect_powermetrics.sh - Collect detailed power metrics (requires sudo)
#
# This script uses the `powermetrics` command which provides detailed
# per-process and per-subsystem power consumption data.
#
# Usage:
#   sudo ./collect_powermetrics.sh              # Default: 10 minutes
#   sudo ./collect_powermetrics.sh 30           # 30 minutes
#   sudo ./collect_powermetrics.sh 60 5000      # 60 min, 5 sec interval
#
# Output: ~/zoom_powermetrics_YYYYmmdd_HHMMSS.txt

set -euo pipefail

DURATION_MIN="${1:-10}"
INTERVAL_MS="${2:-10000}"  # Default 10 seconds

# Calculate iterations
ITERATIONS=$(( (DURATION_MIN * 60 * 1000) / INTERVAL_MS ))

TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
OUTPUT_FILE="$HOME/zoom_powermetrics_${TIMESTAMP}.txt"

echo "=== Power Metrics Collection ==="
echo "Duration: ${DURATION_MIN} minutes"
echo "Interval: $((INTERVAL_MS / 1000)) seconds"
echo "Iterations: ${ITERATIONS}"
echo "Output: ${OUTPUT_FILE}"
echo ""

# Check for root/sudo
if [[ $EUID -ne 0 ]]; then
    echo "Error: powermetrics requires sudo/root privileges" >&2
    echo "Usage: sudo $0 [duration_min] [interval_ms]" >&2
    exit 1
fi

echo "Starting powermetrics collection..."
echo "Press Ctrl+C to stop early"
echo ""

# Run powermetrics
# -s samples specific subsystems: cpu_power, gpu_power, thermal, battery
# -i interval in milliseconds
# -n number of samples
powermetrics \
    -s cpu_power,gpu_power,thermal,battery,tasks \
    -i "$INTERVAL_MS" \
    -n "$ITERATIONS" \
    --show-process-energy \
    --show-process-gpu \
    2>&1 | tee "$OUTPUT_FILE"

echo ""
echo "=== Collection Complete ==="
echo "Output saved to: $OUTPUT_FILE"
echo ""
echo "Analysis tips:"
echo "  - Look for 'Energy Impact' per process"
echo "  - Check 'Package Power' for overall CPU power"
echo "  - Compare GPU power when using external displays"
echo "  - Review 'CPU Thermal Level' for throttling"
