# Blunux 셀프빌드 - 나만의 Linux 만들기

> 컴퓨터 초보자도 따라할 수 있는 완전 가이드

---

## 이게 뭔가요?

**Blunux**는 Arch Linux를 기반으로 한 나만의 Linux 운영체제를 만드는 도구입니다.

이 가이드를 따라하면:
- 한글이 기본으로 설정된 Linux ISO 파일을 만들 수 있어요
- USB에 담아서 어떤 컴퓨터에서든 설치할 수 있어요
- 원하는 프로그램을 미리 포함시킬 수 있어요

---

## 목차

1. [준비하기](#1-준비하기)
2. [필요한 프로그램 설치](#2-필요한-프로그램-설치)
3. [Blunux 다운로드](#3-blunux-다운로드)
4. [ISO 만들기](#4-iso-만들기)
5. [USB에 굽기](#5-usb에-굽기)
6. [컴퓨터에 설치하기](#6-컴퓨터에-설치하기)
7. [문제가 생겼을 때](#7-문제가-생겼을-때)

---

## 1. 준비하기

### 필요한 것들

| 항목 | 설명 |
|------|------|
| **컴퓨터** | Arch Linux, Manjaro, 또는 EndeavourOS가 설치된 컴퓨터 |
| **인터넷** | 패키지 다운로드를 위해 필요 |
| **저장공간** | 최소 20GB 이상의 여유 공간 |
| **USB** | 설치용 USB를 만들려면 8GB 이상 |

### Linux가 없어요!

Arch Linux 계열 운영체제가 없다면:
1. VirtualBox나 VMware에서 [Manjaro](https://manjaro.org/download/)를 먼저 설치하세요
2. 또는 다른 컴퓨터에서 [EndeavourOS](https://endeavouros.com/)를 USB로 부팅해서 사용하세요

---

## 2. 필요한 프로그램 설치

### 2-1. 터미널 열기

키보드에서 `Ctrl + Alt + T`를 누르면 터미널이 열립니다.

검은 화면에 글자를 입력할 수 있는 창이 뜨면 성공!

### 2-2. 시스템 업데이트

아래 명령어를 **한 줄씩** 복사해서 터미널에 붙여넣고 `Enter`를 누르세요.

```bash
sudo pacman -Syu
```

**설명:**
- `sudo` = 관리자 권한으로 실행
- `pacman` = Arch Linux의 프로그램 설치 도구
- `-Syu` = 시스템 전체 업데이트

**비밀번호를 물어보면:** 로그인할 때 사용하는 비밀번호를 입력하세요 (입력해도 화면에 안 보이는 게 정상입니다)

**[Y/n] 물어보면:** `Y`를 누르고 `Enter`

### 2-3. 필수 도구 설치

```bash
sudo pacman -S archiso base-devel git cmake --needed
```

**설명:**
- `archiso` = ISO 파일을 만드는 도구
- `base-devel` = 프로그램 빌드에 필요한 기본 도구들
- `git` = 코드를 다운로드하는 도구
- `cmake` = C++ 프로그램 빌드 도구

### 2-4. Julia 설치

Julia는 이 빌드 도구를 실행하는 프로그래밍 언어입니다.

```bash
curl -fsSL https://install.julialang.org | sh
```

**실행 후:**
1. 여러 질문이 나오면 그냥 `Enter`를 계속 누르세요 (기본값 사용)
2. 설치가 끝나면 터미널을 **닫았다가 다시 여세요**

### 2-5. 설치 확인

새 터미널에서 확인:

```bash
julia --version
```

`julia version 1.x.x` 같은 메시지가 나오면 성공!

---

## 3. Blunux 다운로드

### 3-1. 프로젝트 다운로드

```bash
git clone https://github.com/JaewooJoung/blunux_selfbuild.git
```

**설명:** GitHub에서 Blunux 소스 코드를 다운로드합니다.

### 3-2. 폴더로 이동

```bash
cd blunux_selfbuild
```

**설명:** `cd` = change directory (폴더 이동)

### 3-3. 확인

```bash
ls
```

아래와 같은 파일들이 보이면 성공:
```
build.jl  config_kr.toml  installer/  src/  README.md ...
```

---

## 4. ISO 만들기

### 4-1. 한국어 ISO 빌드

```bash
sudo julia build.jl config_kr.toml
```

**이 명령어를 실행하면:**

```
╔══════════════════════════════════════════════════════════╗
║           Blunux Self-Build Tool v1.0.0                  ║
║        Build your custom Arch-based Linux ISO            ║
╚══════════════════════════════════════════════════════════╝

[*] Blunux 빌드 시작: blunux-korean
    작업 디렉토리: /home/user/blunux_selfbuild/work
    출력 디렉토리: /home/user/blunux_selfbuild/out

[0/13] C++ 인스톨러 빌드 중...
    Configuring CMake...
    Compiling installer...
    [✓] Installer built successfully

[1/13] Archiso 프로파일 초기화 중...
[2/13] mkinitcpio 설정 중...
...
[13/13] ISO 빌드 중...
```

**소요 시간:** 인터넷 속도에 따라 20분 ~ 1시간

**완료되면:**
```
============================================================
[SUCCESS] ISO 빌드 완료!
    출력: /home/user/blunux_selfbuild/out/blunux-korean-2026.01.30-x86_64.iso
============================================================
```

### 4-2. ISO 파일 확인

```bash
ls -lh out/
```

`blunux-korean-xxxx.xx.xx-x86_64.iso` 파일이 보이면 성공!

---

## 5. USB에 굽기

### 준비물

- **USB 드라이브** (8GB 이상)
- **주의:** USB의 모든 데이터가 삭제됩니다!

### 5-1. USB 장치 이름 확인

USB를 컴퓨터에 꽂은 후:

```bash
lsblk
```

**출력 예시:**
```
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 500.0G  0 disk           <- 하드디스크
├─sda1   8:1    0   512M  0 part /boot
└─sda2   8:2    0 499.5G  0 part /
sdb      8:16   1  14.9G  0 disk           <- USB (이게 중요!)
└─sdb1   8:17   1  14.9G  0 part /run/media/user/USB
```

**USB 찾는 방법:**
- `RM` 열이 `1`인 것 (Removable = 이동식)
- 크기가 USB 용량과 비슷한 것
- 위 예시에서는 `sdb`가 USB

### 5-2. USB에 ISO 쓰기

**중요:** `/dev/sdb` 부분을 **자신의 USB 장치 이름**으로 바꾸세요!

```bash
sudo dd if=out/blunux-korean-*.iso of=/dev/sdb bs=4M status=progress oflag=sync
```

**설명:**
- `dd` = 디스크 복사 도구
- `if=` = 입력 파일 (ISO)
- `of=` = 출력 장치 (USB)
- `status=progress` = 진행 상황 표시

**완료까지:** 몇 분 소요

### 5-3. 안전하게 제거

```bash
sync
sudo eject /dev/sdb
```

이제 USB를 뽑아도 됩니다.

---

## 6. 컴퓨터에 설치하기

### 6-1. USB로 부팅하기

1. **컴퓨터를 끄세요**
2. **USB를 꽂으세요**
3. **컴퓨터를 켜면서** 부팅 메뉴 키를 누르세요:

| 제조사 | 부팅 메뉴 키 |
|--------|-------------|
| 삼성 | `F2` 또는 `F10` |
| LG | `F2` |
| ASUS | `F2` 또는 `Esc` |
| Dell | `F12` |
| HP | `F9` 또는 `Esc` |
| Lenovo | `F12` 또는 `Fn+F12` |
| MSI | `F11` |
| Acer | `F12` |

4. 부팅 메뉴에서 **USB**를 선택하세요 (UEFI: 또는 USB: 로 시작하는 항목)

### 6-2. Blunux Live 부팅

화면에 메뉴가 나타나면:
- **Blunux Live** 선택 → 데스크톱 환경으로 부팅

잠시 기다리면 KDE 데스크톱이 나타납니다.

### 6-3. 설치 프로그램 실행

바탕화면에서 **터미널**을 열고 (또는 `Ctrl+Alt+T`):

```bash
blunux-install
```

**자동으로 진행되는 것들:**
1. 시스템 시간 동기화
2. Pacman 키링 초기화
3. 미러리스트 확인
4. 패키지 데이터베이스 동기화

**그 다음 설치 프로그램이 시작됩니다:**
- 디스크 선택
- 사용자 이름/비밀번호 설정
- 설치 진행

### 6-4. 설치 완료 후

```
╔══════════════════════════════════════════════════════════╗
║     Blunux 설치가 완료되었습니다!                        ║
╚══════════════════════════════════════════════════════════╝

  재부팅하려면: reboot
```

1. USB를 뽑으세요
2. `reboot` 입력하고 `Enter`
3. 새로 설치된 Blunux로 부팅됩니다!

---

## 7. 문제가 생겼을 때

### "sudo: command not found"

Arch Linux가 아닌 다른 운영체제에서 실행 중입니다.
Arch Linux 계열(Arch, Manjaro, EndeavourOS)에서 실행하세요.

### "julia: command not found"

Julia가 설치되지 않았거나 터미널을 재시작하지 않았습니다.

```bash
# 다시 설치
curl -fsSL https://install.julialang.org | sh

# 터미널을 닫았다가 다시 열기
```

### "Permission denied"

`sudo`를 빼먹었습니다:

```bash
# 잘못된 예
julia build.jl config_kr.toml

# 올바른 예
sudo julia build.jl config_kr.toml
```

### USB로 부팅이 안 돼요

1. **Secure Boot 끄기:** BIOS에서 Secure Boot를 Disabled로 변경
2. **USB 부팅 순서:** BIOS에서 USB를 첫 번째 부팅 장치로 설정
3. **다른 USB 포트:** USB 2.0 포트(검은색)를 사용해보세요

### 설치 중 인터넷이 안 돼요

```bash
# WiFi 연결
nmtui
```

화살표 키로 "Activate a connection" 선택 → WiFi 선택 → 비밀번호 입력

### 한글 입력이 안 돼요

재부팅 후 자동으로 kime가 시작됩니다.
- **한/영 전환:** `한/영` 키 또는 `Super+Space`

---

## 설정 파일 수정하기

`config_kr.toml` 파일을 열어서 원하는 프로그램을 추가/제거할 수 있습니다.

```bash
nano config_kr.toml
```

**예시 - 프로그램 추가:**
```toml
[packages.browser]
firefox = true
whale = true      # 네이버 웨일 추가!
chrome = true     # 크롬 추가!

[packages.office]
libreoffice = true
hoffice = true    # 한글 오피스 추가!

[packages.development]
vscode = true     # VS Code 추가!
```

수정 후 `Ctrl+O` → `Enter` (저장) → `Ctrl+X` (종료)

그 다음 다시 빌드:
```bash
sudo julia build.jl config_kr.toml
```

---

## ⚠️ 보안 경고 - 반드시 읽으세요!

**config.toml의 기본 비밀번호는 학습용입니다!**

```toml
[install]
root_password = "root"    # ← 기본값
user_password = "user"    # ← 기본값
```

### 설치 후 반드시 비밀번호를 변경하세요:

```bash
# 사용자 비밀번호 변경
passwd

# 루트 비밀번호 변경
sudo passwd root
```

### 또는 빌드 전에 config.toml에서 변경:

```toml
[install]
root_password = "나만의안전한비밀번호"
user_password = "나만의안전한비밀번호"
```

> 💡 **팁:** 실제 사용할 컴퓨터에 설치할 때는 반드시 강력한 비밀번호를 사용하세요!

---

## 도움이 필요하면

- **GitHub Issues:** https://github.com/JaewooJoung/blunux_selfbuild/issues
- **버그 신고나 질문**을 올려주세요!

---

**즐거운 Linux 생활 되세요!**
