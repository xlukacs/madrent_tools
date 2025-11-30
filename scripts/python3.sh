#!/usr/bin/env bash
# Install Python, pip, venv, and some global Python packages (Ubuntu/Debian)
# Usage:
#   chmod +x install-python-dev.sh
#   ./install-python-dev.sh
#
# Edit the GLOBAL_PIP_PACKAGES array below to add/remove what you want.

set -euo pipefail
DEBIAN_FRONTEND=noninteractive

log() {
  echo "[python-dev] $*"
}

err() {
  echo "[python-dev:ERROR] $*" >&2
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
    log "Installing apt packages: ${to_install[*]}"
    $sudo_cmd apt-get install -y "${to_install[@]}"
  else
    log "All requested apt packages are already installed."
  fi
}

pip_install_globals() {
  local pip_cmd="$1"
  shift
  local pkgs=("$@")
  if [ "${#pkgs[@]}" -eq 0 ]; then
    log "No global pip packages requested (GLOBAL_PIP_PACKAGES is empty)."
    return 0
  fi

  log "Installing global pip packages: ${pkgs[*]}"
  $pip_cmd install --upgrade pip
  $pip_cmd install "${pkgs[@]}"
}

main() {
  local SUDO_CMD
  SUDO_CMD="$(need_sudo)"

  log "Updating apt index..."
  $SUDO_CMD apt-get update -y

  # Core Python stuff
  APT_PKGS=(
    python3
    python3-pip
    python3-venv
  )

  install_pkgs "$SUDO_CMD" "${APT_PKGS[@]}"

  # Decide which pip to use (system python3)
  if command -v pip3 >/dev/null 2>&1; then
    PIP_CMD="$SUDO_CMD pip3"
  else
    err "pip3 not found even after install. Aborting."
    exit 1
  fi

  # ---- EDIT THIS ARRAY: global pip packages you want ----
  GLOBAL_PIP_PACKAGES=(
    # tooling
    pipx
    virtualenv
    black
    isort
    flake8
    mypy
    # testing
    pytest
    # HTTP / API
    requests
    httpx
  )

  pip_install_globals "$PIP_CMD" "${GLOBAL_PIP_PACKAGES[@]}"

  log "Done."
  echo
  echo "Python dev setup complete:"
  echo "- python3, pip3, and venv installed."
  echo "- Global pip packages installed: ${GLOBAL_PIP_PACKAGES[*]}"
  echo
  echo "To create a new virtual environment in the current folder:"
  echo "  python3 -m venv .venv"
  echo "  source .venv/bin/activate"
}

main "$@" 

