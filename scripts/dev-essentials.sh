#!/usr/bin/env bash
# Simple dev essentials installer for Ubuntu / Debian
# Usage:
#   chmod +x install-dev.sh
#   ./install-dev.sh
#
# Edit the EXTRA_PACKAGES array below to add/remove tools.

set -euo pipefail
DEBIAN_FRONTEND=noninteractive

log() {
  echo "[dev-install] $*"
}

err() {
  echo "[dev-install:ERROR] $*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    exit 1
  }
}

need_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    require_cmd sudo
    echo sudo
  else
    echo
  fi
}

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

install_pkgs() {
  local sudo_cmd="$1"
  shift
  local to_install=()
  for p in "$@"; do
    if ! pkg_installed "$p"; then
      to_install+=("$p")
    fi
  done

  if [ "${#to_install[@]}" -gt 0 ]; then
    log "Installing: ${to_install[*]}"
    $sudo_cmd apt-get install -y "${to_install[@]}"
  else
    log "All requested packages are already installed."
  fi
}

setup_ssh_keys() {
  # CHANGE THIS to where your old ~/.ssh is stored
  local SSH_BACKUP_DIR="$HOME/dotfiles/.ssh"
  local SSH_DEST_DIR="$HOME/.ssh"

  if [ ! -d "$SSH_BACKUP_DIR" ]; then
    log "SSH backup dir $SSH_BACKUP_DIR not found, skipping SSH key copy."
    return
  fi

  log "Setting up SSH keys from $SSH_BACKUP_DIR..."

  # If ~/.ssh already exists, back it up
  if [ -d "$SSH_DEST_DIR" ] || [ -f "$SSH_DEST_DIR" ]; then
    local backup="${SSH_DEST_DIR}.backup.$(date +%s)"
    log "Backing up existing $SSH_DEST_DIR to $backup"
    mv "$SSH_DEST_DIR" "$backup"
  fi

  # Create a fresh ~/.ssh
  mkdir -p "$SSH_DEST_DIR"
  chmod 700 "$SSH_DEST_DIR"

  # List of files we want to copy/override
  local files_to_copy=(
    id_ed25519
    id_ed25519.pub
    id_rsa
    id_rsa.pub
    config
  )

  for f in "${files_to_copy[@]}"; do
    if [ -f "$SSH_BACKUP_DIR/$f" ]; then
      cp "$SSH_BACKUP_DIR/$f" "$SSH_DEST_DIR/$f"
      log "Copied $f -> $SSH_DEST_DIR/$f"
    else
      log "No $f in backup, skipping."
    fi
  done

  # Fix permissions
  if [ -f "$SSH_DEST_DIR/id_ed25519" ]; then
    chmod 600 "$SSH_DEST_DIR/id_ed25519"
  fi
  if [ -f "$SSH_DEST_DIR/id_rsa" ]; then
    chmod 600 "$SSH_DEST_DIR/id_rsa"
  fi
  if [ -f "$SSH_DEST_DIR/id_ed25519.pub" ]; then
    chmod 644 "$SSH_DEST_DIR/id_ed25519.pub"
  fi
  if [ -f "$SSH_DEST_DIR/id_rsa.pub" ]; then
    chmod 644 "$SSH_DEST_DIR/id_rsa.pub"
  fi
  if [ -f "$SSH_DEST_DIR/config" ]; then
    chmod 600 "$SSH_DEST_DIR/config"
  fi

  log "SSH keys and config set up."
}

main() {
  local SUDO_CMD
  SUDO_CMD="$(need_sudo)"

  # ---- Base dev essentials (edit as you like) ----
  DEV_PACKAGES=(
    build-essential
    git
    curl
    wget
    neovim
    tmux
    ripgrep
    fd-find
    thunar
    blueman
    vim
    brightnessctl
  )

  # ---- Your extra packages go here ----
  # Add or remove as you wish, e.g. 'nodejs', 'docker.io', 'golang-go', etc.
  EXTRA_PACKAGES=(
    # example:
    # nodejs
    # npm
  )

  ALL_PACKAGES=("${DEV_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}")

  log "Updating package index..."
  $SUDO_CMD apt-get update -y

  install_pkgs "$SUDO_CMD" "${ALL_PACKAGES[@]}"

  log "Done. Installed dev essentials."

  setup_ssh_keys
}

main "$@"
