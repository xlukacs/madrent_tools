#!/usr/bin/env bash
set -euo pipefail

# Change these if needed
DOTFILES_DIR="$HOME/dotfiles"
NVIM_CONFIG_SRC="$DOTFILES_DIR/nvim"
NVIM_CONFIG_DEST="$HOME/.config/nvim"
NVIM_APPIMAGE_URL="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.appimage"
NVIM_BIN="/usr/local/bin/nvim"

echo "==> Installing system dependencies (git, curl)..."
if command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y git curl

  # Optional: remove distro neovim so we only use the AppImage version
  if dpkg -l | grep -q "^ii\s\+neovim\s"; then
    echo "==> Removing distro neovim package (using AppImage instead)..."
    sudo apt remove -y neovim
  fi

elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y git curl
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Sy --noconfirm git curl
else
  echo "Package manager not detected. Please install git and curl manually."
fi

echo "==> Installing latest Neovim AppImage..."
tmpdir="$(mktemp -d)"
cd "$tmpdir"

echo "Temp dir for installation $tmpdir"

curl -LO "$NVIM_APPIMAGE_URL"
chmod +x nvim-linux-x86_64.appimage

# Some systems need --appimage-extract; we try direct move first.
# If it fails to run, you can later switch to extraction.
sudo mv nvim-linux-x86_64.appimage "$NVIM_BIN"

echo "==> Neovim version installed:"
"$NVIM_BIN" --version | head -n 1

echo "==> Preparing Neovim config directory..."
mkdir -p "$(dirname "$NVIM_CONFIG_DEST")"

if [ -e "$NVIM_CONFIG_DEST" ] && [ ! -L "$NVIM_CONFIG_DEST" ]; then
  backup="${NVIM_CONFIG_DEST}.backup.$(date +%s)"
  echo "==> Backing up existing Neovim config to $backup"
  mv "$NVIM_CONFIG_DEST" "$backup"
fi

echo "==> Linking Neovim config from $NVIM_CONFIG_SRC"
ln -sfn "$NVIM_CONFIG_SRC" "$NVIM_CONFIG_DEST"

echo "==> Bootstrapping lazy.nvim plugins (Kickstart)..."
"$NVIM_BIN" --headless "+Lazy! sync" +qa || true

echo "==> Done! Open Neovim normally: nvim"
