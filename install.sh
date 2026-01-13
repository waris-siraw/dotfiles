#!/bin/bash

# --- Configuration Variables ---
DOTFILES_ROOT=$(pwd)
STOW_TARGET="$HOME"
# Path to the system backgrounds folder
SYSTEM_BG_DIR="/usr/share/backgrounds"

# Define the directory where package lists are stored
PACKAGES_DIR="$DOTFILES_ROOT/dotfiles/packages"
# Path to background
BG_IMAGE_SRC="$DOTFILES_ROOT/dotfiles/images/Grv_box.png"

# Package files
COMMON_PACMAN="$PACKAGES_DIR/common.pacman"
DESKTOP_PACMAN="$PACKAGES_DIR/desktop.pacman"
LAPTOP_PACMAN="$PACKAGES_DIR/laptop.pacman"
AUR_PACMAN="$PACKAGES_DIR/aur.pacman"

# Neovim plugin manager (vim-plug) URL
VIM_PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
# Destination uses XDG standard, falling back to ~/.config
VIM_PLUG_DESTINATION="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/plug.vim"

# --- Logging and Utility Functions ---

log() {
  echo -e "\n\033[1;34m>>> $1\033[0m" # Blue message
}

error() {
  echo -e "\033[1;31m!!! ERROR: $1\033[0m" >&2 # Red message to stderr
}

prompt_device_type() {
  while true; do
    echo -e "\n\033[1;33mWhich device are you configuring?\033[0m"
    echo "1) Desktop"
    echo "2) Laptop"
    read -r -p "Select an option [1-2]: " choice
    case "$choice" in
    1)
      DEVICE_TYPE="desktop"
      break
      ;;
    2)
      DEVICE_TYPE="laptop"
      break
      ;;
    *) echo "Invalid choice. Please enter 1 or 2." ;;
    esac
  done
}

# --- CRITICAL OVERWRITE FUNCTION ---
# This function forces the content of the repository to be linked,
# deleting any conflicting, non-symlinked files/directories in the system.
stow_force_overwrite() {
  local package_name=$1
  local repo_path=$2  # Directory in the repo where the package resides (e.g., dotfiles or dotfiles/config)
  local target_dir=$3 # Destination directory on the system (e.g., $HOME or $HOME/.config)

  log "Handling package: $package_name (FORCING REPOSITORY CONTENT over $target_dir)"

  # 1. Navigate to the package root directory in the repository
  cd "$DOTFILES_ROOT/$repo_path" || {
    error "Could not enter repo path: $repo_path"
    return 1
  }

  # --- FATAL ERROR CHECK FOR DOUBLE .CONFIG ---
  if [ "$target_dir" = "$HOME/.config" ] && [ -d "$package_name/.config" ]; then
    error "!!! FATAL ERROR: DOUBLE .CONFIG DETECTED IN REPOSITORY STRUCTURE !!!"
    error "The package '$package_name' contains an inner '.config' directory ('$package_name/.config')."
    error "This will result in '$HOME/.config/.config'. Please remove the inner '.config' folder from your repository."
    cd "$DOTFILES_ROOT"
    return 1
  fi
  # ----------------------------------------

  log "Current working directory for stow: $(pwd)"
  log "Stow package name: $package_name | Target directory: $target_dir"

  # 2. Unstow any old symbolic links for this package
  log "Unstowing potential old links for $package_name..."
  stow -D -t "$target_dir" -v "$package_name" 2>/dev/null

  # 3. Iterate over all files/folders the package intends to link and remove conflicts
  find "$package_name" -maxdepth 1 -mindepth 1 -not -name '.' | while read -r item; do
    local base_name=$(basename "$item")
    local destination="$target_dir/$base_name"

    # Check if the destination file exists AND IS NOT a symbolic link
    if [ -e "$destination" ] && [ ! -L "$destination" ]; then
      error "NON-LINK CONFLICT DETECTED: $destination. DELETING."
      # Use 'rm -rf' without sudo unless strictly necessary
      rm -rf "$destination" || {
        error "FAILED TO DELETE CONFLICT: $destination. Check permissions!"
        return 1
      }
    fi
  done

  # 4. Execute the final stow
  local stow_command="stow -d . -t \"$target_dir\" -v -R \"$package_name\""
  log "Executing stow command: $stow_command"
  stow -d . -t "$target_dir" -v -R "$package_name"
  local stow_status=$?

  if [ $stow_status -ne 0 ]; then
    error "STOW FAILED for $package_name. Exit code: $stow_status. Check verbose output above."
    cd "$DOTFILES_ROOT"
    return 1
  else
    log "Stow completed for $package_name."
  fi

  # Return to the script's root directory
  cd "$DOTFILES_ROOT"
}

# --- 1. Package Installation (Arch/Pacman) ---

install_packages() {
  log "Checking for GNU Stow..."
  if ! command -v stow &>/dev/null; then
    sudo pacman -S --noconfirm stow || {
      error "Failed to install Stow. Exiting."
      exit 1
    }
  fi

  log "Updating package database..."
  sudo pacman -Syu --noconfirm || error "Database update failed. Proceeding with installation."

  PACKAGES_TO_INSTALL=""

  # Collect Common Packages
  if [ -f "$COMMON_PACMAN" ]; then
    log "Adding common packages from $COMMON_PACMAN..."
    PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$COMMON_PACMAN" | xargs) "
  fi

  # Collect Device-Specific Packages
  if [ "$DEVICE_TYPE" = "desktop" ] && [ -f "$DESKTOP_PACMAN" ]; then
    log "Adding DESKTOP packages from $DESKTOP_PACMAN..."
    PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$DESKTOP_PACMAN" | xargs) "
  elif [ "$DEVICE_TYPE" = "laptop" ] && [ -f "$LAPTOP_PACMAN" ]; then
    log "Adding LAPTOP packages from $LAPTOP_PACMAN..."
    PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$LAPTOP_PACMAN" | xargs) "
  fi

  # Execute batch installation
  if [ -n "$(echo $PACKAGES_TO_INSTALL | xargs)" ]; then
    log "Installing all selected standard packages..."
    sudo pacman -S --needed --noconfirm $PACKAGES_TO_INSTALL || error "Some packages failed to install."
  else
    log "No standard packages found for installation."
  fi
}

# --- 2. AUR Package Installation (Yay) ---

install_aur_packages() {
  log "Checking AUR configuration..."

  # 1. Check if yay is installed. If not, install it.
  if ! command -v yay &>/dev/null; then
    log "Yay not found. Installing yay from AUR..."

    # Ensure git and base-devel are installed (required for building yay)
    log "Installing prerequisites (git, base-devel)..."
    sudo pacman -S --needed --noconfirm git base-devel

    # Clone and build yay in a temp directory
    log "Cloning yay repository..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay || {
      error "Failed to enter /tmp/yay"
      return 1
    }

    log "Building yay..."
    makepkg -si --noconfirm

    # Return to root and clean up
    cd "$DOTFILES_ROOT"
    rm -rf /tmp/yay

    log "Yay installed successfully."
  fi

  # 2. Read aur.pacman and install packages
  if [ -f "$AUR_PACMAN" ]; then
    log "Reading AUR packages from $AUR_PACMAN..."

    # Read file ignoring comments and empty lines
    AUR_TO_INSTALL=$(grep -vE '^\s*#|^\s*$' "$AUR_PACMAN" | xargs)

    if [ -n "$AUR_TO_INSTALL" ]; then
      log "Installing AUR packages: $AUR_TO_INSTALL"
      # NOTE: Do NOT use sudo with yay
      yay -S --needed --noconfirm $AUR_TO_INSTALL || error "Failed to install some AUR packages."
    else
      log "No packages found in aur.pacman."
    fi
  else
    log "No aur.pacman file found at $AUR_PACMAN. Skipping AUR."
  fi
}

# --- 3. Background Setup ---

setup_backgrounds() {
  log "Setting up system background directory..."

  if [ ! -d "$SYSTEM_BG_DIR" ]; then
    log "Creating $SYSTEM_BG_DIR (requires sudo)..."
    sudo mkdir -p "$SYSTEM_BG_DIR"
  fi

  if [ -f "$BG_IMAGE_SRC" ]; then
    log "Linking Grv_box.png to system backgrounds..."
    sudo ln -snf "$BG_IMAGE_SRC" "$SYSTEM_BG_DIR/Grv_box.png"
  else
    error "Background image not found at $BG_IMAGE_SRC. Skipping link."
  fi
}

# --- 4. Shell Management (Fish) ---

setup_fish_shell() {
  log "Checking Fish shell configuration..."

  if ! command -v fish &>/dev/null; then
    log "Fish not found. Assuming it was or will be installed via pacman."
    return
  fi

  FISH_PATH=$(which fish)

  if [[ "$SHELL" != "$FISH_PATH" ]]; then
    log "Setting Fish as the default shell..."

    if ! grep -q "$FISH_PATH" /etc/shells; then
      log "Adding Fish path to /etc/shells..."
      echo "$FISH_PATH" | sudo tee -a /etc/shells
    fi

    sudo chsh -s "$FISH_PATH" "$USER"
    log "Shell updated to Fish. Changes apply after next login/reboot."
  else
    log "Fish is already your default shell."
  fi
}

# --- 5. Neovim Plugin Manager Installation ---

install_vim_plug_manager() {
  log "Installing vim-plug manager..."
  if ! command -v nvim &>/dev/null; then
    log "Neovim not installed. Skipping vim-plug setup."
    return
  fi

  log "Installing vim-plug at $VIM_PLUG_DESTINATION"
  mkdir -p "$(dirname "$VIM_PLUG_DESTINATION")"
  if ! command -v curl &>/dev/null; then
    error "Curl not found. Cannot download vim-plug."
    return
  fi

  if ! curl -fLo "$VIM_PLUG_DESTINATION" --create-dirs "$VIM_PLUG_URL"; then
    error "Failed to install vim-plug manager."
  fi
}

# --- 6. Dotfiles Symlinking with Stow (Main Logic) ---

stow_dotfiles() {
  log "Starting symlink creation with GNU Stow (OVERWRITE MODE)..."

  # Step 1: Stow root level directories (e.g., zsh, nvim, tmux)
  log "Stowing root packages (targeting \$HOME)..."
  # The package root for these is "dotfiles"
  ROOT_PACKAGES=$(find "$DOTFILES_ROOT/dotfiles" -maxdepth 1 -mindepth 1 -type d \
    -not -name '.*' -not -name 'packages' -not -name 'config' -not -name 'images' \
    -exec basename {} \;)

  for package in $ROOT_PACKAGES; do
    stow_force_overwrite "$package" "dotfiles" "$STOW_TARGET" || return 1
  done

  # Step 2: Stow nested config packages
  if [ -d "$DOTFILES_ROOT/dotfiles/config" ]; then
    log "Stowing nested configurations (targeting \$HOME/.config)"

    # The package root for these is "dotfiles/config"
    REPO_CONFIG_PATH="dotfiles/config"
    CONFIG_TARGET_PATH="$STOW_TARGET/.config"

    # Base configuration packages
    declare -a CONFIG_PACKAGES=("common")

    # Add the device-specific configuration (which holds i3/i3blocks)
    if [ "$DEVICE_TYPE" = "desktop" ] && [ -d "$DOTFILES_ROOT/$REPO_CONFIG_PATH/desktop" ]; then
      CONFIG_PACKAGES+=("desktop")
    elif [ "$DEVICE_TYPE" = "laptop" ] && [ -d "$DOTFILES_ROOT/$REPO_CONFIG_PATH/laptop" ]; then
      CONFIG_PACKAGES+=("laptop")
    fi

    for package in "${CONFIG_PACKAGES[@]}"; do
      if [ -d "$DOTFILES_ROOT/$REPO_CONFIG_PATH/$package" ]; then
        # Link packages (like 'laptop' or 'desktop') directly to $HOME/.config
        stow_force_overwrite "$package" "$REPO_CONFIG_PATH" "$CONFIG_TARGET_PATH" || return 1
      fi
    done
  fi

  log "Finished stowing."
}

# --- 7. Neovim Plugin Installation ---

install_nvim_plugins() {
  if command -v nvim &>/dev/null; then
    log "Running Neovim plugin installation (Requires stowed configuration)..."
    # The Nvim configuration must be stowed by now for PlugInstall to work
    nvim --headless +PlugInstall +qall
  else
    log "Neovim not installed. Skipping plugins."
  fi
}

# --- Main Execution ---

main() {
  # Greeting
  echo -e "\033[1;35m"
  echo "##########################"
  echo "#      Hello, Waris!     #"
  echo "##########################"
  echo -e "\033[0m"

  log "!!! WARNING !!! This mode WILL OVERWRITE ALL existing system configurations that conflict with your dotfiles."

  prompt_device_type

  # Handle the previous failed stow path if it exists
  if [ -d "$HOME/.config/.config" ]; then
    error "Previous failed stow path detected. Removing $HOME/.config/.config."
    rm -rf "$HOME/.config/.config"
  fi

  # 1. Standard Pacman Install
  install_packages || return 1

  # 2. AUR/Yay Install (NEW)
  install_aur_packages

  install_vim_plug_manager

  setup_fish_shell
  setup_backgrounds

  stow_dotfiles || {
    error "Stow failed. Check your repository structure."
    return 1
  }

  install_nvim_plugins

  log "\n✅ Installation complete!"
  log "To finalize the installation and integrate essential components (like the i3 window manager), a **system reboot is required**."
}

# Run the main function
main
