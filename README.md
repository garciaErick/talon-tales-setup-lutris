# TalonTales Linux Setup (Lutris)

Version-controlled configuration for running TalonTales (TalonRO) on Linux
via Wine + dgVoodoo2 + DXVK.

## What This Repo Contains

Everything needed to reproduce the game setup **except** game assets
(GRFs, BGM, skins) and Gepard anti-cheat binaries (obtained via patcher).

### Repository Structure

```
talon-tales-setup-lutris/
├── setup.sh                 # Build Wine prefix from scratch
├── restore.sh               # Deploy all configs to their system locations
├── launch.sh                # Launch the game with correct env vars
├── .gitignore
├── README.md
│
├── game/                    # Files that go in the game directory
│   ├── *.exe                # Game executables (GameStart, GamePatch, Setup, etc.)
│   ├── *.dll                # Custom DLLs (dgVoodoo2, dinput, MSVC runtimes, etc.)
│   ├── *.ini, *.conf        # Configuration files (dgVoodoo, DXVK, ROExt, etc.)
│   ├── AI/                  # Homunculus/mercenary AI scripts + AzzyAI
│   └── savedata/            # Game settings and keybindings
│
├── wine-prefix/             # Custom parts of the Wine prefix
│   ├── user.reg             # DLL overrides and per-app settings
│   ├── system.reg           # System-wide Wine registry
│   ├── userdef.reg          # User defaults
│   ├── winetricks.log       # Installed winetricks (vcrun6, vcrun2008)
│   ├── lutris.json          # DPI setting (110)
│   └── dosdevices.conf      # Documents drive letter mappings
│
├── lutris/                  # Lutris game configuration files
│   ├── talontales.yml
│   └── talon-1775380751.yml
│
└── docs/
    └── TALONTALES_LINUX_SETUP.md   # Detailed setup documentation
```

## Prerequisites

- **Wine** (tested with wine-staging-10.18)
- **Winetricks** (`vcrun6`, `vcrun2008`)
- **DXVK** (`/usr/share/dxvk/setup_dxvk.sh`)
- The game installer or existing game assets (GRFs, BGM, skins)

## Restore Procedure

### 1. Clone or extract this repo

```bash
cd /mnt/holy-grail/do-NOT-delete/Games/talon-tales-setup-lutris
```

### 2. Build the Wine prefix

```bash
./setup.sh
```

This creates the Wine prefix, installs winetricks, installs DXVK,
applies DLL overrides, configures dosdevices, and sets DPI.

### 3. Deploy all tracked files

```bash
./restore.sh
```

This copies game files, Wine registry files, and Lutris configs
to their correct system locations.

### 4. Place game assets

Copy the game assets into the game directory:

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

### 5. Run the patcher (first time only)

```bash
./launch.sh GamePatch.exe
```

This downloads `gepard.dll` and any other server-side updates.
**Gepard anti-cheat is required for login.**

### 6. Play!

```bash
./launch.sh
```

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
| `game/grf.list` | GRF file load order |

## Troubleshooting

See `docs/TALONTALES_LINUX_SETUP.md` for detailed troubleshooting:

- **White screen**: DLL overrides wrong, check they're set to `native`
- **Black screen with watermark**: DXVK not installed/enabled
- **Crash on launch**: Missing winetricks, run `./setup.sh`
- **Multi-monitor issues**: Check `dxvk.conf` has `deferSurfaceCreation = True`

## Notes

- `gepard.dll` and `gepard.grf` are **not** tracked (obtained via GamePatch.exe)
- `gepard.register` is **not** tracked (machine-specific, regenerates on launch)
- Shader cache (`GLCache/`) is **not** tracked (regenerates automatically)
- Paths are hardcoded to this machine's setup
