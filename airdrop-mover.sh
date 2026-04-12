#!/usr/bin/env bash
#
# airdrop-mover.sh
#
# Watches ~/Downloads for new files delivered via AirDrop
# (identified by com.apple.sharingd in the quarantine xattr)
# and moves them to ~/AirDrop.
#
# How it works: macOS stamps every incoming file with a quarantine
# extended attribute that includes the delivering app's bundle ID.
# AirDrop files are delivered by com.apple.sharingd. This script
# watches for new files in ~/Downloads, checks that attribute, and
# moves only AirDrop deliveries.

WATCH_DIR="${AIRDROP_MOVER_WATCH_DIR:-$HOME/Downloads}"
DEST_DIR="${AIRDROP_MOVER_DEST_DIR:-$HOME/AirDrop}"

mkdir -p "$DEST_DIR"

fswatch -0 --event Created "$WATCH_DIR" | while IFS= read -r -d '' file; do
  # Skip directories, partial downloads, and hidden files
  [[ -d "$file" ]] && continue
  [[ "$(basename "$file")" == .* ]] && continue
  [[ "$file" == *.crdownload ]] && continue
  [[ "$file" == *.part ]] && continue
  [[ "$file" == *.download ]] && continue

  # Give the OS a moment to finish writing the file and set xattrs
  sleep 1

  # Check if this file came from AirDrop (sharingd)
  quarantine="$(xattr -p com.apple.quarantine "$file" 2>/dev/null || true)"
  if [[ "$quarantine" == *"com.apple.sharingd"* ]]; then
    basename="$(basename "$file")"
    dest="$DEST_DIR/$basename"

    # Handle name collisions
    if [[ -e "$dest" ]]; then
      ext="${basename##*.}"
      name="${basename%.*}"
      counter=1
      while [[ -e "$DEST_DIR/${name} (${counter}).${ext}" ]]; do
        ((counter++))
      done
      dest="$DEST_DIR/${name} (${counter}).${ext}"
    fi

    mv "$file" "$dest"
    osascript -e "display notification \"Moved $(basename "$dest") to ~/AirDrop\" with title \"AirDrop Mover\"" 2>/dev/null || true
  fi
done
