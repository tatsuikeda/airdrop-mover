# airdrop-mover

Automatically moves AirDrop files out of `~/Downloads` and into date-stamped subfolders under `~/AirDrop`.

No GUI, no paid app, no dependencies beyond `fswatch`. Runs as a background launchd service, starts at login, and sends a macOS notification when it moves a file.

## How it works

macOS stamps every incoming file with a quarantine extended attribute (`com.apple.quarantine`) that includes the delivering application. AirDrop files are delivered by `sharingd`. This script watches `~/Downloads` for new files, checks that attribute, and moves only AirDrop deliveries. Browser downloads, Slack files, and everything else stay put.

You can verify this yourself:

```bash
# AirDrop a file to your Mac, then check it:
xattr -p com.apple.quarantine ~/Downloads/some-airdropped-file.jpg
# Output: 0081;66a1b2c3;sharingd;SOME-UUID
#                        ^^^^^^^^ this is how we know
```

Files are organized into timestamped subfolders:

```
~/AirDrop/
  2026-04-12_14-30-05/
    IMG_0946.heic
    IMG_0947.heic
  2026-04-12_17-22-11/
    document.pdf
```

## Install

```bash
git clone https://github.com/tatsuikeda/airdrop-mover.git
cd airdrop-mover
bash install.sh
```

The installer will:
1. Prompt to install `fswatch` via Homebrew if it's not already installed
2. Copy the watcher script to `~/.local/share/airdrop-mover/`
3. Create `~/AirDrop/` if it doesn't exist
4. Install and start a launchd agent that runs at login
5. Use Homebrew's bash if available (Apple's `/bin/bash` is 3.2 from 2007)

## Uninstall

```bash
bash install.sh --uninstall
```

This removes the launchd agent and the installed script. Your `~/AirDrop` folder and its files are left untouched.

## Configuration

Set these environment variables before running `install.sh` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `AIRDROP_MOVER_DEST_DIR` | `~/AirDrop` | Where to move AirDrop files |
| `AIRDROP_MOVER_WATCH_DIR` | `~/Downloads` | Folder to watch for incoming files |

Example:

```bash
AIRDROP_MOVER_DEST_DIR=~/Documents/AirDrop bash install.sh
```

## Features

- Detects AirDrop files by quarantine xattr (not by file type or timing)
- Organizes into date-stamped subfolders (`~/AirDrop/2026-04-12_14-30-05/`)
- Deduplicates fswatch events (AirDrop fires 3 events per file)
- Handles filename collisions (appends a counter)
- Sends a native macOS notification on each move
- Ignores partial downloads (.crdownload, .part, .download)
- Runs as a launchd agent (starts at login, restarts if it crashes)
- Compatible with both Apple's bash 3.2 and modern bash 5.x
- Idempotent installer (safe to run multiple times)
- Zero runtime dependencies beyond macOS and fswatch

## Requirements

- macOS
- [fswatch](https://github.com/emcrisostomo/fswatch) (`brew install fswatch`)

## Why not Hazel?

[Hazel](https://www.noodlesoft.com/) is a great general-purpose file automation tool, but it costs $42 and this does the same thing for AirDrop in ~70 lines of bash. Both use the same underlying mechanism (the quarantine xattr) to identify AirDrop files.

## License

MIT
