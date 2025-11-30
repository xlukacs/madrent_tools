#!/usr/bin/env bash
# Inject custom bashrc content from dotfiles/system/.bashrc
# into the user's ~/.bashrc, backing up the original first.
#
# Usage:
#   chmod +x inject-bashrc.sh
#   ./inject-bashrc.sh

set -euo pipefail

log() {
  echo "[bashrc-inject] $*"
}

err() {
  echo "[bashrc-inject:ERROR] $*" >&2
}

main() {
  local DOTFILES_DIR="$HOME/dotfiles"
  local SRC_BASHRC="$DOTFILES_DIR/system/.bashrc"
  local SRC_BASH_ALIASES="$DOTFILES_DIR/system/.bash_aliases"
  # local TARGET_BASHRC="$HOME/.bash_aliases"
  local TARGET_BASHRC="$HOME/.bashrc"

  # if [ ! -f "$SRC_BASHRC" ]; then
    # err "Source bashrc not found: $SRC_BASHRC"
    # exit 1
  # fi
  
  if [ ! -f "$SRC_BASH_ALIASES" ]; then
	  err "Source bashrc not found: $SRC_BASH_ALIASES"
    exit 1
  fi


  # Create ~/.bashrc if it doesn't exist
  if [ ! -f "$TARGET_BASHRC" ]; then
    log "No existing $TARGET_BASHRC found, creating an empty one."
    touch "$TARGET_BASHRC"
  fi

  # Backup existing ~/.bashrc
  local backup="${TARGET_BASHRC}.backup.$(date +%s)"
  log "Backing up $TARGET_BASHRC to $backup"
  cp "$TARGET_BASHRC" "$backup"

  # Optional: avoid multiple injections if you run the script again
  # We’ll wrap your content in a marker block.
  local START_MARK="# >>> dotfiles/system/.bashrc (injected) >>>"
  local END_MARK="# <<< dotfiles/system/.bashrc (injected) <<<"

  # Remove any previous injected block if present
  if grep -qF "$START_MARK" "$TARGET_BASHRC"; then
    log "Previous injected block found, removing it before re-injecting."
    # Use awk to strip the old block
    awk -v start="$START_MARK" -v end="$END_MARK" '
      $0 == start {in_block=1; next}
      $0 == end   {in_block=0; next}
      !in_block   {print}
    ' "$TARGET_BASHRC" > "${TARGET_BASHRC}.tmp"
    mv "${TARGET_BASHRC}.tmp" "$TARGET_BASHRC"
  fi

  log "Appending custom bashrc to $TARGET_BASHRC"

  {
    echo ""
    echo "$START_MARK"
    # cat "$SRC_BASHRC"
    cat "$SRC_BASH_ALIASES"
    echo "$END_MARK"
    echo ""
  } >> "$TARGET_BASHRC"

  log "Done. Reload with:  source ~/.bashrc"
}

main "$@"
