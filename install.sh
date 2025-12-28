#!/bin/bash

# --- Configuration Variables ---
# DOTFILES_ROOT is the repository root (where the script is executed)
DOTFILES_ROOT=$(pwd) 
STOW_TARGET="$HOME"

# Package files
COMMON_PACMAN="$DOTFILES_ROOT/.pacman.common"
DESKTOP_PACMAN="$DOTFILES_ROOT/.pacman.desktop"
LAPTOP_PACMAN="$DOTFILES_ROOT/.pacman.laptop"
# AUR files can also be added here (.aur.common, etc.)

# --- Logging and Utility Functions ---

log() {
    echo -e "\n\033[1;34m>>> $1\033[0m" # Message in blue
}

error() {
    echo -e "\033[1;31m!!! ERROR: $1\033[0m" >&2 # Error message in red to stderr
}

prompt_device_type() {
    while true; do
        echo -e "\n\033[1;33mWhich device are you installing on?\033[0m"
        read -r -p "Type [d] for Desktop or [l] for Laptop: " choice
        case "$choice" in
            [Dd]* ) DEVICE_TYPE="desktop"; break;;
            [Ll]* ) DEVICE_TYPE="laptop"; break;;
            * ) echo "Invalid choice. Please try again.";;
        esac
    done
}

# --- 1. Package Installation (Common + Specific) ---

install_packages() {
    log "Checking for and installing GNU Stow..."
    if ! command -v stow &> /dev/null; then
        sudo pacman -S --noconfirm stow || { error "Failed to install GNU Stow. Exiting."; exit 1; }
    fi
    
    log "Updating package database..."
    sudo pacman -Syu --noconfirm || { error "Update failed."; exit 1; }

    PACKAGES_TO_INSTALL=""
    
    # 1. Common Packages (Always)
    if [ -f "$COMMON_PACMAN" ]; then
        log "Adding common packages from $COMMON_PACMAN."
        PACKAGES_TO_INSTALL+=" $(grep -vE '^\s*#|^\s*$' "$COMMON_PACMAN" | xargs)"
    else
        error "File $COMMON_PACMAN not found."
    fi

    # 2. Specific Packages (Conditional)
    if [ "$DEVICE_TYPE" = "desktop" ] && [ -f "$DESKTOP_PACMAN" ]; then
        log "Adding DESKTOP-specific packages from $DESKTOP_PACMAN."
        PACKAGES_TO_INSTALL+=" $(grep -vE '^\s*#|^\s*$' "$DESKTOP_PACMAN" | xargs)"
    elif [ "$DEVICE_TYPE" = "laptop" ] && [ -f "$LAPTOP_PACMAN" ]; then
        log "Adding LAPTOP-specific packages from $LAPTOP_PACMAN."
        PACKAGES_TO_INSTALL+=" $(grep -vE '^\s*#|^\s*$' "$LAPTOP_PACMAN" | xargs)"
    fi
    
    # 3. Execute Installation
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        log "Installing total packages..."
        sudo pacman -S --needed --noconfirm $PACKAGES_TO_INSTALL || error "Pacman package installation failed."
    else
        log "No packages found for installation."
    fi
    
    # [Optional] Add logic for AUR files here (.aur.common, etc.)
}

# --- 2. Dotfiles Symlinking with Stow (Common + Specific) ---

stow_dotfiles() {
    log "Starting symbolic link creation (symlinks) with GNU Stow..."
    
    # *** KEY NAVIGATION ***
    # Enter the "dotfiles" subdirectory which contains the Stow packages (your configs)
    cd "$DOTFILES_ROOT/dotfiles" || { error "Could not find the 'dotfiles' subdirectory in $DOTFILES_ROOT"; exit 1; }

    # Array of Stow packages to install
    declare -a PACKAGES_TO_STOW=("common")
    
    # Add the specific package (desktop or laptop)
    if [ "$DEVICE_TYPE" = "desktop" ]; then
        PACKAGES_TO_STOW+=("desktop")
    elif [ "$DEVICE_TYPE" = "laptop" ]; then
        PACKAGES_TO_STOW+=("laptop")
    fi
    
    if [ ${#PACKAGES_TO_STOW[@]} -eq 0 ]; then
        error "No packages defined for stowing."
        return
    fi
    
    for package in "${PACKAGES_TO_STOW[@]}"; do
        if [ -d "$package" ]; then
            log "Stowing package: $package ($package configuration)"
            # -d . tells Stow to look in the current directory (i.e., dotfiles/)
            stow -d . -t "$STOW_TARGET" -v -R "$package"
            if [ $? -ne 0 ]; then
                error "Stow failed for package $package. Check for conflicts in $STOW_TARGET (e.g., an existing file)."
            fi
        else
            error "Stow package directory '$package' was not found in $(pwd)."
        fi
    done
    
    # Return to the repository root directory
    cd "$DOTFILES_ROOT"
}

# --- Main Execution ---
main() {
    log "Starting automated Dotfiles configuration"
    
    # 0. Ask for device type
    prompt_device_type

    # 1. Install packages (Common + Specific)
    install_packages

    # 2. Link Dotfiles (Common + Specific)
    stow_dotfiles
    
    log "\n✅ Configuration completed!"
    log "To apply changes (e.g., Zsh config), you might need to restart your shell (e.g., 'exec zsh') or your graphical system."
}

# Execute the main function
main
