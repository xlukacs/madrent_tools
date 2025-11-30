#!/usr/bin/env bash
# Install i3 on Ubuntu (desktop or server)
# Usage:
#   ./install-i3-ubuntu.sh [--with-extras] [--with-lightdm] [--config /path/to/i3.conf]
# Options:
#   --with-extras     Install helpful tools (rofi/picom/feh/kitty/etc)
#   --with-lightdm    Install LightDM (use if you don’t have a display manager)
#   --config PATH     Use this file as i3 config instead of generating one

set -euo pipefail

DEBIAN_FRONTEND=noninteractive

log() {
  echo "[i3-install] $*"
}

err() {
  echo "[i3-install:ERROR] $*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing command: $1"
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

is_ubuntu() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    [ "${ID:-}" = "ubuntu" ] || [ "${ID_LIKE:-}" = "ubuntu" ]
  else
    false
  fi
}

has_dm() {
  # Detect if a display manager seems present
  if [ -f /etc/X11/default-display-manager ]; then
    return 0
  fi
  # Fallback: common DMs
  systemctl list-unit-files 2>/dev/null | grep -qE \
    'gdm.service|gdm3.service|lightdm.service|sddm.service'
}

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

install_pkgs() {
  local sudo_cmd="$1"
  shift
  # Avoid duplicate installs
  local to_install=()
  for p in "$@"; do
    if ! pkg_installed "$p"; then
      to_install+=("$p")
    fi
  done
  if [ "${#to_install[@]}" -gt 0 ]; then
    $sudo_cmd apt-get install -y --no-install-recommends "${to_install[@]}"
  else
    log "All requested packages already installed: $*"
  fi
}

create_i3_config() {
  # $1: optional path to user-provided config file (may be empty)
  local user_cfg="$1"

  # Figure out which home to use (handles sudo)
  local home_dir
  home_dir="${SUDO_USER:+/home/$SUDO_USER}"
  home_dir="${home_dir:-$HOME}"

  local cfg_dir="$home_dir/.config/i3"
  local cfg_file="$cfg_dir/config"

  mkdir -p "$cfg_dir"

  # If user provided a config and it exists, use it
  if [ -n "$user_cfg" ] && [ -f "$user_cfg" ]; then
    log "Using user-provided i3 config: $user_cfg"
    cp "$user_cfg" "$cfg_file"
  else
    # If a config already exists and no user config was provided, leave it
    if [ -f "$cfg_file" ]; then
      log "Existing i3 config detected at $cfg_file; leaving it as-is."
      return 0
    fi

    log "No user config provided or file not found; generating minimal config."

    # Pick a sensible terminal default
    local term="xterm"
    command -v gnome-terminal >/dev/null 2>&1 && term="gnome-terminal"
    command -v kitty >/dev/null 2>&1 && term="kitty"

    # If rofi exists, use it; else fall back to dmenu
    local launcher="dmenu_run"
    command -v rofi >/dev/null 2>&1 && launcher="rofi -show drun"

    cat >"$cfg_file" <<EOF
# Minimal i3 config (auto-generated)
set \$mod Mod4

font pango:monospace 10

# Use Mouse+\$mod to drag floating windows
floating_modifier \$mod

# Terminal
bindsym \$mod+Return exec $term

# Kill focused window
bindsym \$mod+Shift+q kill

# Launcher (rofi or dmenu)
bindsym \$mod+d exec $launcher

# Focus movement
bindsym \$mod+j focus left
bindsym \$mod+k focus down
bindsym \$mod+l focus up
bindsym \$mod+semicolon focus right

# Move windows
bindsym \$mod+Shift+j move left
bindsym \$mod+Shift+k move down
bindsym \$mod+Shift+l move up
bindsym \$mod+Shift+semicolon move right

# Split orientation
bindsym \$mod+h split h
bindsym \$mod+v split v

# Fullscreen
bindsym \$mod+f fullscreen toggle

# Floating toggle
bindsym \$mod+Shift+space floating toggle

# Focus between tiling/floating
bindsym \$mod+space focus mode_toggle

# Workspaces 1-9
set \$ws1 "1"
set \$ws2 "2"
set \$ws3 "3"
set \$ws4 "4"
set \$ws5 "5"
set \$ws6 "6"
set \$ws7 "7"
set \$ws8 "8"
set \$ws9 "9"

bindsym \$mod+1 workspace \$ws1
bindsym \$mod+2 workspace \$ws2
bindsym \$mod+3 workspace \$ws3
bindsym \$mod+4 workspace \$ws4
bindsym \$mod+5 workspace \$ws5
bindsym \$mod+6 workspace \$ws6
bindsym \$mod+7 workspace \$ws7
bindsym \$mod+8 workspace \$ws8
bindsym \$mod+9 workspace \$ws9

bindsym \$mod+Shift+1 move container to workspace \$ws1
bindsym \$mod+Shift+2 move container to workspace \$ws2
bindsym \$mod+Shift+3 move container to workspace \$ws3
bindsym \$mod+Shift+4 move container to workspace \$ws4
bindsym \$mod+Shift+5 move container to workspace \$ws5
bindsym \$mod+Shift+6 move container to workspace \$ws6
bindsym \$mod+Shift+7 move container to workspace \$ws7
bindsym \$mod+Shift+8 move container to workspace \$ws8
bindsym \$mod+Shift+9 move container to workspace \$ws9

# Reload/Restart/Exit
bindsym \$mod+Shift+c reload
bindsym \$mod+Shift+r restart
bindsym \$mod+Shift+e exec --no-startup-id i3-nagbar -t warning \
  -m 'Exit i3?' -B 'Yes, exit' 'i3-msg exit'

# Status bar
bar {
  status_command i3status
}
EOF
  fi

  # Ensure user owns the config if script ran via sudo
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER":"$SUDO_USER" "$cfg_dir"
  fi

  log "Final i3 config is at $cfg_file"
}

main() {
  if ! is_ubuntu; then
    err "This script targets Ubuntu. Aborting."
    exit 1
  fi

  local WITH_EXTRAS=0
  local WITH_LIGHTDM=0
  local USER_CONFIG_FILE=""

  while [ "${1:-}" != "" ]; do
    case "$1" in
      --with-extras)
        WITH_EXTRAS=1
        ;;
      --with-lightdm)
        WITH_LIGHTDM=1
        ;;
      --config)
        shift
        USER_CONFIG_FILE="${1:-}"
        if [ -z "$USER_CONFIG_FILE" ]; then
          err "--config requires a path argument"
          exit 1
        fi
        ;;
      -h|--help)
        sed -n '2,80p' "$0"
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done

  local SUDO_CMD
  SUDO_CMD="$(need_sudo)"

  log "Updating package index..."
  $SUDO_CMD apt-get update -y

  # Base i3 packages
  log "Installing i3 and essentials..."
  install_pkgs "$SUDO_CMD" i3 i3blocks suckless-tools

  # Optional extras: launcher, compositor, image viewer, terminal, etc.
  if [ "$WITH_EXTRAS" -eq 1 ]; then
    log "Installing extras (rofi, picom, feh, kitty, etc.)..."
    install_pkgs "$SUDO_CMD" rofi picom feh kitty arandr \
      pavucontrol network-manager-gnome fonts-font-awesome
  fi

  # Display manager (optional)
  if [ "$WITH_LIGHTDM" -eq 1 ]; then
    log "Preparing LightDM preseed (set as default)..."
    echo "lightdm shared/default-x-display-manager select lightdm" | \
      $SUDO_CMD debconf-set-selections

    if ! pkg_installed xorg; then
      log "Installing Xorg (server/minimal systems)..."
      install_pkgs "$SUDO_CMD" xorg
    fi

    log "Installing LightDM..."
    install_pkgs "$SUDO_CMD" lightdm slick-greeter
    $SUDO_CMD systemctl enable lightdm || true
    $SUDO_CMD systemctl set-default graphical.target || true
  else
    if ! has_dm; then
      log "No display manager detected. You can install one with:"
      echo "  sudo apt-get update && sudo apt-get install -y lightdm"
      echo "Or re-run this script with --with-lightdm"
    else
      log "Display manager detected. i3 session will be available at login."
    fi
  fi

  create_i3_config "$USER_CONFIG_FILE"

  log "Done."
  echo
  echo "Next steps:"
  echo "- Log out, then at the login screen select the 'i3' session."
  echo "- Mod key is the Super/Windows key (assuming your config keeps that)."
}

main "$@"
