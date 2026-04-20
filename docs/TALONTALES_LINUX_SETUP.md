# Talon Tales Linux Setup Guide (Wine + dgVoodoo + DXVK)

**Last Updated:** April 5, 2026  
**Status:** Partially Working - Game launches with graphics, but has multi-monitor and Gepard issues

---

## 📋 Table of Contents

1. [System Requirements](#system-requirements)
2. [What We Did to Get It Working](#what-we-did-to-get-it-working)
3. [Current Configuration](#current-configuration)
4. [Known Issues](#known-issues)
5. [Troubleshooting](#troubleshooting)
6. [File Locations](#file-locations)
7. [How the Stack Works](#how-the-stack-works)

---

## System Requirements

| Component | Required | Notes |
|-----------|----------|-------|
| Wine | 11.5+ | System Wine |
| DXVK | Latest | Required for dgVoodoo output |
| dgVoodoo | v2.79+ | DirectX 8/9 wrapper |
| Display Server | X11 or Wayland | Wayland may have issues |
| GPU | NVIDIA/AMD | NVIDIA RTX 4070 tested |

---

## What We Did to Get It Working

### Step 1: Fix Corrupted DLL Overrides in Wine Registry

The Wine registry had corrupted DLL overrides. We reset them:

```bash
# Remove corrupted overrides
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg delete "HKCU\Software\Wine\DllOverrides" /v d3d8 /f
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg delete "HKCU\Software\Wine\DllOverrides" /v d3d9 /f
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg delete "HKCU\Software\Wine\DllOverrides" /v ddraw /f
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg delete "HKCU\Software\Wine\DllOverrides" /v d3dimm /f

# Re-add them properly
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg add "HKCU\Software\Wine\DllOverrides" /v d3d8 /t REG_SZ /d native /f
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg add "HKCU\Software\Wine\DllOverrides" /v d3d9 /t REG_SZ /d native /f
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg add "HKCU\Software\Wine\DllOverrides" /v ddraw /t REG_SZ /d native /f
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine reg add "HKCU\Software\Wine\DllOverrides" /v d3dimm /t REG_SZ /d native /f
```

### Step 2: Reset Gepard Registration

The Gepard Shield registration was corrupted:

```bash
rm /mnt/holy-grail/do-NOT-delete/Games/TalonTales/gepard.register
rm -rf /mnt/holy-grail/do-NOT-delete/Games/TalonTales/GLCache
```

### Step 3: Install DXVK (CRITICAL!)

**This was the missing piece that caused the black screen!**

dgVoodoo outputs D3D11, and DXVK translates D3D11 to Vulkan for Linux.

```bash
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales /usr/share/dxvk/setup_dxvk.sh install
```

This installs DXVK DLLs to:
- `~/.local/share/lutris/runners/wine/talontales/drive_c/windows/system32/`
- `~/.local/share/lutris/runners/wine/talontales/drive_c/windows/syswow64/`

### Step 4: Enable DXVK in Lutris Config

Edit `~/.config/lutris/games/talontales.yml`:

```yaml
wine:
  dxvk: true    # Changed from false to true
  esync: true
  version: system
```

### Step 5: Verify dgVoodoo.conf Settings

The game directory already had a proper `dgVoodoo.conf` with:

```ini
[General]
OutputAPI = d3d11_fl10_0    # Outputs D3D11 for DXVK to handle
FullScreenMode = false
ScalingMode = centered_ar

[DirectX]
dgVoodooWatermark = false
VideoCard = internal3D
VRAM = 4096
FastVideoMemoryAccess = true
```

### Step 6: Launch the Game

```bash
cd /mnt/holy-grail/do-NOT-delete/Games/TalonTales && \
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales \
WINEDLLPATH=/mnt/holy-grail/do-NOT-delete/Games/TalonTales \
wine GameStart.exe
```

Or launch via patcher:
```bash
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales wine GamePatch.exe
```

---

## Current Configuration

### Lutris Config (`~/.config/lutris/games/talontales.yml`)

```yaml
name: TalonTales
game_slug: talontales
version: Custom Setup
slug: talontales-custom
runner: wine
year: 2002
user: tsunderick

script:
  game:
    exe: /mnt/holy-grail/do-NOT-delete/Games/TalonTales/GamePatch.exe
    prefix: $HOME/.local/share/lutris/runners/wine/talontales
    working_dir: /mnt/holy-grail/do-NOT-delete/Games/TalonTales
  
  wine:
    dxvk: true
    esync: true
    version: system
    
  system:
    env:
      __GL_SHADER_DISK_CACHE: "1"
      __GL_SHADER_DISK_CACHE_PATH: /mnt/holy-grail/do-NOT-delete/Games/TalonTales
```

### Wine DLL Overrides (Registry)

```
HKCU\Software\Wine\DllOverrides
    d3d8    REG_SZ    native
    d3d9    REG_SZ    native
    ddraw   REG_SZ    native
    d3dimm  REG_SZ    native
```

### Installed Winetricks

```
vcrun6
vcrun2008
```

---

## Known Issues

### 🟡 Issue 1: Multi-Monitor Problem

**Symptoms:** Floating game window only works on ONE specific monitor, becomes unresponsive when dragged to others  
**Status:** Partially Fixed

**Root Cause:**
- Vulkan surface is bound to the monitor where the game starts
- When window is dragged to another monitor, the Vulkan surface becomes invalid
- DXVK needs `deferSurfaceCreation` to handle window movement

**Fix Applied:**
1. Enable `dxvk.conf` (was disabled as `dxvk.conf.disabled`)
2. Add deferred surface creation for both D3D9 and D3D11

**dxvk.conf settings:**
```ini
# Defer surface creation - helps with window moving between monitors
d3d9.deferSurfaceCreation = True
d3d11.deferSurfaceCreation = True

# Shared memory for better multi-monitor handling
dxvk.shmem = True

# Enable device filtering (helps with multi-GPU setups)
dxvk.enableDeviceFilter = True
```

**If Still Not Working:**
1. Use gamescope: `gamescope -W 1920 -H 1080 -- wine GameStart.exe`
2. Lock to primary monitor via dgVoodoo.conf:
   ```ini
   FullScreenOutput = 1
   DisplayOutputEnableMask = 0x00000001
   ```

### 🔴 Issue 2: Gepard Shield Kick

**Symptoms:** Getting kicked immediately after login  
**Status:** Needs investigation

**Potential Causes:**
- Gepard Shield detecting Wine/Linux environment
- DLL modifications being flagged
- Anti-cheat incompatibility with Wine

**Potential Fixes to Try:**
1. Check if Gepard has Linux/Wine whitelist
2. Try different Wine versions (guide suggests sys-wine-8.0.2)
3. Disable any additional overlays/hooks
4. Contact server admin about Linux compatibility
5. Check Gepard logs for kick reason

### 🟡 Issue 3: Wayland Compatibility

**Symptoms:** May cause display issues  
**Status:** Partially mitigated

**Current Workaround:**
- DXVK handles Vulkan output
- dgVoodoo outputs D3D11

**Alternative:** Use gamescope for better Wayland support:
```bash
gamescope -W 1920 -H 1080 -w 1024 -h 768 -- wine GameStart.exe
```

---

## Troubleshooting

### White Screen on Launch
- **Cause:** dgvoodoo not loading (DLL overrides wrong)
- **Fix:** Verify DLL overrides are set to `native`

### Black Screen with dgVoodoo Watermark
- **Cause:** DXVK not installed/enabled
- **Fix:** Install DXVK and enable in Lutris config

### Game Crashes Immediately
- **Cause:** Missing dependencies or corrupted registry
- **Fix:** 
  1. Run `winetricks vcrun6 vcrun2008`
  2. Reset DLL overrides
  3. Reset Gepard registration

### Invalid System Key Error
- **Cause:** Corrupted Wine registry or Gepard registration
- **Fix:** Reset registry overrides and delete `gepard.register`

### Sprites Not Loading
- **Cause:** DirectX 8 not being translated properly
- **Fix:** Ensure dgVoodoo DLLs are in game directory and overrides are set

---

## File Locations

### Game Directory
```
/mnt/holy-grail/do-NOT-delete/Games/TalonTales/
├── GamePatch.exe          # Main launcher/patcher
├── GameStart.exe          # Game client
├── Setup.exe              # Graphics settings
├── dgVoodooCpl.exe        # dgVoodoo control panel
├── dgVoodoo.conf          # dgVoodoo configuration
├── dxvk.conf              # DXVK configuration (multi-monitor fix!)
├── d3d8.dll               # dgVoodoo DirectX 8 wrapper
├── d3d9.dll               # dgVoodoo DirectX 9 wrapper
├── ddraw.dll              # dgVoodoo DirectDraw wrapper
├── d3dimm.dll             # dgVoodoo D3D Immediate Mode wrapper
├── gepard.dll             # Anti-cheat
├── gepard.grf             # Anti-cheat data
├── gepard.register        # Anti-cheat registration
├── savedata/              # Game settings and saves
│   └── OptionInfo.lua     # Display settings
└── BGM/                   # Background music
```

### Wine Prefix
```
~/.local/share/lutris/runners/wine/talontales/
├── drive_c/
│   └── windows/
│       ├── system32/      # DXVK DLLs installed here
│       └── syswow64/      # 32-bit DXVK DLLs
├── system.reg             # System registry
├── user.reg               # User registry (DLL overrides)
└── userdef.reg            # User defaults
```

### Lutris Config
```
~/.config/lutris/games/talontales.yml
```

---

## How the Stack Works

```
┌─────────────────────────────────────────────────────────────┐
│                    TALON TALES GAME                          │
│                   (DirectX 8 Application)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     dgVoodoo2                                │
│  • d3d8.dll (in game dir) - Native override                 │
│  • Translates DX8 → DX11 (d3d11_fl10_0)                     │
│  • Config: dgVoodoo.conf                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       DXVK                                   │
│  • d3d11.dll (in Wine prefix)                               │
│  • Translates DX11 → Vulkan                                 │
│  • Essential for Linux display                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Vulkan / GPU                              │
│                   (NVIDIA RTX 4070)                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Display Server                            │
│              (Wayland / X11 / gamescope)                    │
└─────────────────────────────────────────────────────────────┘
```

### Key Insight

**Both dgVoodoo AND DXVK are required:**
- **dgVoodoo alone** = Black screen (DX11 has nowhere to go on Linux)
- **DXVK alone** = Original game won't work (DX8 too old)
- **dgVoodoo + DXVK** = Working graphics! ✓

---

## Reference: Working Payon RO Guide

Based on a working Linux setup for a similar Ragnarok Online server:

1. Use Bottles or Lutris with Wine 8.0.2
2. dgVoodoo v2.79.3 specifically
3. DXVK: dxvk-async-2.0 for NVIDIA, dxvk-2.0 for AMD
4. Install vcredist_x86 from game's Windows Libraries folder
5. DLL Overrides: ddraw, d3d8, d3dimm, d3d11 = Native (Windows)
6. Disable LatencyFleX if server has strong anti-cheat

---

## Quick Launch Command

```bash
cd /mnt/holy-grail/do-NOT-delete/Games/TalonTales && \
WINEPREFIX=~/.local/share/lutris/runners/wine/talontales \
WINEDLLPATH=/mnt/holy-grail/do-NOT-delete/Games/TalonTales \
wine GameStart.exe
```

---

## Next Steps for Future Debugging

1. **Multi-monitor:** Try Wine virtual desktop or gamescope
2. **Gepard kick:** Check Gepard logs, try different Wine versions
3. **If all else fails:** Try Bottles with the exact configuration from the Payon RO guide

---

*Document created during troubleshooting session on April 5, 2026*
