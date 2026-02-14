#!/bin/bash
# Deploy latest Blunux ISO to Ventoy USB
# Usage: ./deploy_ventoy.sh [ventoy_mount] [iso_dir]

set -e

VENTOY_DIR="${1:-/run/media/crux/Ventoy}"
ISO_DIR="${2:-/run/media/crux/ss4/test/bn2sb/out}"

echo "========================================"
echo "  Blunux ISO → Ventoy 배포"
echo "========================================"
echo ""

# Check Ventoy mount
if [ ! -d "$VENTOY_DIR" ]; then
    echo "오류: Ventoy USB를 찾을 수 없습니다: $VENTOY_DIR"
    echo "Error: Ventoy USB not found at: $VENTOY_DIR"
    exit 1
fi

# Find latest ISO
LATEST_ISO=$(ls -t "$ISO_DIR"/*.iso 2>/dev/null | head -1)

if [ -z "$LATEST_ISO" ]; then
    echo "오류: ISO 파일을 찾을 수 없습니다: $ISO_DIR/"
    echo "Error: No ISO files found in: $ISO_DIR/"
    exit 1
fi

ISO_NAME=$(basename "$LATEST_ISO")
ISO_SIZE=$(du -h "$LATEST_ISO" | cut -f1)

echo "ISO 파일:  $LATEST_ISO"
echo "파일 크기: $ISO_SIZE"
echo "대상:      $VENTOY_DIR/$ISO_NAME"
echo ""

# Remove old Blunux ISOs from Ventoy
OLD_ISOS=$(ls "$VENTOY_DIR"/blunux-*.iso 2>/dev/null || true)
if [ -n "$OLD_ISOS" ]; then
    echo "이전 Blunux ISO 삭제 중... / Removing old Blunux ISOs..."
    rm -v "$VENTOY_DIR"/blunux-*.iso
    echo ""
fi

# Copy new ISO
echo "복사 중... / Copying..."
rsync --progress "$LATEST_ISO" "$VENTOY_DIR/$ISO_NAME"
sync

# Unmount Ventoy USB
echo "USB 마운트 해제 중... / Unmounting Ventoy USB..."
umount "$VENTOY_DIR" 2>/dev/null && echo "USB를 안전하게 제거할 수 있습니다." || echo "마운트 해제 실패 - 수동으로 해제하세요."

echo ""
echo "========================================"
echo "  완료! / Done!"
echo "  $ISO_NAME → Ventoy USB"
echo "  USB를 제거하세요 / Safe to remove USB"
echo "========================================"
