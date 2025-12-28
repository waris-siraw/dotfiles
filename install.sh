#!/bin/bash

# --- Configuration Variables ---
# Assumes the script is run from the repository root
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
    sudo pacman -Syu --noconfirm || error "Database update failed. Proceeding with installation."

    PACKAGES_TO_INSTALL=""
    
    # 1. Common Packages (Always)
    if [ -f "$COMMON_PACMAN" ]; then
        log "Adding common packages from $COMMON_PACMAN."
        # Use grep to filter out comments and empty lines
        PACKAGES_TO_INSTALL+=" $(grep -vE '^\s*#|^\s*$' "$COMMON_PACMAN" | xargs)"
    else
        log "File $COMMON_PACMAN not found in $PACKAGES_DIR. Skipping common package installation."
    fi

    # 2. Specific Packages (Conditional)
    if [ "$DEVICE_TYPE" = "desktop" ] && [ -f "$DESKTOP_PACMAN" ]; then
        log "Adding DESKTOP-specific packages from $DESKTOP_PACMAN."
        PACKAGES_TO_INSTALL+=" $(grep -vE '^\s*#|^\s*$' "$DESKTOP_PACMAN" | xargs)"
    elif [ "$DEVICE_TYPE" = "laptop" ] && [ -f "$LAPTOP_PACMAN" ]; then
        log "Adding LAPTOP-specific packages from $LAPTOP_PACMAN."
        PACKAGES_TO_INSTALL+=" $(grep -vE '^\s*#|^\s*$' "$LAPTOP_PACMAN" | xargs)"
    else
        log "No specific package list found for $DEVICE_TYPE (expected in $PACKAGES_DIR). Skipping this phase."
    fi
    
    # 3. Execute Installation
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        log "Installing total packages..."
        sudo pacman -S --needed --noconfirm $PACKAGES_TO_INSTALL || error "Pacman package installation failed for some packages."
    else
        log "No packages found for installation."
    fi
}

# --- 2. Dotfiles Symlinking with Stow (Double Stowing Logic) ---

stow_dotfiles() {
    log "Starting symbolic link creation (symlinks) with GNU Stow..."
    
    # KEY NAVIGATION: Enter the "dotfiles" subdirectory 
    cd "$DOTFILES_ROOT/dotfiles" || { error "Could not find the 'dotfiles' subdirectory. Verify your repository structure."; exit 1; }

    
    # --- STEP 1: STOW ROOT PACKAGES ---
    
    log "Stowing root level packages (e.g., zsh, tmux)..."
    
    # Trova solo le cartelle di primo livello che non iniziano con '.' (es. zsh, tmux)
    ROOT_PACKAGES=$(find . -maxdepth 1 -mindepth 1 -type d \
        -not -name '.*' \
        -not -name 'packages' \
        -not -name 'config' \
        -not -name 'images' \
        -exec basename {} \;)
    
    if [ -z "$ROOT_PACKAGES" ]; then
        log "No root packages found to stow (excluding images/config/packages)."
    fi

    for package in $ROOT_PACKAGES; do
        log "Stowing root package: $package"
        # -R: Restow (sovrascrive link esistenti)
        # --adopt: Adotta file preesistenti nel pacchetto, poi crea il link
        stow -d . -t "$STOW_TARGET" -v -R --adopt "$package"
        if [ $? -ne 0 ]; then
            error "Stow failed for root package $package."
        fi
    done


    # --- STEP 2: STOW NESTED CONFIG PACKAGES (common, desktop, laptop) ---
    
    if [ -d "config" ]; then
        log "Stowing conditional config packages (common, desktop, laptop)..."
        
        # Navigate INTO the config folder.
        cd "config" || { error "Failed to enter config directory."; cd ..; exit 1; }
        
        # Ordine: 'common' per primo, 'desktop' (specifico) per secondo per garantire la priorità.
        declare -a CONDITIONAL_PACKAGES=("common")
        
        if [ "$DEVICE_TYPE" = "desktop" ] && [ -d "desktop" ]; then
            CONDITIONAL_PACKAGES+=("desktop")
        elif [ "$DEVICE_TYPE" = "laptop" ] && [ -d "laptop" ]; then
            CONDITIONAL_PACKAGES+=("laptop")
        fi
        
        # Iterate over the packages to be stowed from the 'config/' directory
        for package in "${CONDITIONAL_PACKAGES[@]}"; do
            if [ -d "$package" ]; then
                log "Stowing conditional package: $package"
                # Usa --adopt per risolvere conflitti con file non gestiti da Stow
                stow -d . -t "$STOW_TARGET" -v -R --adopt "$package"
                if [ $? -ne 0 ]; then
                    error "Stow failed for conditional package $package. Check your internal directory structure (must be .config/app/) or if you have duplicate configurations (e.g., i3 in both common and desktop)."
                fi
            else
                 error "Conditional package directory '$package' not found in config/."
            fi
        done
        
        # Go back up to dotfiles/ directory
        cd ..
    fi

    log "Finished stowing. Returning to repository root."
    cd "$DOTFILES_ROOT"
}

# --- Main Execution ---
main() {
    log "Starting automated Dotfiles configuration"
    
    prompt_device_type
    
    install_packages

    stow_dotfiles
    
    log "\n✅ Configuration completed!"
    log "To apply changes (e.g., Zsh config, if used), you might need to restart your shell (e.g., 'exec zsh') or your graphical system."
}

# Execute the main function
main
