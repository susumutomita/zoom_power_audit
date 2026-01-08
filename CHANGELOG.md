# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-08

### Added

- Initial release
- `zoom-power-audit.sh`: Main monitoring script
  - Time-series sampling of CPU, memory, battery
  - Baseline system snapshot (OS, power, displays, USB/Thunderbolt)
  - End-of-run snapshot with pmset log
  - Graceful Ctrl+C handling with data preservation
  - Support for English and Japanese macOS
- `install.sh`: PATH installation helper
- `scripts/collect_powermetrics.sh`: Detailed power metrics (requires sudo)
- `scripts/quick_triage.sh`: One-shot snapshot for easy sharing
- Sample output files for documentation
- Comprehensive README with troubleshooting guide

### Compatibility

- macOS 14 (Sonoma) and later
- Apple Silicon (M1, M2, M3, M4 series)
- Intel Macs (limited testing)
