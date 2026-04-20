#!/bin/bash
# =============================================
# TalonTales - Full Setup Script
# =============================================
# One-command setup that:
#   1. Builds the Wine prefix (DXVK, DLL overrides, winetricks, dosdevices)
#   2. Copies binaries (EXEs, DLLs) into the game directory
#   3. Copies AI scripts into the game directory
#   4. Symlinks config files (edits in game dir = edits in repo)
#   5. Symlinks savedata (game saves sync to repo)
#   6. Copies Wine prefix registry files
#   7. Symlinks Lutris YAML configs (Lutris UI edits sync to repo)
#
# Usage: ./setup.sh
#
# Safe to run multiple times (idempotent).

set -euo pipefail

# --- Configuration ---
GAME_DIR="/mnt/holy-grail/do-NOT-delete/Games/TalonTales"
WINEPREFIX="$HOME/.local/share/lutris/runners/wine/talontales"
LUTRIS_DIR="$HOME/.config/lutris/games"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Helper: create symlink, removing existing file/dir/symlink first
symlink() {
    local src="$1"
    local dst="$2"
    if [ -L "$dst" ]; then
        local current
        current="$(readlink "$dst")"
        if [ "$current" = "$src" ]; then
            return 0  # already correct
        fi
        warn "  Updating symlink: $(basename "$dst")"
        rm "$dst"
    elif [ -e "$dst" ]; then
        warn "  Replacing existing file with symlink: $(basename "$dst")"
        rm -rf "$dst"
    fi
    ln -s "$src" "$dst"
    info "  Linked: $(basename "$dst")"
}

# Helper: copy file if destination doesn't exist or differs
copy_file() {
    local src="$1"
    local dst="$2"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        return 0  # identical, skip
    fi
    cp "$src" "$dst"
    info "  Copied: $(basename "$src")"
}

# --- Prerequisites Check ---
info "Checking prerequisites..."

command -v wine >/dev/null 2>&1 || error "wine is not installed."
command -v winetricks >/dev/null 2>&1 || error "winetricks is not installed."

if [ ! -f "/usr/share/dxvk/setup_dxvk.sh" ]; then
    warn "DXVK setup script not found at /usr/share/dxvk/setup_dxvk.sh"
    warn "DXVK installation will be skipped."
    DXVK_SETUP=""
else
    DXVK_SETUP="/usr/share/dxvk/setup_dxvk.sh"
fi

# --- Step 1: Build Wine Prefix ---
echo ""
info "=== Step 1/7: Build Wine Prefix ==="

if [ -f "$WINEPREFIX/system.reg" ]; then
    info "Wine prefix already exists. Skipping wineboot."
else
    info "Running wineboot --init..."
    mkdir -p "$WINEPREFIX"
    WINEPREFIX="$WINEPREFIX" wineboot --init
    while WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null; do sleep 1; done
    info "Wine prefix initialized."
fi

# --- Step 2: Install Winetricks ---
info "Installing winetricks dependencies (vcrun6, vcrun2008)..."

if [ -f "$WINEPREFIX/winetricks.log" ] && \
   grep -q "vcrun6" "$WINEPREFIX/winetricks.log" && \
   grep -q "vcrun2008" "$WINEPREFIX/winetricks.log"; then
    info "Winetricks already installed. Skipping."
else
    WINEPREFIX="$WINEPREFIX" winetricks -q vcrun6 vcrun2008
    info "Winetricks installed."
fi

# --- Step 3: Install DXVK ---
info "Installing DXVK..."

if [ -n "$DXVK_SETUP" ]; then
    if [ -f "$WINEPREFIX/drive_c/windows/syswow64/d3d11.dll" ]; then
        info "DXVK already present. Skipping."
    else
        WINEPREFIX="$WINEPREFIX" "$DXVK_SETUP" install
        info "DXVK installed."
    fi
else
    warn "DXVK not available. Install manually later."
fi

# --- Step 4: Apply DLL Overrides ---
info "Applying DLL overrides (d3d8, d3d9, ddraw, d3dimm -> native)..."

export WINEPREFIX
for dll in d3d8 d3d9 ddraw d3dimm; do
    WINEPREFIX="$WINEPREFIX" wine reg delete "HKCU\Software\Wine\DllOverrides" /v "$dll" /f 2>/dev/null || true
    WINEPREFIX="$WINEPREFIX" wine reg add "HKCU\Software\Wine\DllOverrides" /v "$dll" /t REG_SZ /d native /f >/dev/null 2>&1
done
WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true
info "DLL overrides applied."

# --- Step 5: Configure DosDevices + DPI ---
info "Configuring dosdevices (e: -> $GAME_DIR)..."

DOSDEVICES="$WINEPREFIX/dosdevices"
if [ -L "$DOSDEVICES/e:" ]; then
    current="$(readlink "$DOSDEVICES/e:")"
    if [ "$current" != "$GAME_DIR" ]; then
        rm "$DOSDEVICES/e:"
        ln -s "$GAME_DIR" "$DOSDEVICES/e:"
        info "DosDevices e: updated."
    fi
else
    ln -s "$GAME_DIR" "$DOSDEVICES/e:"
    info "DosDevices e: created."
fi

info "Setting DPI to 110..."
echo '{"dpi_assigned": 110}' > "$WINEPREFIX/lutris.json"

info "Wine prefix setup complete."

# --- Step 6: Deploy Game Files ---
echo ""
info "=== Step 6/7: Deploy Game Files ==="

mkdir -p "$GAME_DIR"

# 6a: Copy binaries (EXEs, DLLs, ASI, M3D)
info "Copying binaries to $GAME_DIR..."
for ext in exe dll asi m3d; do
    for file in "$SCRIPT_DIR/game/"*."$ext"; do
        [ -f "$file" ] || continue
        copy_file "$file" "$GAME_DIR/$(basename "$file")"
    done
done

# 6b: Copy AI scripts
info "Copying AI scripts..."
mkdir -p "$GAME_DIR/AI"
mkdir -p "$GAME_DIR/AI/USER_AI/data"
cp -r "$SCRIPT_DIR/game/AI/"* "$GAME_DIR/AI/" 2>/dev/null || true
info "AI scripts copied."

# 6c: Symlink config files (edits sync to repo)
info "Symlinking config files (edits in game dir = edits in repo)..."
for file in dgVoodoo.conf dxvk.conf dinput.ini dinput8.ini plugin.ini \
            Setup.ini GamePatch.ini; do
    src="$SCRIPT_DIR/game/$file"
    dst="$GAME_DIR/$file"
    [ -f "$src" ] && symlink "$src" "$dst"
done

# 6d: Symlink savedata (game saves sync to repo)
info "Symlinking savedata..."
mkdir -p "$GAME_DIR/savedata"
for file in OptionInfo.lua UserKeys_s.lua ChatWndInfo_U.lua MiniPartyInfo.lua; do
    src="$SCRIPT_DIR/game/savedata/$file"
    dst="$GAME_DIR/savedata/$file"
    [ -f "$src" ] && symlink "$src" "$dst"
done

# --- Step 7: Deploy Wine Prefix + Lutris Configs ---
echo ""
info "=== Step 7/7: Deploy Wine Prefix & Lutris Configs ==="

# 7a: Copy Wine prefix registry files (Wine overwrites these at runtime, don't symlink)
info "Copying Wine prefix registry files..."
for file in user.reg system.reg userdef.reg winetricks.log; do
    src="$SCRIPT_DIR/wine-prefix/$file"
    dst="$WINEPREFIX/$file"
    [ -f "$src" ] && copy_file "$src" "$dst"
done
copy_file "$SCRIPT_DIR/wine-prefix/lutris.json" "$WINEPREFIX/lutris.json"

# 7b: Symlink Lutris YAML configs (Lutris UI edits sync to repo)
info "Symlinking Lutris configs..."
mkdir -p "$LUTRIS_DIR"
for file in "$SCRIPT_DIR"/lutris/*.yml; do
    [ -f "$file" ] || continue
    symlink "$file" "$LUTRIS_DIR/$(basename "$file")"
done

# --- Done ---
echo ""
info "========================================="
info "Setup complete!"
info "========================================="
info ""
info "Symlinked configs (live-edit, auto-tracked by git):"
info "  game/*.conf, *.ini, grf.list, no_splash, gepard.license"
info "  game/savedata/*.lua"
info "  lutris/*.yml -> $LUTRIS_DIR/"
info ""
info "Copied binaries (one-time):"
info "  EXEs, DLLs, AI scripts -> $GAME_DIR/"
info ""
info "Copied Wine prefix files (one-time):"
info "  Registry files -> $WINEPREFIX/"
info ""
info "Next steps:"
info "  1. Place game assets (GRFs, BGM, skins) in $GAME_DIR"
info "  2. Open Lutris and configure the game (see README.md)"
info "  3. CRITICAL: Set Lutris executable to GamePatch.exe"
info "  4. Launch from Lutris"
info ""
warn "Note: gepard.dll and gepard.grf are NOT included."
warn "They are downloaded automatically when you run GamePatch.exe."
