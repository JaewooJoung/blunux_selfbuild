#!/bin/bash

# root 권한 체크
if [ "$EUID" -ne 0 ]; then
  echo "[!] 이 스크립트는 root 권한으로 실행해야 합니다. (sudo ./mkvt.sh)"
  exit 1
fi

echo "=========================================="
echo "      Ventoy USB 생성 스크립트"
echo "=========================================="

# 시스템에 연결된 USB 이동식 디바이스 목록 출력
echo "[*] 감지된 USB 드라이브 목록:"
echo "------------------------------------------"
lsblk -d -n -o NAME,SIZE,MODEL,TRAN | grep "usb"
echo "------------------------------------------"

# 디바이스명 입력 받기 (예: sdb)
read -p "[?] Ventoy를 설치할 USB 장치명을 입력하세요 (예: sdb): " DEV_NAME

# 입력값 검증
if [ -z "$DEV_NAME" ]; then
  echo "[!] 장치명이 입력되지 않았습니다. 종료합니다."
  exit 1
fi

TARGET_DEV="/dev/$DEV_NAME"

# 장치 존재 여부 확인
if [ ! -b "$TARGET_DEV" ]; then
  echo "[!] $TARGET_DEV 장치를 찾을 수 없습니다. 장치명을 확인해 주세요."
  exit 1
fi

# 최종 경고 및 확인
echo ""
echo "=========================================="
echo " [경고] $TARGET_DEV 의 모든 데이터가 삭제됩니다!"
echo "=========================================="
read -p "[?] 정말 진행하시겠습니까? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "[*] Ventoy 설치를 시작합니다..."
  
  # Arch Linux 공식 ventoy 패키지 실행 명령
  ventoy -i "$TARGET_DEV"
  
  if [ $? -eq 0 ]; then
    echo "[+] Ventoy 설치가 성공적으로 완료되었습니다!"
  else
    echo "[!] Ventoy 설치 중 오류가 발생했습니다."
  fi
else
  echo "[*] 작업을 취소했습니다."
  exit 0
fi
