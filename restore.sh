#!/bin/bash
# =============================================
# TalonTales - Restore Script
# =============================================
# Deploys all tracked configuration files from this repo
# to their correct system locations.
#
# Usage: ./restore.sh
#
# What it does:
#   1. Runs setup.sh if Wine prefix doesn't exist
#   2. Copies Wine registry files to WINEPREFIX
#   3. Copies Lutris configs to ~/.config/lutris/games/
#   4. Copies game files to the game directory
#   5. Verifies critical files exist

set -euo pipefail

# --- Configuration ---
GAME_DIR="/mnt/holy-grail/do-NOT-delete/Games/TalonTales"
WINEPREFIX="$HOME/.local/share/lutris/runners/wine/talontales"
LUTRIS_DIR="$HOME/.config/lutris/games"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Step 0: Ensure Wine prefix exists ---
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    info "Wine prefix not found. Running setup.sh first..."
    bash "$SCRIPT_DIR/setup.sh"
    echo ""
fi

# --- Step 1: Deploy Wine Prefix Configs ---
info "Step 1/4: Deploying Wine prefix configuration files..."

mkdir -p "$WINEPREFIX"

for file in user.reg system.reg userdef.reg winetricks.log lutris.json; do
    if [ -f "$SCRIPT_DIR/wine-prefix/$file" ]; then
        cp "$SCRIPT_DIR/wine-prefix/$file" "$WINEPREFIX/$file"
        info "  Copied wine-prefix/$file -> $WINEPREFIX/$file"
    else
        warn "  Skipped wine-prefix/$file (not found in repo)"
    fi
done

# --- Step 2: Deploy Lutris Configs ---
info "Step 2/4: Deploying Lutris game configurations..."

mkdir -p "$LUTRIS_DIR"

for file in "$SCRIPT_DIR"/lutris/*.yml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        cp "$file" "$LUTRIS_DIR/$filename"
        info "  Copied lutris/$filename -> $LUTRIS_DIR/$filename"
    fi
done

# --- Step 3: Deploy Game Files ---
info "Step 3/4: Deploying game directory files..."

mkdir -p "$GAME_DIR"

# Copy everything from game/ preserving directory structure
cp -r "$SCRIPT_DIR/game/"* "$GAME_DIR/" 2>/dev/null || {
    # If the glob expands to nothing (empty game/ dir), skip
    warn "  No files found in game/ directory to copy."
}

# Verify key DLLs were copied
CRITICAL_DLLS=(
    "d3d8.dll"
    "d3d9.dll"
    "ddraw.dll"
    "d3dimm.dll"
    "dinput.dll"
    "dgVoodoo.conf"
    "dxvk.conf"
)

for dll in "${CRITICAL_DLLS[@]}"; do
    if [ -f "$GAME_DIR/$dll" ]; then
        info "  Verified: $dll"
    else
        warn "  Missing: $GAME_DIR/$dll"
    fi
done

# --- Step 4: Verification Summary ---
info "Step 4/4: Verification..."

ERRORS=0

# Check Wine prefix
if [ -f "$WINEPREFIX/user.reg" ] && [ -f "$WINEPREFIX/system.reg" ]; then
    info "  Wine prefix: OK"
else
    error "  Wine prefix: REGISTRY FILES MISSING"
    ERRORS=$((ERRORS + 1))
fi

# Check dosdevices
if [ -L "$WINEPREFIX/dosdevices/e:" ]; then
    DOS_TARGET=$(readlink "$WINEPREFIX/dosdevices/e:")
    if [ "$DOS_TARGET" = "$GAME_DIR" ]; then
        info "  DosDevices e: -> $GAME_DIR: OK"
    else
        warn "  DosDevices e: -> $DOS_TARGET (expected $GAME_DIR)"
        info "  Run ./setup.sh to fix dosdevices mapping"
    fi
else
    warn "  DosDevices e: not found. Run ./setup.sh to create it."
fi

# Check Lutris configs
LUTRIS_OK=true
for yml in talontales.yml talon-1775380751.yml; do
    if [ ! -f "$LUTRIS_DIR/$yml" ]; then
        warn "  Lutris config missing: $LUTRIS_DIR/$yml"
        LUTRIS_OK=false
    fi
done
if [ "$LUTRIS_OK" = true ]; then
    info "  Lutris configs: OK"
fi

# Check game executables
if [ -f "$GAME_DIR/GameStart.exe" ] && [ -f "$GAME_DIR/GamePatch.exe" ]; then
    info "  Game executables: OK"
else
    warn "  Game executables: MISSING (expected GameStart.exe and GamePatch.exe)"
fi

# --- Done ---
echo ""
info "========================================="
info "Restore complete!"
info "========================================="
info ""
info "Files deployed:"
info "  Wine prefix configs -> $WINEPREFIX/"
info "  Lutris configs      -> $LUTRIS_DIR/"
info "  Game files          -> $GAME_DIR/"
info ""
info "Next steps:"
info "  1. Place game assets (GRFs, BGM, skins) in $GAME_DIR if not already present"
info "  2. Run: ./launch.sh GamePatch.exe"
info "     (This downloads Gepard anti-cheat files - required for login)"
info "  3. Run: ./launch.sh"
info "     (Launches the game!)"
info ""
warn "Note: gepard.dll and gepard.grf are NOT included in this repo."
warn "They must be obtained by running GamePatch.exe at least once."
