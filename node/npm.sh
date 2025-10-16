#!/usr/bin/env bash
set -euo pipefail

#----------------------------------------
# CONFIGURATION
#----------------------------------------
NODE_VERSION="lts/*"   # You can change this (e.g., "20", "22", or exact version)
NVM_DIR="$HOME/.nvm"

#----------------------------------------
# HELPERS
#----------------------------------------
log() {
  echo -e "\e[1;32m[INFO]\e[0m $*"
}
error() {
  echo -e "\e[1;31m[ERROR]\e[0m $*" >&2
  exit 1
}

#----------------------------------------
# PREREQUISITES
#----------------------------------------
log "Updating package index..."
sudo apt-get update -y

log "Installing required packages..."
sudo apt-get install -y curl git ca-certificates build-essential

#----------------------------------------
# NVM INSTALLATION
#----------------------------------------
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  log "Installing NVM..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
else
  log "NVM already installed. Skipping..."
fi

# Make sure NVM is loaded in this session
export NVM_DIR
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

#----------------------------------------
# NODE + NPM INSTALLATION
#----------------------------------------
log "Installing Node.js version: $NODE_VERSION"
nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use default

#----------------------------------------
# VERIFY INSTALLATION
#----------------------------------------
log "Verifying installation..."
node -v || error "Node.js install failed!"
npm -v || error "npm install failed!"

#----------------------------------------
# ENVIRONMENT SETUP
#----------------------------------------
log "Adding NVM to your shell startup file..."

SHELL_RC=""
if [ -n "${ZSH_VERSION-}" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "${BASH_VERSION-}" ]; then
  SHELL_RC="$HOME/.bashrc"
else
  SHELL_RC="$HOME/.profile"
fi

# Only add lines if not already present
if ! grep -q 'NVM_DIR' "$SHELL_RC"; then
  {
    echo ''
    echo '# >>> NVM configuration >>>'
    echo 'export NVM_DIR="$HOME/.nvm"'
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    echo '# <<< NVM configuration <<<'
  } >>"$SHELL_RC"
  log "NVM added to $SHELL_RC"
else
  log "NVM already configured in $SHELL_RC"
fi

log "✅ Installation complete! Restart your terminal or run:"
echo "    source $SHELL_RC"
echo "Then verify with:"
echo "    node -v && npm -v"
echo "You can manage Node.js versions with 'nvm install <version>' and 'nvm use <version>'."