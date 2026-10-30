#!/usr/bin/env bash
# AI workstation setup for Ubuntu / Debian (amd64 and arm64).
# Installs T3 Code and Cursor desktop apps, T3 / Cursor Agent / Codex /
# Claude Code CLIs, GitHub CLI, and Doppler. No Node.js prerequisite.
#
# Usage: ./scripts/setup-ai.sh
# Run as your normal user; sudo is used only for system packages.
# Existing desktop apps and agent CLIs are skipped. gh and doppler are
# managed through their official APT repositories.

set -euo pipefail

log() {
  echo "[ai-setup] $*"
}

err() {
  echo "[ai-setup:ERROR] $*" >&2
  exit 1
}

download() {
  curl --fail --silent --show-error --location --retry 3 "$1" -o "$2"
}

pkg_installed() {
  [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
}

install_cli() {
  local name="$1" command_name="$2" installer_url="$3" interpreter="$4"

  if command -v "$command_name" >/dev/null 2>&1; then
    log "$name already installed. Skipping."
    return
  fi

  log "Installing $name..."
  download "$installer_url" "$TMP_DIR/$command_name-install.sh"
  "$interpreter" "$TMP_DIR/$command_name-install.sh"
  command -v "$command_name" >/dev/null 2>&1 || err "$name installation failed: $command_name is missing."
}

setup_repositories() {
  # https://github.com/cli/cli/blob/trunk/docs/install_linux.md
  # https://docs.doppler.com/docs/install-cli
  log "Configuring GitHub CLI and Doppler APT repositories..."
  "${AS_ROOT[@]}" install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d

  download https://cli.github.com/packages/githubcli-archive-keyring.gpg "$TMP_DIR/githubcli.gpg"
  "${AS_ROOT[@]}" install -m 0644 "$TMP_DIR/githubcli.gpg" /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | "${AS_ROOT[@]}" tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  download https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key "$TMP_DIR/doppler.key"
  gpg --batch --yes --dearmor --output "$TMP_DIR/doppler.gpg" "$TMP_DIR/doppler.key"
  "${AS_ROOT[@]}" install -m 0644 "$TMP_DIR/doppler.gpg" /usr/share/keyrings/doppler-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" \
    | "${AS_ROOT[@]}" tee /etc/apt/sources.list.d/doppler-cli.list >/dev/null

  "${AS_ROOT[@]}" apt-get update
  "${AS_ROOT[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y gh doppler
}

install_desktop_apps() {
  # https://t3.codes/download
  if pkg_installed t3code; then
    log "T3 Code desktop already installed. Skipping."
  else
    log "Downloading the latest stable T3 Code desktop..."
    download https://api.github.com/repos/pingdotgg/t3code/releases/latest "$TMP_DIR/t3-release.json"
    local t3_url
    t3_url="$(jq -er --arg suffix "-$ARCH.deb" \
      '[.assets[] | select(.name | startswith("T3-Code-")) | select(.name | endswith($suffix)) | .browser_download_url] | if length == 1 then .[0] else error("Expected one T3 Code Debian package") end' \
      "$TMP_DIR/t3-release.json")"
    download "$t3_url" "$TMP_DIR/t3code.deb"
    "${AS_ROOT[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$TMP_DIR/t3code.deb"
  fi

  # https://cursor.com/download
  if pkg_installed cursor; then
    log "Cursor desktop already installed. Skipping."
  else
    local cursor_arch="$ARCH"
    [ "$ARCH" != amd64 ] || cursor_arch=x64
    log "Downloading the latest stable Cursor desktop..."
    download "https://api2.cursor.sh/updates/download/golden/linux-$cursor_arch-deb/cursor/latest" "$TMP_DIR/cursor.deb"
    "${AS_ROOT[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$TMP_DIR/cursor.deb"
  fi
}

main() {
  [ "$(uname -s)" = Linux ] && [ -f /etc/debian_version ] \
    || err "This script supports Ubuntu / Debian Linux."
  command -v apt-get >/dev/null 2>&1 || err "apt-get is required."
  command -v dpkg >/dev/null 2>&1 || err "dpkg is required."
  ARCH="$(dpkg --print-architecture)"
  case "$ARCH" in
    amd64|arm64) ;;
    *) err "Unsupported architecture: $ARCH (expected amd64 or arm64)." ;;
  esac

  AS_ROOT=()
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || err "sudo is required for system packages."
    AS_ROOT=(sudo)
    sudo -v
  fi

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf -- "$TMP_DIR"' EXIT
  # APT's _apt user must be able to read downloaded desktop packages.
  chmod 0755 "$TMP_DIR"

  log "Installing prerequisites..."
  "${AS_ROOT[@]}" apt-get update
  "${AS_ROOT[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg jq tar

  setup_repositories
  install_desktop_apps

  # Native installers put agent CLIs here; include it for this run as well.
  export PATH="$HOME/.local/bin:$PATH"
  mkdir -p "$HOME/.local/bin"
  # Persist PATH once for future login shells.
  local path_line='export PATH="$HOME/.local/bin:$PATH"'
  if ! grep -qxF "$path_line" "$HOME/.profile" 2>/dev/null; then
    printf '\n# AI command-line tools\n%s\n' "$path_line" >> "$HOME/.profile"
  fi

  install_cli "T3 Code CLI" t3 https://t3.codes/install.sh sh
  install_cli "Cursor Agent" cursor-agent https://cursor.com/install bash
  # https://learn.chatgpt.com/docs/codex/cli (official OpenAI documentation)
  install_cli "Codex CLI" codex https://chatgpt.com/codex/install.sh sh
  # https://code.claude.com/docs/en/setup
  install_cli "Claude Code" claude https://claude.ai/install.sh bash

  log "Verifying CLI installations..."
  t3 --version
  cursor-agent --version
  codex --version
  claude --version
  gh --version
  doppler --version

  log "Done. Open T3 Code and Cursor from your application launcher."
  log 'For this terminal, run: export PATH="$HOME/.local/bin:$PATH"'
  log "Sign in as needed: codex login; claude; cursor-agent login; gh auth login; doppler login"
}

main "$@"
