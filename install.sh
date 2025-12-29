#!/bin/bash

# --- Configuration Variables ---
DOTFILES_ROOT=$(pwd) 
STOW_TARGET="$HOME"

# Define the directory where package lists are stored
PACKAGES_DIR="$DOTFILES_ROOT/dotfiles/packages"

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
    
    # Add Common Packages
    if [ -f "$COMMON_PACMAN" ]; then
        log "Adding common packages from $COMMON_PACMAN..."
        PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$COMMON_PACMAN" | xargs) "
    fi

    # Add Device-Specific Packages
    if [ "$DEVICE_TYPE" = "desktop" ] && [ -f "$DESKTOP_PACMAN" ]; then
        log "Adding DESKTOP packages from $DESKTOP_PACMAN..."
        PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$DESKTOP_PACMAN" | xargs)"
    elif [ "$DEVICE_TYPE" = "laptop" ] && [ -f "$LAPTOP_PACMAN" ]; then
        log "Adding LAPTOP packages from $LAPTOP_PACMAN..."
        PACKAGES_TO_INSTALL+="$(grep -vE '^\s*#|^\s*$' "$LAPTOP_PACMAN" | xargs)"
    fi
    
    # Execute single installation command
    if [ -n "$(echo $PACKAGES_TO_INSTALL | xargs)" ]; then
        log "Installing all selected packages..."
        sudo pacman -S --needed --noconfirm $PACKAGES_TO_INSTALL || error "Some packages failed to install."
    else
        log "No packages found for installation."
    fi
}

# --- 2. Shell Management (Fish) ---

setup_fish_shell() {
    log "Configuring Fish shell..."
    
    # Ensure fish is installed (it should be in your common.pacman, but this is a safety check)
    if ! command -v fish &> /dev/null; then
        log "Fish not found. Installing now..."
        sudo pacman -S --noconfirm fish
    fi

    FISH_PATH=$(which fish)

    # Check if Fish is already the default shell
    if [[ "$SHELL" != "$FISH_PATH" ]]; then
        log "Setting Fish as the default shell..."
        
        # Add Fish to /etc/shells if not already present
        if ! grep -q "$FISH_PATH" /etc/shells; then
            echo "$FISH_PATH" | sudo tee -a /etc/shells
        fi
        
        # Change shell for the current user
        sudo chsh -s "$FISH_PATH" "$USER"
        log "Default shell changed to $FISH_PATH"
    else
        log "Fish is already your default shell."
    fi
}

# --- 3. Dotfiles Symlinking with Stow ---

stow_dotfiles() {
    log "Starting symlink creation with GNU Stow..."
    cd "$DOTFILES_ROOT/dotfiles" || { error "Could not find 'dotfiles' directory."; exit 1; }

    # Step 1: Stow root level directories (zsh, tmux, nvim, etc.)
    log "Stowing root packages..."
    ROOT_PACKAGES=$(find . -maxdepth 1 -mindepth 1 -type d \
        -not -name '.*' -not -name 'packages' -not -name 'config' -not -name 'images' \
        -exec basename {} \;)
    
    for package in $ROOT_PACKAGES; do
        log "Stowing: $package"
        stow -d . -t "$STOW_TARGET" -v -R --adopt "$package"
    done

    # Step 2: Stow nested config packages
    if [ -d "config" ]; then
        log "Stowing conditional configs from config/..."
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

    log "Stowing finished. Returning to repository root."
    cd "$DOTFILES_ROOT"
}

# --- 4. Post-Stow Actions ---

nvim_plugin_install() {
    if command -v nvim &> /dev/null; then
        log "Installing Neovim plugins..."
        nvim --headless +PlugInstall +qall
    else
        log "Neovim not found. Skipping plugin installation."
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
    
    stow_dotfiles
    
    nvim_plugin_install
    
    log "\n✅ Configuration completed successfully!"
    log "Please log out and log back in (or restart) to apply the shell changes."
}

main
