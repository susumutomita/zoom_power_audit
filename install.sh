#!/usr/bin/env bash
#
# install.sh - Install zoom-power-audit to your PATH
#
# Usage:
#   ./install.sh              # Install to ~/.local/bin (default)
#   ./install.sh /usr/local/bin  # Install to custom location (may need sudo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="$HOME/.local/bin"

# Determine install location
INSTALL_DIR="${1:-$DEFAULT_INSTALL_DIR}"

echo "=== Zoom Power Audit Installer ==="
echo ""

# Create install directory if needed
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Creating directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Copy main script
echo "Installing zoom-power-audit to $INSTALL_DIR..."
cp "$SCRIPT_DIR/zoom-power-audit.sh" "$INSTALL_DIR/zoom-power-audit"
chmod +x "$INSTALL_DIR/zoom-power-audit"

# Copy helper scripts if they exist
if [[ -d "$SCRIPT_DIR/scripts" ]]; then
    for script in "$SCRIPT_DIR/scripts"/*.sh; do
        if [[ -f "$script" ]]; then
            basename_script=$(basename "$script" .sh)
            cp "$script" "$INSTALL_DIR/zoom-power-$basename_script"
            chmod +x "$INSTALL_DIR/zoom-power-$basename_script"
            echo "  Installed: zoom-power-$basename_script"
        fi
    done
fi

echo ""
echo "Installation complete!"
echo ""

# Check if INSTALL_DIR is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "NOTE: $INSTALL_DIR is not in your PATH."
    echo ""
    echo "Add this line to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
    echo "Then run: source ~/.zshrc (or restart your terminal)"
else
    echo "You can now run: zoom-power-audit --help"
fi
echo ""
