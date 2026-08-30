#!/usr/bin/env bash

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Installing Homebrew..."
    curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" | bash
else
    echo "Homebrew is already installed."
fi
