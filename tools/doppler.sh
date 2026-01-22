#!/bin/sh
# Install Doppler CLI on Debian/Ubuntu systems
# Usage:
#   chmod +x doppler.sh
#   ./doppler.sh

set -euo pipefail

log() {
  echo "[doppler-install] $*"
}

err() {
  echo "[doppler-install:ERROR] $*" >&2
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
  }
}

detect_debian_version() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$VERSION_ID" in
      "11"|"12"|"20.04"|"22.04"|"24.04"|*)
        # Debian 11+ or Ubuntu 22.04+ - use modern keyring method
        echo "modern"
        return 0
        ;;
      *)
        # Older versions - use apt-key method
        echo "legacy"
        return 0
        ;;
    esac
  fi
  # Default to modern if we can't detect
  echo "modern"
}

install_doppler_modern() {
  local sudo_cmd="$1"
  log "Installing Doppler CLI (modern method for Debian 11+ / Ubuntu 22.04+)..."
  
  log "Updating package index..."
  $sudo_cmd apt-get update
  
  log "Installing dependencies..."
  $sudo_cmd apt-get install -y apt-transport-https ca-certificates curl gnupg
  
  log "Adding Doppler GPG key..."
  curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
    'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
    $sudo_cmd gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
  
  log "Adding Doppler repository..."
  echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | \
    $sudo_cmd tee /etc/apt/sources.list.d/doppler-cli.list >/dev/null
  
  log "Updating package index..."
  $sudo_cmd apt-get update
  
  log "Installing Doppler CLI..."
  $sudo_cmd apt-get install -y doppler
}

install_doppler_legacy() {
  local sudo_cmd="$1"
  log "Installing Doppler CLI (legacy method for older Debian/Ubuntu versions)..."
  
  log "Updating package index..."
  $sudo_cmd apt-get update
  
  log "Installing dependencies..."
  $sudo_cmd apt-get install -y apt-transport-https ca-certificates curl gnupg
  
  log "Adding Doppler GPG key..."
  curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
    'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
    $sudo_cmd apt-key add -
  
  log "Adding Doppler repository..."
  echo "deb https://packages.doppler.com/public/cli/deb/debian any-version main" | \
    $sudo_cmd tee /etc/apt/sources.list.d/doppler-cli.list >/dev/null
  
  log "Updating package index..."
  $sudo_cmd apt-get update
  
  log "Installing Doppler CLI..."
  $sudo_cmd apt-get install -y doppler
}

main() {
  local SUDO_CMD
  SUDO_CMD="$(need_sudo)"
  
  # Check if we're on a Debian-based system
  if ! command -v apt-get >/dev/null 2>&1; then
    err "This script requires apt-get (Debian/Ubuntu system)"
    exit 1
  fi
  
  local install_method
  install_method="$(detect_debian_version)"
  
  if [ "$install_method" = "modern" ]; then
    install_doppler_modern "$SUDO_CMD"
  else
    install_doppler_legacy "$SUDO_CMD"
  fi
  
  log "Verifying installation..."
  if command -v doppler >/dev/null 2>&1; then
    log "Doppler CLI installed successfully!"
    doppler --version
  else
    err "Doppler CLI installation may have failed. Please check the output above."
    exit 1
  fi
  
  log "Done."
}

main "$@"
