#!/bin/bash
# Blunux ISO Builder
# Downloads latest code and builds ISO

set -e

REPO_URL="https://github.com/JaewooJoung/blunux_selfbuild.git"
BRANCH="main"
DIR_NAME="blunux_selfbuild"
CONFIG_FILE="config.toml"

echo "========================================"
echo "  Blunux ISO Builder"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "루트 권한이 필요합니다. sudo로 실행하세요."
    echo "Root privileges required. Please run with sudo."
    exit 1
fi

# Remove existing directory
if [ -d "$DIR_NAME" ]; then
    echo "기존 폴더 삭제 중... / Removing existing folder..."
    rm -rf "$DIR_NAME"
fi

# Clone repository
echo "저장소 클론 중... / Cloning repository..."
git clone -b "$BRANCH" "$REPO_URL" "$DIR_NAME"

# Enter directory and build
cd "$DIR_NAME"

# Check if config file exists, if not use example
if [ ! -f "$CONFIG_FILE" ]; then
    echo "config.toml이 없습니다. 예시 파일을 사용합니다."
    echo "config.toml not found. Using example file."
    cp examples/korean-desktop.toml "$CONFIG_FILE"
fi

echo ""
echo "ISO 빌드 시작... / Starting ISO build..."
echo ""

julia build.jl "$CONFIG_FILE"

echo ""
echo "========================================"
echo "  완료! / Done!"
echo "========================================"
