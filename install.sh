#!/usr/bin/env bash
#
# install.sh
#
# Installs airdrop-mover: a background service that automatically
# moves AirDrop files from ~/Downloads to ~/AirDrop.
#
# Usage: bash install.sh
# Uninstall: bash install.sh --uninstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/airdrop-mover"
PLIST_NAME="com.user.airdrop-mover"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
DEST_DIR="${AIRDROP_MOVER_DEST_DIR:-$HOME/AirDrop}"

# ──────────────────────────────────────────────────────────────────
# Uninstall
# ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  echo "==> Uninstalling airdrop-mover..."
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  rm -rf "$INSTALL_DIR"
  echo "==> Uninstalled. Your ~/AirDrop folder and its files are untouched."
  exit 0
fi

# ──────────────────────────────────────────────────────────────────
# Preflight
# ──────────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: this only works on macOS."
  exit 1
fi

if ! command -v fswatch &>/dev/null; then
  echo "fswatch is required but not installed."
  if command -v brew &>/dev/null; then
    read -rp "Install it with Homebrew? [Y/n] " answer
    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
      brew install fswatch
    else
      echo "Install fswatch manually and re-run this script."
      exit 1
    fi
  else
    echo "Install it with: brew install fswatch"
    exit 1
  fi
fi

# ──────────────────────────────────────────────────────────────────
# Install
# ──────────────────────────────────────────────────────────────────
echo "==> Installing airdrop-mover..."

# Copy script to a stable location
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/airdrop-mover.sh" "$INSTALL_DIR/airdrop-mover.sh"
chmod +x "$INSTALL_DIR/airdrop-mover.sh"

# Create destination folder
mkdir -p "$DEST_DIR"

# Stop existing service if running
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Resolve paths (launchd needs absolute paths)
FSWATCH_DIR="$(dirname "$(command -v fswatch)")"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo "/usr/local")"

# Use brew bash if available (Apple's /bin/bash is 3.2 from 2007)
BASH_PATH="${BREW_PREFIX}/bin/bash"
if [[ ! -x "$BASH_PATH" ]]; then
  BASH_PATH="/bin/bash"
fi

# Write launchd plist
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BASH_PATH}</string>
        <string>${INSTALL_DIR}/airdrop-mover.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${FSWATCH_DIR}:${BREW_PREFIX}/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/airdrop-mover.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/airdrop-mover.log</string>
</dict>
</plist>
EOF

# Start the service
launchctl load "$PLIST_PATH"

echo ""
echo "==> Installed and running."
echo "    AirDrop files will be moved from ~/Downloads to ${DEST_DIR}"
echo "    Logs: ${INSTALL_DIR}/airdrop-mover.log"
echo ""
echo "    Uninstall with: bash $SCRIPT_DIR/install.sh --uninstall"
