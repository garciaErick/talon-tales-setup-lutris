# TalonTales Linux Setup (Lutris)

Version-controlled configuration for running TalonTales (TalonRO) on Linux
via Lutris + Wine + dgVoodoo2 + DXVK.

## CRITICAL: Always Launch Through GamePatch.exe

**Gepard Shield anti-cheat expects you to launch from the patcher.** Do NOT
point Lutris (or any launcher) at `GameStart.exe`. Always use `GamePatch.exe`.
Launching directly from the game client will get you kicked immediately.

## The Gepard Anti-Cheat

Gepard Shield doesn't like standard Steam Proton or standard Wine versions.
It's not a kernel-level anti-cheat, so it can be worked around — but it requires
a specific Wine staging version and launching through the patcher.

**What works:** `wine-staging-10.18` (or `wine-10.18-staging-amd64`)

If you don't have this version, install [ProtonPlus](https://flathub.org/apps/details/net.davidotek.pupgui2)
and download Wine-Staging 10.18 through it, then restart Lutris.

## What This Repo Contains

Everything needed to reproduce the game setup **except** game assets
(GRFs, BGM, skins) and Gepard anti-cheat binaries (obtained via patcher).

### Repository Structure

```
talon-tales-setup-lutris/
├── setup.sh                 # One-command setup: Wine prefix + deploy everything
├── .gitignore
├── README.md
│
├── game/                    # Files that go in the game directory
│   ├── *.exe                # Game executables (GamePatch, GameStart, Setup, etc.)
│   ├── *.dll                # Custom DLLs (dgVoodoo2, dinput, MSVC runtimes, etc.)
│   ├── *.ini, *.conf        # Config files (SYMLINKED to game dir — edits sync to repo)
│   ├── AI/                  # Homunculus/mercenary AI scripts + AzzyAI
│   └── savedata/            # Game settings (SYMLINKED — saves sync to repo)
│
├── wine-prefix/             # Custom parts of the Wine prefix
│   ├── user.reg             # DLL overrides and per-app settings
│   ├── system.reg           # System-wide Wine registry
│   ├── userdef.reg          # User defaults
│   ├── winetricks.log       # Installed winetricks (vcrun6, vcrun2008)
│   └── lutris.json          # DPI setting (110)
│
├── lutris/                  # Lutris game configs (SYMLINKED — Lutris edits sync to repo)
│   ├── talontales.yml
│   └── talon-1775380751.yml
│
└── docs/
    └── TALONTALES_LINUX_SETUP.md   # Raw troubleshooting notes
```

### What's Symlinked vs Copied

| Type | Method | Why |
|------|--------|-----|
| Config files (`.conf`, `.ini`) | **Symlinked** | Edit in game dir = auto-tracked by git |
| `savedata/*.lua` | **Symlinked** | Game saves sync to repo |
| Lutris `*.yml` | **Symlinked** | Lutris UI edits sync to repo |
| Binaries (`.exe`, `.dll`, `.asi`, `.m3d`) | **Copied** | Don't change, no need to symlink |
| AI scripts | **Copied** | Rarely edited, simpler to copy |
| Wine `*.reg`, `winetricks.log` | **Copied** | Wine overwrites at runtime, symlinks would break |

## Setup Procedure

### 1. Install via Lutris

1. Have your `TalonTales_Full_Install.exe` ready.
2. Open Lutris and click the **+** button (top left).
3. Choose **"Install a Windows game from an executable"**.
4. Select the installer and let it run.
5. **CRITICAL: When setup finishes, UNCHECK "Launch game now".** Do not start yet.

### 2. Configure Lutris

Back in Lutris, right-click the new Talon Tales game and select **Configure**:

**Game options tab:**
- Change the **Executable** to `GamePatch.exe` (NOT GameStart.exe)

**Runner options tab:**
- Wine version: `wine-staging-10.18` (exactly this version)
- Toggle **Windowed (Virtual Desktop)** to **ON** — set resolution to your client size (e.g. 1920x1080)
- Set **Mouse Warp Override** to **Disable** (prevents mouse getting stuck on monitor edges)

### 3. Run setup.sh

```bash
git clone https://github.com/garciaErick/talon-tales-setup-lutris.git
cd talon-tales-setup-lutris
./setup.sh
```

This does everything in one shot:
- Builds the Wine prefix (wineboot, winetricks, DXVK, DLL overrides, dosdevices, DPI)
- Copies binaries and AI scripts to the game directory
- Symlinks config files and savedata (edits sync to repo)
- Copies Wine prefix registry files
- Symlinks Lutris YAML configs

### 4. Place game assets

Copy the game assets into the game directory (if not already there from the installer):

```
/mnt/holy-grail/do-NOT-delete/Games/TalonTales/
├── data.grf            # Main game data (~2GB)
├── tdata.grf           # Talon Tales custom data (~1.7GB)
├── gepard.grf          # Anti-cheat data (~32MB)
├── *.grf               # Event data GRFs
├── BGM/                # Background music (~645MB)
├── skin/               # UI skins (~284MB)
└── System/             # Game database files (~12MB)
```

### 5. Run the patcher

Launch the game from Lutris. The first time through, `GamePatch.exe` will
download `gepard.dll` and any server-side updates. **This is required for login.**

After patching completes, the game will launch normally.

## Multi-Monitor Fix

Gepard tries to hook the primary monitor's drawing buffer, so moving the
window to another monitor causes the image to freeze.

**Fix:** Enable **Windowed (Virtual Desktop)** in Lutris runner options.
This tricks Gepard/Wine into thinking there's only one big screen, so the
image stays alive wherever you drag it.

**Wayland users:** Switching to X11 also fixes it, but the virtual desktop
approach is the permanent fix if you want to stay on Wayland.

**Also:** Set **Mouse Warp Override** to **Disable** in Lutris runner options
or your mouse will get stuck on monitor edges.

## The Graphics Stack

```
Talon Tales (DirectX 8)
    ↓
dgVoodoo2 (d3d8.dll in game dir) → DX8 to DX11
    ↓
DXVK (d3d11.dll in Wine prefix) → DX11 to Vulkan
    ↓
GPU / Vulkan / Display
```

Both dgVoodoo2 AND DXVK are required:
- dgVoodoo2 alone = black screen (DX11 has nowhere to go on Linux)
- DXVK alone = game won't work (native DX8 too old)
- dgVoodoo2 + DXVK = working graphics

## Key Configuration Files

| File | Purpose |
|------|---------|
| `game/dgVoodoo.conf` | dgVoodoo2 settings (VRAM, resolution, vsync) |
| `game/dxvk.conf` | DXVK settings (multi-monitor fix, FPS HUD) |
| `game/dinput.ini` | ROExt mouse freedom and key remapping |
| `game/dinput8.ini` | ROExt window lock and input settings |
| `game/plugin.ini` | RCX skill ground effect visuals |
| `game/Setup.ini` | OpenSetup engine config |

## Troubleshooting

- **White screen**: DLL overrides wrong, check they're set to `native`
- **Black screen with watermark**: DXVK not installed/enabled
- **Crash on launch**: Missing winetricks, run `./setup.sh`
- **Kicked immediately after login**: Not launching through GamePatch.exe, or wrong Wine version
- **Multi-monitor image freeze**: Enable Virtual Desktop in Lutris runner options
- **Mouse stuck on screen edges**: Set Mouse Warp Override to Disable in Lutris

## Notes

- `gepard.dll`, `gepard.grf`, and `gepard.license` are **not** tracked (obtained via installer/patcher)
- `grf.list` is **not** tracked (provided by installer)
- `gepard.register` is **not** tracked (machine-specific, regenerates on launch)
- Shader cache (`GLCache/`) is **not** tracked (regenerates automatically)
- Paths are hardcoded to this machine's setup

## Credits

- **Vilefox** — Discovered that Gepard Shield works with `wine-staging-10.18` when
  launched through `GamePatch.exe` instead of the game client directly. Also found
  the virtual desktop multi-monitor fix and Mouse Warp Override setting.
  Without this research, none of this would work.
