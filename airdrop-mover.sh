#!/usr/bin/env bash
#
# airdrop-mover.sh
#
# Watches ~/Downloads for new files delivered via AirDrop
# (identified by sharingd in the quarantine xattr)
# and moves them to ~/AirDrop in date-stamped subfolders.
#
# Files arriving within 10 seconds of each other are grouped
# into the same subfolder.
#
# How it works: macOS stamps every incoming file with a quarantine
# extended attribute that includes the delivering app's bundle ID.
# AirDrop files are delivered by sharingd. This script watches for
# new files in ~/Downloads, checks that attribute, and moves only
# AirDrop deliveries. Browser downloads, Slack files, and everything
# else stay put.

WATCH_DIR="${AIRDROP_MOVER_WATCH_DIR:-$HOME/Downloads}"
DEST_DIR="${AIRDROP_MOVER_DEST_DIR:-$HOME/AirDrop}"
WATCH_DIR="${WATCH_DIR%/}"
BATCH_WINDOW=10

mkdir -p "$DEST_DIR"

CURRENT_SUBFOLDER=""
LAST_MOVE_TIME=0

# fswatch -x emits one line per event with flags appended. AirDrop
# fires multiple events per file (Created, Renamed, AttributeModified).
# The sleep + file existence check handles dedup naturally: the first
# event moves the file, subsequent events see it's gone and skip.
fswatch -x "$WATCH_DIR" | while read -r line; do
  # Extract file path (everything before the first event flag keyword)
  file="$(echo "$line" | awk '{for(i=1;i<=NF;i++){if($i ~ /^(Created|Updated|Removed|Renamed|OwnerModified|AttributeModified|MovedFrom|MovedTo|IsFile|IsDir|IsSymLink|Link|Overflow|PlatformSpecific)$/){break}; if(i>1)printf " "; printf $i}}')"

  # Skip directories, hidden files, and partial downloads
  [[ -z "$file" ]] && continue
  [[ -d "$file" ]] && continue
  [[ "$(basename "$file")" == .* ]] && continue
  [[ "$file" == *.crdownload ]] && continue
  [[ "$file" == *.part ]] && continue
  [[ "$file" == *.download ]] && continue

  # Only act on files directly in WATCH_DIR. AirDrop drops at the top
  # level; subfolders are user-organized and may contain old AirDrop
  # files that would otherwise get re-moved when their xattrs change
  # (e.g., dragging into iMessage triggers AttributeModified).
  [[ "$(dirname "$file")" != "$WATCH_DIR" ]] && continue

  # Wait for the OS to finish writing and set xattrs
  sleep 1

  # Skip if file is gone (already moved by a previous event for same file)
  [[ ! -f "$file" ]] && continue

  # Check if this file came from AirDrop
  quarantine="$(xattr -p com.apple.quarantine "$file" 2>/dev/null || true)"
  if [[ "$quarantine" == *"sharingd"* ]]; then
    NOW=$(date +%s)
    ELAPSED=$(( NOW - LAST_MOVE_TIME ))

    # Start a new subfolder if outside the batch window or no folder yet
    if [[ -z "$CURRENT_SUBFOLDER" ]] || [[ $ELAPSED -gt $BATCH_WINDOW ]]; then
      CURRENT_SUBFOLDER="$DEST_DIR/$(date '+%Y-%m-%d_%H-%M-%S')"
      mkdir -p "$CURRENT_SUBFOLDER"
    fi

    LAST_MOVE_TIME=$NOW

    basename="$(basename "$file")"
    dest="$CURRENT_SUBFOLDER/$basename"

    # Handle name collisions
    if [[ -e "$dest" ]]; then
      ext="${basename##*.}"
      name="${basename%.*}"
      counter=1
      while [[ -e "$CURRENT_SUBFOLDER/${name} (${counter}).${ext}" ]]; do
        ((counter++))
      done
      dest="$CURRENT_SUBFOLDER/${name} (${counter}).${ext}"
    fi

    mv "$file" "$dest"
    osascript -e "display notification \"Moved $(basename "$dest") to ~/AirDrop\" with title \"AirDrop Mover\"" 2>/dev/null || true
  fi
done
