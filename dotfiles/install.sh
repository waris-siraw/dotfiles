#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------
# Paths
# ----------------------------------
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"
PACKAGES_DIR="$DOTFILES_DIR/packages"

# ----------------------------------
# Helpers
# ----------------------------------
install_pacman() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "Package file not found: $file"
    exit 1
  fi

  echo "Installing packages from $(basename "$file")"
  grep -Ev '^\s*#|^\s*$' "$file" | xargs sudo pacman -S --needed
}

copy_config() {
  local src="$1"

  if [[ ! -d "$src" ]]; then
    echo "Config dir not found: $src"
    exit 1
  fi

  echo "Copying config from $(basename "$src")"
  mkdir -p ~/.config
  cp -r "$src"/* ~/.config/
}

# ----------------------------------
# Profile selection
# ----------------------------------
echo
echo "Select installation profile:"
echo "1) Desktop"
echo "2) Laptop"
echo

read -rp "> " PROFILE_CHOICE

case "$PROFILE_CHOICE" in
  1) PROFILE="desktop" ;;
  2) PROFILE="laptop" ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

# ----------------------------------
# Packages
# ----------------------------------
install_pacman "$PACKAGES_DIR/common.pacman"
install_pacman "$PACKAGES_DIR/$PROFILE.pacman"

# ----------------------------------
# Config files
# ----------------------------------
copy_config "$CONFIG_DIR/common"
copy_config "$CONFIG_DIR/$PROFILE"

# ----------------------------------
# MIME defaults (optional)
# ----------------------------------
if [[ -f "$DOTFILES_DIR/mime/mimeapps.list" ]]; then
  echo "Applying MIME defaults"
  mkdir -p ~/.config
  cp "$DOTFILES_DIR/mime/mimeapps.list" ~/.config/mimeapps.list
fi

# ----------------------------------
# Done
# ----------------------------------
echo
echo "----------------------------------"
echo " Dotfiles install completed ✔"
echo
echo " Next manual steps:"
echo " - Install GTK theme (gruvbox-dark-gtk)"
echo " - Run Firefox once"
echo " - Reboot (recommended)"
echo "----------------------------------"

