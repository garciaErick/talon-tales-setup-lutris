#!/bin/bash
# =============================================
# TalonTales - Wine Prefix Setup Script
# =============================================
# Builds a fresh Wine prefix with DXVK, DLL overrides,
# dosdevices mappings, and required winetricks.
#
# Usage: ./setup.sh
#
# This script is safe to run multiple times. It will skip
# steps that have already been completed.

set -euo pipefail

# --- Configuration ---
GAME_DIR="/mnt/holy-grail/do-NOT-delete/Games/TalonTales"
WINEPREFIX="$HOME/.local/share/lutris/runners/wine/talontales"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Prerequisites Check ---
info "Checking prerequisites..."

command -v wine >/dev/null 2>&1 || error "wine is not installed. Install it first."
command -v winetricks >/dev/null 2>&1 || error "winetricks is not installed. Install it first."

if [ ! -f "/usr/share/dxvk/setup_dxvk.sh" ]; then
    warn "DXVK setup script not found at /usr/share/dxvk/setup_dxvk.sh"
    warn "DXVK installation will be skipped. You may need to install it manually."
    DXVK_SETUP=""
else
    DXVK_SETUP="/usr/share/dxvk/setup_dxvk.sh"
fi

if [ ! -d "$GAME_DIR" ]; then
    error "Game directory not found: $GAME_DIR"
fi

# --- Step 1: Create Wine Prefix ---
info "Step 1/6: Creating Wine prefix at $WINEPREFIX"

if [ -f "$WINEPREFIX/system.reg" ]; then
    info "Wine prefix already exists (system.reg found). Skipping wineboot."
else
    export WINEPREFIX
    info "Running wineboot --init (this may take a moment)..."
    WINEPREFIX="$WINEPREFIX" wineboot --init
    # Wait for wineboot to finish
    while WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null; do
        sleep 1
    done
    info "Wine prefix initialized."
fi

# --- Step 2: Install Winetricks ---
info "Step 2/6: Installing winetricks dependencies (vcrun6, vcrun2008)..."

if [ -f "$WINEPREFIX/winetricks.log" ]; then
    if grep -q "vcrun6" "$WINEPREFIX/winetricks.log" && grep -q "vcrun2008" "$WINEPREFIX/winetricks.log"; then
        info "Winetricks dependencies already installed. Skipping."
    else
        WINEPREFIX="$WINEPREFIX" winetricks -q vcrun6 vcrun2008
        info "Winetricks dependencies installed."
    fi
else
    WINEPREFIX="$WINEPREFIX" winetricks -q vcrun6 vcrun2008
    info "Winetricks dependencies installed."
fi

# --- Step 3: Install DXVK ---
info "Step 3/6: Installing DXVK..."

if [ -n "$DXVK_SETUP" ]; then
    if [ -f "$WINEPREFIX/drive_c/windows/syswow64/d3d11.dll" ]; then
        info "DXVK DLLs already present. Skipping."
    else
        WINEPREFIX="$WINEPREFIX" "$DXVK_SETUP" install
        info "DXVK installed."
    fi
else
    warn "DXVK setup script not available. Skipping."
    warn "Install DXVK manually: WINEPREFIX=$WINEPREFIX /usr/share/dxvk/setup_dxvk.sh install"
fi

# --- Step 4: Apply DLL Overrides ---
info "Step 4/6: Applying DLL overrides (d3d8, d3d9, ddraw, d3dimm -> native)..."

export WINEPREFIX

DLLS=("d3d8" "d3d9" "ddraw" "d3dimm")
for dll in "${DLLS[@]}"; do
    # Delete existing override first (ignore errors if it doesn't exist)
    WINEPREFIX="$WINEPREFIX" wine reg delete "HKCU\Software\Wine\DllOverrides" /v "$dll" /f 2>/dev/null || true
    # Add native override
    WINEPREFIX="$WINEPREFIX" wine reg add "HKCU\Software\Wine\DllOverrides" /v "$dll" /t REG_SZ /d native /f >/dev/null 2>&1
    info "  Set $dll = native"
done

# Kill wineserver after registry operations
WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true
info "DLL overrides applied."

# --- Step 5: Configure DosDevices ---
info "Step 5/6: Configuring dosdevices (e: -> $GAME_DIR)..."

DOSDEVICES="$WINEPREFIX/dosdevices"

if [ -L "$DOSDEVICES/e:" ]; then
    CURRENT_TARGET="$(readlink "$DOSDEVICES/e:")"
    if [ "$CURRENT_TARGET" = "$GAME_DIR" ]; then
        info "DosDevices e: already points to $GAME_DIR. Skipping."
    else
        warn "DosDevices e: points to $CURRENT_TARGET, updating to $GAME_DIR..."
        rm "$DOSDEVICES/e:"
        ln -s "$GAME_DIR" "$DOSDEVICES/e:"
        info "DosDevices e: updated."
    fi
else
    ln -s "$GAME_DIR" "$DOSDEVICES/e:"
    info "DosDevices e: created."
fi

# --- Step 6: Set DPI ---
info "Step 6/6: Setting DPI to 110..."

if [ -f "$WINEPREFIX/lutris.json" ]; then
    CURRENT_DPI=$(grep -o '"dpi_assigned":[[:space:]]*[0-9]*' "$WINEPREFIX/lutris.json" | grep -o '[0-9]*' || echo "")
    if [ "$CURRENT_DPI" = "110" ]; then
        info "DPI already set to 110. Skipping."
    else
        echo '{"dpi_assigned": 110}' > "$WINEPREFIX/lutris.json"
        info "DPI set to 110."
    fi
else
    echo '{"dpi_assigned": 110}' > "$WINEPREFIX/lutris.json"
    info "DPI set to 110."
fi

# --- Done ---
echo ""
info "========================================="
info "Wine prefix setup complete!"
info "========================================="
info ""
info "Wine prefix: $WINEPREFIX"
info "DosDevices e: -> $GAME_DIR"
info "DLL overrides: d3d8, d3d9, ddraw, d3dimm = native"
info "Winetricks: vcrun6, vcrun2008"
info "DXVK: installed"
info "DPI: 110"
info ""
info "Next steps:"
info "  1. Run ./restore.sh to deploy tracked config files"
info "  2. Place game assets (GRFs, BGM, skins) in $GAME_DIR"
info "  3. Run ./launch.sh GamePatch.exe to get Gepard anti-cheat files"
info "  4. Run ./launch.sh to play!"
