#!/bin/bash

# root 권한 체크
if [ "$EUID" -ne 0 ]; then
  echo "[!] 이 스크립트는 root 권한으로 실행해야 합니다. (sudo ./masp.sh)"
  exit 1
fi

NEW_SIZE="32G"

echo "=========================================="
echo "    /tmp (tmpfs) 용량 $NEW_SIZE 변경 스크립트"
echo "=========================================="

# 1. /etc/fstab에 /tmp 항목 적용/수정
if grep -q "[[:space:]]/tmp[[:space:]]" /etc/fstab; then
  # 기존 /tmp 설정이 fstab에 존재하는 경우 size 옵션 업데이트
  sed -i -E "s|([[:space:]]/tmp[[:space:]]+tmpfs[[:space:]]+defaults,size=)[^[:space:]]+|\1$NEW_SIZE|" /etc/fstab
  sed -i -E "s|([[:space:]]/tmp[[:space:]]+tmpfs[[:space:]]+[^[:space:]]*size=)[^[:space:]]+|\1$NEW_SIZE|" /etc/fstab
else
  # 기존 설정이 없을 경우 fstab 맨 아래에 추가
  echo "tmpfs   /tmp    tmpfs   defaults,noatime,mode=1777,size=$NEW_SIZE   0 0" >> /etc/fstab
fi

# 2. 재부팅 없이 마운트 옵션 즉시 재적용
mount -o remount,size=$NEW_SIZE /tmp

if [ $? -eq 0 ]; then
  echo "[+] /tmp 용량이 성공적으로 $NEW_SIZE 로 변경되었습니다!"
  echo ""
  echo "[*] 현재 /tmp 용량 상태:"
  df -h /tmp
else
  echo "[!] /tmp 용량 변경 중 오류가 발생했습니다."
fi
