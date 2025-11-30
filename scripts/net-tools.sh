#!/usr/bin/env bash
# Install Tailscale and developer network tools on Ubuntu/Debian
#
# Usage:
#   chmod +x install-net-dev.sh
#   ./install-net-dev.sh --server       # CLI tools only, server/headless
#   ./install-net-dev.sh --desktop      # CLI + GUI tools (Postman, Wireshark)
#   ./install-net-dev.sh --desktop --tailscale-up
#
# Flags:
#   --server        Install for server/headless (no GUI tools, no snap)
#   --desktop       Install full setup including GUI tools (Postman, Wireshark)
#   --tailscale-up  Run 'tailscale up' at the end (interactive login)
#
# Edit the arrays NET_CLI_PACKAGES, NET_GUI_PACKAGES, EXTRA_PACKAGES
# to customize what gets installed.

set -euo pipefail
DEBIAN_FRONTEND=noninteractive

log() {
  echo "[net-dev] $*"
}

err() {
  echo "[net-dev:ERROR] $*" >&2
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
    log "All requested apt packages already installed."
  fi
}

install_snap_if_needed() {
  local sudo_cmd="$1"
  if ! command -v snap >/dev/null 2>&1; then
    log "snapd not found; installing snapd..."
    install_pkgs "$sudo_cmd" snapd
  fi
}

install_tailscale() {
  local sudo_cmd="$1"

  if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale already installed; skipping."
    return 0
  fi

  log "Installing Tailscale (from official repo)..."

  $sudo_cmd apt-get install -y curl apt-transport-https gnupg

  # NOTE: If you're not on Ubuntu 20.04 (focal), change 'focal' to your codename:
  # e.g. jammy, noble, bookworm, etc.
  local distro_codename
  distro_codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-focal}")"

  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${distro_codename}.noarmor.gpg" | \
    $sudo_cmd tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${distro_codename}.tailscale-keyring.list" | \
    $sudo_cmd tee /etc/apt/sources.list.d/tailscale.list >/dev/null

  $sudo_cmd apt-get update -y
  $sudo_cmd apt-get install -y tailscale

  log "Enabling and starting Tailscale service..."
  $sudo_cmd systemctl enable tailscaled || true
  $sudo_cmd systemctl start tailscaled || true

  log "Tailscale installed."
}

install_postman() {
  local sudo_cmd="$1"

  install_snap_if_needed "$sudo_cmd"

  if snap list 2>/dev/null | grep -q '^postman '; then
    log "Postman (snap) already installed; skipping."
    return 0
  fi

  log "Installing Postman via snap..."
  $sudo_cmd snap install postman
}

main() {
  local SUDO_CMD
  SUDO_CMD="$(need_sudo)"

  local MODE=""           # "server" or "desktop"
  local RUN_TAILSCALE_UP=0

  while [ "${1:-}" != "" ]; do
    case "$1" in
      --server)
        MODE="server"
        ;;
      --desktop)
        MODE="desktop"
        ;;
      --tailscale-up)
        RUN_TAILSCALE_UP=1
        ;;
      -h|--help)
        sed -n '2,120p' "$0"
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done

  if [ -z "$MODE" ]; then
    err "You must specify one of: --server or --desktop"
    echo "Example:"
    echo "  ./install-net-dev.sh --server"
    echo "  ./install-net-dev.sh --desktop --tailscale-up"
    exit 1
  fi

  log "Mode: $MODE"

  log "Updating apt index..."
  $SUDO_CMD apt-get update -y

  # ---- CLI network/dev tools (edit as desired) ----
  NET_CLI_PACKAGES=(
    curl
    wget
    httpie
    jq
    nmap
    net-tools      # ifconfig, netstat (legacy but handy)
    dnsutils       # dig, nslookup
    iproute2       # ip, ss, etc. (usually already installed)
    tcpdump
    traceroute
  )

  # ---- GUI network tools (desktop mode only) ----
  NET_GUI_PACKAGES=(
    wireshark
  )

  # ---- Extra stuff (common for both modes; edit as you like) ----
  EXTRA_PACKAGES=(
    # mitmproxy
    # socat
  )

  # Install CLI tools (both modes)
  install_pkgs "$SUDO_CMD" "${NET_CLI_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}"

  # Desktop-only tools
  if [ "$MODE" = "desktop" ]; then
    log "Desktop mode: installing GUI network tools..."
    install_pkgs "$SUDO_CMD" "${NET_GUI_PACKAGES[@]}"

    log "Desktop mode: installing Postman..."
    install_postman "$SUDO_CMD"
  else
    log "Server mode: skipping GUI tools (Wireshark, Postman, snap)."
  fi

  # Tailscale
  install_tailscale "$SUDO_CMD"

  if [ "$RUN_TAILSCALE_UP" -eq 1 ]; then
    log "Running 'tailscale up' now (you may need to complete login in browser)..."
    $SUDO_CMD tailscale up || {
      err "'tailscale up' failed; you can run it manually later."
    }
  else
    echo
    echo "[net-dev] Tailscale is installed but not yet authenticated."
    echo "Run this when you're ready:"
    echo "  sudo tailscale up"
  fi

  echo
  log "All done."
  echo "Installed CLI tools: ${NET_CLI_PACKAGES[*]} ${EXTRA_PACKAGES[*]}"
  if [ "$MODE" = "desktop" ]; then
    echo "Installed GUI tools: ${NET_GUI_PACKAGES[*]} + Postman (snap)"
  else
    echo "GUI tools were skipped (server mode)."
  fi
}

main "$@"
