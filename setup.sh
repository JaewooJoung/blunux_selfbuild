#!/bin/bash
# Blunux Self-Build Setup Script
# Downloads the latest Blunux builder from GitHub

set -e

REPO_URL="https://github.com/JaewooJoung/blunux_selfbuild.git"
BRANCH="claude/fix-input-device-drivers-Ktfpc"
DIR_NAME="blunux_selfbuild"

echo "========================================"
echo "  Blunux Self-Build Setup"
echo "========================================"
echo ""

# Check if directory exists
if [ -d "$DIR_NAME" ]; then
    echo "기존 폴더 삭제 중... / Removing existing folder..."
    rm -rf "$DIR_NAME"
fi

# Clone repository
echo "저장소 클론 중... / Cloning repository..."
git clone -b "$BRANCH" "$REPO_URL" "$DIR_NAME"

echo ""
echo "========================================"
echo "  설치 완료! / Setup complete!"
echo "========================================"
echo ""
echo "다음 단계 / Next steps:"
echo ""
echo "  cd $DIR_NAME"
echo "  sudo julia build.jl examples/korean-desktop.toml"
echo ""
