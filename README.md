# airdrop-mover

Automatically moves AirDrop files out of `~/Downloads` and into `~/AirDrop`.

No GUI, no paid app, no dependencies beyond `fswatch`. Runs as a background launchd service, starts at login, and sends a macOS notification when it moves a file.

## How it works

macOS stamps every incoming file with a quarantine extended attribute (`com.apple.quarantine`) that includes the bundle ID of the delivering application. AirDrop files are delivered by `com.apple.sharingd`. This script watches `~/Downloads` for new files, checks that attribute, and moves only AirDrop deliveries. Browser downloads, Slack files, and everything else stay put.

You can verify this yourself:

```bash
# AirDrop a file to your Mac, then check it:
xattr -p com.apple.quarantine ~/Downloads/some-airdropped-file.jpg
# Output: 0083;...;com.apple.sharingd;...
#                   ^^^^^^^^^^^^^^^^^^^ this is how we know
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
- Handles filename collisions (appends a counter)
- Sends a native macOS notification on each move
- Ignores partial downloads (.crdownload, .part, .download)
- Runs as a launchd agent (starts at login, restarts if it crashes)
- Idempotent installer (safe to run multiple times)
- Zero runtime dependencies beyond macOS and fswatch

## Requirements

- macOS
- [fswatch](https://github.com/emcrisostomo/fswatch) (`brew install fswatch`)

## License

MIT
