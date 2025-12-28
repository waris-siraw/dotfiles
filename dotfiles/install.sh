#!/usr/bin/env bash
set -e

# ------------------ resolve paths correctly ------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_DIR="$SCRIPT_DIR/config/common"
STOW_DIR="$SCRIPT_DIR/stow"

echo "Install script location: $SCRIPT_DIR"
echo "Config source          : $CONFIG_DIR"
echo "Stow output            : $STOW_DIR"
echo

# ------------------ checks ------------------
command -v stow >/dev/null || {
  echo "❌ GNU Stow is not installed"
  exit 1
}

# ------------------ clean stow dir ------------------
echo "Cleaning stow directory…"
rm -rf "$STOW_DIR"
mkdir -p "$STOW_DIR"

# ------------------ helper ------------------
make_app_package () {
  local app="$1"

  echo "→ $app"
  mkdir -p "$STOW_DIR/$app/.config"
  cp -r "$CONFIG_DIR/$app" "$STOW_DIR/$app/.config/$app"
}

# ------------------ apps (~/.config/<app>) ------------------
APPS=(
  alacritty
  btop
  dunst
  fish
  i3
  i3blocks
  nvim
  rofi
  yazi
  zathura
)

for app in "${APPS[@]}"; do
  if [[ -d "$CONFIG_DIR/$app" ]]; then
    make_app_package "$app"
  else
    echo "⚠️  Skipping $app (not found in config/common)"
  fi
done

# ------------------ stow ------------------
echo
echo "Running stow…"
cd "$STOW_DIR"
stow "${APPS[@]}"

echo
echo "✔ Dotfiles installed successfully"

