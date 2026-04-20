#!/bin/bash
# =============================================
# TalonTales - Game Launcher
# =============================================
# Launches TalonTales with the correct Wine
# environment variables pre-configured.
#
# Usage:
#   ./launch.sh              (launches GameStart.exe)
#   ./launch.sh GamePatch.exe   (launches the patcher)
#   ./launch.sh Setup.exe       (launches graphics settings)

set -euo pipefail

# --- Configuration ---
GAME_DIR="/mnt/holy-grail/do-NOT-delete/Games/TalonTales"
WINEPREFIX="$HOME/.local/share/lutris/runners/wine/talontales"

# Default to GameStart.exe if no argument given
EXE="${1:-GameStart.exe}"

# --- Validate ---
if [ ! -d "$GAME_DIR" ]; then
    echo "ERROR: Game directory not found: $GAME_DIR" >&2
    exit 1
fi

if [ ! -f "$GAME_DIR/$EXE" ]; then
    echo "ERROR: $EXE not found in $GAME_DIR" >&2
    exit 1
fi

if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "ERROR: Wine prefix not found at $WINEPREFIX" >&2
    echo "Run ./setup.sh first to create it." >&2
    exit 1
fi

# --- Launch ---
cd "$GAME_DIR"

export WINEPREFIX
export WINEDLLPATH="$GAME_DIR"

# NVIDIA shader cache (optional but recommended)
export __GL_SHADER_DISK_CACHE="${__GL_SHADER_DISK_CACHE:-1}"
export __GL_SHADER_DISK_CACHE_PATH="${__GL_SHADER_DISK_CACHE_PATH:-$GAME_DIR}"

echo "Launching $EXE..."
echo "  WINEPREFIX:  $WINEPREFIX"
echo "  WINEDLLPATH: $WINEDLLPATH"
echo "  Working dir: $GAME_DIR"
echo ""

wine "$EXE"
