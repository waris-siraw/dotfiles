#!/bin/bash

# --- Configuration Variables ---
DOTFILES_ROOT=$(pwd) 
STOW_TARGET="$HOME"
# Path to the system backgrounds folder
SYSTEM_BG_DIR="/usr/share/backgrounds"

# Define the directory where package lists are stored
PACKAGES_DIR="$DOTFILES_ROOT/dotfiles/packages"
# Path to your specific Gruvbox image
BG_IMAGE_SRC="$DOTFILES_ROOT/dotfiles/images/Grv_box.png"

# Package files with .pacman extension
COMMON_PACMAN="$PACKAGES_DIR/common.pacman"
DESKTOP_PACMAN="$PACKAGES_DIR/desktop.pacman"
LAPTOP_PACMAN="$PACKAGES_DIR/laptop.pacman"

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
            1 ) DEVICE_TYPE="desktop"; break;;
            2 ) DEVICE_TYPE="laptop"; break;;
            * ) echo "Invalid choice. Please enter 1 or 2.";;
        esac
    done
}

# --- 1. Package Installation ---

install_packages() {
    log "Checking for GNU Stow..."
    if ! command -v stow &> /dev/null; then
        sudo pacman -S --noconfirm stow || { error "Failed to install Stow. Exiting."; exit 1; }
    fi
    
    log "Updating package database..."
    sudo pacman -Syu --noconfirm || error "Database update failed. Proceeding anyway."

    PACKAGES_TO_INSTALL=""
    
    # Collect Common Packages
    if [ -f "$COMMON_PACMAN" ]; then
        log "Adding common packages from $COMMON_PACMAN..."
        PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$COMMON_PACMAN" | xargs) "
    fi

    # Collect Device-Specific Packages
    if [ "$DEVICE_TYPE" = "desktop" ] && [ -f "$DESKTOP_PACMAN" ]; then
        log "Adding DESKTOP packages from $DESKTOP_PACMAN..."
        PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$DESKTOP_PACMAN" | xargs)"
    elif [ "$DEVICE_TYPE" = "laptop" ] && [ -f "$LAPTOP_PACMAN" ]; then
        log "Adding LAPTOP packages from $LAPTOP_PACMAN..."
        PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$LAPTOP_PACMAN" | xargs)"
    fi
    
    # Execute batch installation
    if [ -n "$(echo $PACKAGES_TO_INSTALL | xargs)" ]; then
        log "Installing all selected packages..."
        sudo pacman -S --needed --noconfirm $PACKAGES_TO_INSTALL || error "Some packages failed to install."
    else
        log "No packages found for installation."
    fi
}

# --- 2. Background Setup ---

setup_backgrounds() {
    log "Setting up system background directory..."
    
    # Create the backgrounds directory if it doesn't exist
    if [ ! -d "$SYSTEM_BG_DIR" ]; then
        log "Creating $SYSTEM_BG_DIR (requires sudo)..."
        sudo mkdir -p "$SYSTEM_BG_DIR"
    fi

    # Check if the Gruvbox image exists in your repo
    if [ -f "$BG_IMAGE_SRC" ]; then
        log "Linking Grv_box.png to system backgrounds..."
        # Create a symbolic link in the system folder pointing to your repo
        sudo ln -snf "$BG_IMAGE_SRC" "$SYSTEM_BG_DIR/Grv_box.png"
    else
        error "Background image not found at $BG_IMAGE_SRC. Skipping link."
    fi
}

# --- 3. Shell Management (Fish) ---

setup_fish_shell() {
    log "Checking Fish shell configuration..."
    
    if ! command -v fish &> /dev/null; then
        log "Fish not found. Installing..."
        sudo pacman -S --noconfirm fish
    fi

    FISH_PATH=$(which fish)

    # Change default shell if it's not already Fish
    if [[ "$SHELL" != "$FISH_PATH" ]]; then
        log "Setting Fish as the default shell..."
        
        # Ensure fish is in /etc/shells
        if ! grep -q "$FISH_PATH" /etc/shells; then
            echo "$FISH_PATH" | sudo tee -a /etc/shells
        fi
        
        sudo chsh -s "$FISH_PATH" "$USER"
        log "Shell updated to Fish. Changes apply after next login."
    else
        log "Fish is already your default shell."
    fi
}

# --- 4. Dotfiles Symlinking with Stow ---

stow_dotfiles() {
    log "Starting symlink creation with GNU Stow..."
    
    # Navigate to the dotfiles directory relative to script location
    cd "$DOTFILES_ROOT/dotfiles" || { error "Could not find 'dotfiles' subdirectory."; exit 1; }

    # Step 1: Stow root level directories (e.g., zsh, nvim, tmux)
    log "Stowing root packages..."
    ROOT_PACKAGES=$(find . -maxdepth 1 -mindepth 1 -type d \
        -not -name '.*' -not -name 'packages' -not -name 'config' -not -name 'images' \
        -exec basename {} \;)
    
    for package in $ROOT_PACKAGES; do
        log "Stowing: $package"
        # --adopt helps integrate existing files by moving them into the repo
        stow -d . -t "$STOW_TARGET" -v -R --adopt "$package"
    done

    # Step 2: Stow nested config packages (common, desktop, laptop)
    if [ -d "config" ]; then
        log "Stowing nested configurations..."
        cd "config" || { error "Failed to enter config directory."; cd ..; exit 1; }
        
        declare -a CONDITIONAL_PACKAGES=("common")
        [ "$DEVICE_TYPE" = "desktop" ] && CONDITIONAL_PACKAGES+=("desktop")
        [ "$DEVICE_TYPE" = "laptop" ] && CONDITIONAL_PACKAGES+=("laptop")
        
        for package in "${CONDITIONAL_PACKAGES[@]}"; do
            if [ -d "$package" ]; then
                log "Stowing conditional package: $package"
                stow -d . -t "$STOW_TARGET" -v -R --adopt "$package"
            fi
        done
        cd ..
    fi

    log "Finished stowing. Returning to root."
    cd "$DOTFILES_ROOT"
}

# --- 5. Post-Stow Actions ---

nvim_plugin_install() {
    if command -v nvim &> /dev/null; then
        log "Running Neovim plugin installation..."
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

    prompt_device_type
    
    install_packages
    
    setup_fish_shell
    
    setup_backgrounds
    
    stow_dotfiles
    
    nvim_plugin_install
    
    log "\n✅ Installation complete!"
    log "Note: Your background is linked at: $SYSTEM_BG_DIR/Grv_box.png"
    log "Please log out and back in to start using Fish by default."
}

main
