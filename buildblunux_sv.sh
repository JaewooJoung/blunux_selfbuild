#!/bin/bash
# Blunux Svenska ISO-byggare
# Swedish ISO Builder

set -e

REPO_URL="https://github.com/JaewooJoung/blunux_selfbuild.git"
BRANCH="main"
DIR_NAME="blunux_selfbuild"
CONFIG_FILE="config_sv.toml"

echo "========================================"
echo "  Blunux Svenska ISO-byggare"
echo "  Swedish ISO Builder"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Root-privilegier krävs. Kör med sudo."
    echo "Root privileges required. Please run with sudo."
    exit 1
fi

# Remove existing directory
if [ -d "$DIR_NAME" ]; then
    echo "Tar bort befintlig mapp... / Removing existing folder..."
    rm -rf "$DIR_NAME"
fi

# Clone repository
echo "Klonar repository... / Cloning repository..."
git clone -b "$BRANCH" "$REPO_URL" "$DIR_NAME"

# Enter directory and build
cd "$DIR_NAME"

echo ""
echo "Startar svensk ISO-byggning..."
echo "Starting Swedish ISO build..."
echo ""

julia build.jl "$CONFIG_FILE"

echo ""
echo "========================================"
echo "  Klart! / Done!"
echo "========================================"
