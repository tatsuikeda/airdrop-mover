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
DEDUP_DIR="/tmp/airdrop-mover-dedup"

mkdir -p "$DEST_DIR" "$DEDUP_DIR"

# fswatch -x emits one line per event with flags appended. AirDrop
# fires multiple events per file (Created, Renamed, AttributeModified)
# so we deduplicate using temp marker files.
fswatch -x "$WATCH_DIR" | while read -r line; do
  # Extract file path: everything before the first event flag keyword
  file="$(echo "$line" | awk '{for(i=1;i<=NF;i++){if($i ~ /^(Created|Updated|Removed|Renamed|OwnerModified|AttributeModified|MovedFrom|MovedTo|IsFile|IsDir|IsSymLink|Link|Overflow|PlatformSpecific)$/){break}; if(i>1)printf " "; printf $i}}')"

  # Skip if empty, directory, hidden, or partial download
  [[ -z "$file" ]] && continue
  [[ -d "$file" ]] && continue
  [[ "$(basename "$file")" == .* ]] && continue
  [[ "$file" == *.crdownload ]] && continue
  [[ "$file" == *.part ]] && continue
  [[ "$file" == *.download ]] && continue

  # Deduplicate: skip if we already saw this file recently
  dedup_key="$(echo "$file" | md5 -q 2>/dev/null || echo "$file" | md5sum 2>/dev/null | cut -d' ' -f1)"
  dedup_file="$DEDUP_DIR/$dedup_key"
  if [[ -f "$dedup_file" ]]; then
    continue
  fi
  touch "$dedup_file"
  # Clean old markers
  find "$DEDUP_DIR" -type f -not -newermt '10 seconds ago' -delete 2>/dev/null || true

  # Give the OS a moment to finish writing the file and set xattrs
  sleep 1

  # Skip if file no longer exists (already moved or deleted)
  [[ ! -f "$file" ]] && continue

  # Check if this file came from AirDrop (sharingd)
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

  # Remove dedup marker after processing
  rm -f "$dedup_file" 2>/dev/null
done
