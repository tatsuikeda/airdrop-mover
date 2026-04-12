#!/usr/bin/env bash
#
# airdrop-mover.sh
#
# Watches ~/Downloads for new files delivered via AirDrop
# (identified by sharingd in the quarantine xattr)
# and moves them to ~/AirDrop in date-stamped subfolders.
#
# How it works: macOS stamps every incoming file with a quarantine
# extended attribute that includes the delivering app's bundle ID.
# AirDrop files are delivered by sharingd. This script watches for
# new files in ~/Downloads, checks that attribute, and moves only
# AirDrop deliveries. Browser downloads, Slack files, and everything
# else stay put.

WATCH_DIR="${AIRDROP_MOVER_WATCH_DIR:-$HOME/Downloads}"
DEST_DIR="${AIRDROP_MOVER_DEST_DIR:-$HOME/AirDrop}"

mkdir -p "$DEST_DIR"

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

  # Wait for the OS to finish writing and set xattrs
  sleep 1

  # Skip if file is gone (already moved by a previous event for same file)
  [[ ! -f "$file" ]] && continue

  # Check if this file came from AirDrop
  quarantine="$(xattr -p com.apple.quarantine "$file" 2>/dev/null || true)"
  if [[ "$quarantine" == *"sharingd"* ]]; then
    subfolder="$DEST_DIR/$(date '+%Y-%m-%d_%H-%M-%S')"
    mkdir -p "$subfolder"

    basename="$(basename "$file")"
    dest="$subfolder/$basename"

    # Handle name collisions
    if [[ -e "$dest" ]]; then
      ext="${basename##*.}"
      name="${basename%.*}"
      counter=1
      while [[ -e "$subfolder/${name} (${counter}).${ext}" ]]; do
        ((counter++))
      done
      dest="$subfolder/${name} (${counter}).${ext}"
    fi

    mv "$file" "$dest"
    osascript -e "display notification \"Moved $(basename "$dest") to ~/AirDrop\" with title \"AirDrop Mover\"" 2>/dev/null || true
  fi
done
