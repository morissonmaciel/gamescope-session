#!/bin/bash

# Check if git is installed
if ! command -v git &>/dev/null; then
    echo "Git is not installed. Installing..."
    # Install git
    if ! sudo zypper in git-core; then
        echo "Failed to install Git."
        exit 1
    fi
fi

# Define repository URL
repo_url="https://github.com/morissonmaciel/gamescope-session.git"

# Remove existing setup folder
rm -rf "$HOME/.gamescope-setup"

# Clone the repository into $HOME/.gamescope-setup
if ! git clone "$repo_url" "$HOME/.gamescope-setup"; then
    echo "Cloning failed. Downloading zip archive..."
    # Download zip archive
    if ! wget -O "$HOME/.gamescope-setup/archive.zip" "https://github.com/morissonmaciel/gamescope-session/archive/refs/tags/v0.11.zip"; then
        echo "Failed to download zip archive."
        exit 1
    fi
    # Unzip the archive
    if ! unzip "$HOME/.gamescope-setup/archive.zip" -d "$HOME/.gamescope-setup"; then
        echo "Failed to unzip archive."
        exit 1
    fi
    # Clean up the zip file
    if ! rm "$HOME/.gamescope-setup/archive.zip"; then
        echo "Failed to clean up zip file."
        exit 1
    fi
fi

# Navigate into the cloned repository folder
if ! cd "$HOME/.gamescope-setup"; then
    echo "Failed to navigate to the cloned repository folder."
    exit 1
fi

# Give setup.sh execute permission
chmod +x setup.sh
