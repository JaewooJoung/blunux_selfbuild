#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 installer_build.jl                                                 ┃
#┃ 📙Brief     📝 C++ Installer Build Module for Blunux Self-Build                   ┃
#┃ 🧾Details   🔎 Compiles the blunux-installer C++ CLI tool                         ┃
#┃ 🚩OAuthor   🦋 Blunux Project                                                    ┃
#┃ 👨‍🔧LAuthor   👤 Blunux Project                                                    ┃
#┃ 📆LastDate  📍 2026-01-29 🔄Please support to keep update🔄                      ┃
#┃ 🏭License   📜 MIT License                                                       ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#=
Installer Build Module for Blunux Self-Build Tool

Handles compilation of the C++ CLI installer using CMake.
The compiled installer is placed in the LiveOS for use during installation.
=#

"""
    check_build_requirements()

Check if required build tools are available (cmake, g++).
Returns true if all requirements are met.
"""
function check_build_requirements()
    requirements = [
        ("cmake", "cmake"),
        ("g++", "gcc")
    ]

    all_met = true
    for (cmd, pkg) in requirements
        if !success(`which $cmd`)
            println("    $(RED)[✗]$(RESET) $cmd not found - install $pkg")
            all_met = false
        end
    end

    return all_met
end

"""
    build_installer(installer_dir::String, build_type::String="Release")

Build the C++ installer using CMake.
Returns the path to the compiled binary, or nothing on failure.

# Arguments
- `installer_dir`: Path to the installer source directory
- `build_type`: CMake build type ("Release" or "Debug")
"""
function build_installer(installer_dir::String, build_type::String="Release")
    build_dir = joinpath(installer_dir, "build")

    # Check requirements
    if !check_build_requirements()
        println("    $(YELLOW)[!]$(RESET) Skipping installer build - missing requirements")
        return nothing
    end

    # Create build directory
    mkpath(build_dir)

    println("    Configuring CMake...")
    try
        # Run cmake configure
        run(Cmd(`cmake -S $installer_dir -B $build_dir -DCMAKE_BUILD_TYPE=$build_type`,
                dir=installer_dir))
    catch e
        println("    $(RED)[✗]$(RESET) CMake configuration failed: $e")
        return nothing
    end

    println("    Compiling installer...")
    try
        # Run cmake build
        run(Cmd(`cmake --build $build_dir --parallel`, dir=installer_dir))
    catch e
        println("    $(RED)[✗]$(RESET) Compilation failed: $e")
        return nothing
    end

    # Find the compiled binary
    binary_path = joinpath(build_dir, "blunux-installer")
    if isfile(binary_path)
        println("    $(GREEN)[✓]$(RESET) Installer built successfully: $binary_path")
        return binary_path
    else
        println("    $(RED)[✗]$(RESET) Binary not found at: $binary_path")
        return nothing
    end
end

"""
    install_installer_to_profile(binary_path::String, profile_dir::String)

Copy the compiled installer binary to the archiso profile.
Also copies the config.toml file for use by the installer.

# Arguments
- `binary_path`: Path to the compiled blunux-installer binary
- `profile_dir`: Path to the archiso profile directory
"""
function install_installer_to_profile(binary_path::String, profile_dir::String)
    if !isfile(binary_path)
        println("    $(YELLOW)[!]$(RESET) Installer binary not found, skipping")
        return false
    end

    airootfs_dir = joinpath(profile_dir, "airootfs")
    bin_dir = joinpath(airootfs_dir, "usr", "local", "bin")
    mkpath(bin_dir)

    # Copy binary
    dest_path = joinpath(bin_dir, "blunux-installer")
    cp(binary_path, dest_path, force=true)
    chmod(dest_path, 0o755)

    println("    Installed blunux-installer to LiveOS")
    return true
end

"""
    copy_config_to_profile(config_file::String, profile_dir::String)

Copy the TOML config file to the archiso profile for use by the installer.
"""
function copy_config_to_profile(config_file::String, profile_dir::String)
    if !isfile(config_file)
        println("    $(YELLOW)[!]$(RESET) Config file not found: $config_file")
        return false
    end

    airootfs_dir = joinpath(profile_dir, "airootfs")
    config_dir = joinpath(airootfs_dir, "etc", "blunux")
    mkpath(config_dir)

    # Copy config
    dest_path = joinpath(config_dir, "config.toml")
    cp(config_file, dest_path, force=true)

    println("    Copied config.toml to /etc/blunux/config.toml")
    return true
end

"""
    update_install_script_for_installer(profile_dir::String)

Update the blunux-install script to use the C++ installer instead of archinstall.
"""
function update_install_script_for_installer(profile_dir::String)
    airootfs_dir = joinpath(profile_dir, "airootfs")
    scripts_dir = joinpath(airootfs_dir, "usr", "local", "bin")
    mkpath(scripts_dir)

    install_script = joinpath(scripts_dir, "blunux-install")

    open(install_script, "w") do f
        print(f, raw"""#!/bin/bash
# Blunux Install Script
# Launches the Blunux C++ Installer

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
RESET='\033[0m'

echo ""
echo -e "${BLUE}======================================${RESET}"
echo -e "${BLUE}       Blunux System Installer${RESET}"
echo -e "${BLUE}======================================${RESET}"
echo ""

step0_ok=false
step1_ok=false
step2_ok=false
step3_ok=false

# ─────────────────────────────────────
# Step 0: 시스템 시간 동기화 (NTP)
# ─────────────────────────────────────
echo -e "[0/4] ${YELLOW}시스템 시간 동기화 중...${RESET}"
if timedatectl set-ntp true 2>/dev/null; then
    sleep 2  # NTP 동기화 대기
    step0_ok=true
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "      ${GREEN}[성공]${RESET} NTP 활성화 - 현재 시간: $current_time"
else
    echo -e "      ${YELLOW}[경고]${RESET} NTP 설정 실패 (계속 진행)"
    step0_ok=true  # 계속 진행
fi

# ─────────────────────────────────────
# Step 1: Pacman 키링 초기화
# ─────────────────────────────────────
echo ""
echo -e "[1/4] ${YELLOW}Pacman 키링 초기화 중...${RESET}"

# 먼저 기존 서비스로 시도
sudo systemctl start pacman-init.service 2>/dev/null

# 30초간 대기
for i in $(seq 1 30); do
    if [ -d /etc/pacman.d/gnupg/private-keys-v1.d ]; then
        step1_ok=true
        break
    fi
    sleep 1
    printf "\r      %d초 대기 중..." "$i"
done
echo ""

# 실패시 수동으로 키링 초기화
if [ "$step1_ok" = false ]; then
    echo -e "      ${CYAN}[시도]${RESET} 수동 키링 초기화 중..."

    # 기존 키링 제거 및 재생성
    sudo rm -rf /etc/pacman.d/gnupg 2>/dev/null

    # pacman-key 초기화
    if sudo pacman-key --init 2>/dev/null; then
        echo -e "      ${GREEN}[성공]${RESET} pacman-key --init 완료"

        # archlinux 키 등록
        if sudo pacman-key --populate archlinux 2>/dev/null; then
            echo -e "      ${GREEN}[성공]${RESET} pacman-key --populate 완료"
            step1_ok=true
        else
            echo -e "      ${RED}[실패]${RESET} pacman-key --populate 실패"
        fi
    else
        echo -e "      ${RED}[실패]${RESET} pacman-key --init 실패"
    fi
fi

if [ "$step1_ok" = true ]; then
    echo -e "      ${GREEN}[성공]${RESET} Pacman 키링 초기화 완료"
else
    echo -e "      ${RED}[실패]${RESET} Pacman 키링 초기화 실패"
fi

# ─────────────────────────────────────
# Step 2: 미러리스트 확인
# ─────────────────────────────────────
echo ""
echo -e "[2/4] ${YELLOW}미러리스트 확인 중...${RESET}"

if grep -q "^Server" /etc/pacman.d/mirrorlist 2>/dev/null; then
    step2_ok=true
    echo -e "      ${GREEN}[성공]${RESET} 미러리스트가 이미 설정되어 있습니다"
else
    echo "      미러리스트가 비어있습니다. 기본 미러를 설정합니다..."
    sudo bash -c 'cat > /etc/pacman.d/mirrorlist << EOF
## Worldwide
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch
## Worldwide (Rackspace)
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
## South Korea
Server = https://mirror.premi.st/archlinux/\$repo/os/\$arch
Server = https://ftp.lanet.kr/pub/archlinux/\$repo/os/\$arch
## Japan
Server = https://ftp.jaist.ac.jp/pub/Linux/ArchLinux/\$repo/os/\$arch
## United States
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
EOF'
    if grep -q "^Server" /etc/pacman.d/mirrorlist 2>/dev/null; then
        step2_ok=true
        echo -e "      ${GREEN}[성공]${RESET} 기본 미러 설정 완료"
    else
        echo -e "      ${RED}[실패]${RESET} 미러리스트 설정 실패"
    fi
fi

# ─────────────────────────────────────
# Step 3: 패키지 데이터베이스 동기화
# ─────────────────────────────────────
echo ""
echo -e "[3/4] ${YELLOW}패키지 데이터베이스 동기화 중...${RESET}"

# 잠금 파일 삭제 (이전 작업의 흔적)
if [ -f /var/lib/pacman/db.lck ]; then
    echo -e "      ${CYAN}[정리]${RESET} 잠금 파일 삭제 중..."
    sudo rm -f /var/lib/pacman/db.lck
fi

# 부분 다운로드 파일 삭제
if ls /var/lib/pacman/sync/*.part 1>/dev/null 2>&1; then
    echo -e "      ${CYAN}[정리]${RESET} 부분 다운로드 파일 삭제 중..."
    sudo rm -f /var/lib/pacman/sync/*.part
fi

# 첫 번째 시도: 일반 동기화
if sudo pacman -Sy --noconfirm 2>/dev/null; then
    step3_ok=true
    echo -e "      ${GREEN}[성공]${RESET} 패키지 데이터베이스 동기화 완료"
else
    echo -e "      ${CYAN}[시도]${RESET} 강제 동기화 (-Syy) 시도 중..."

    # 두 번째 시도: 강제 동기화 (모든 DB 재다운로드)
    if sudo pacman -Syy --noconfirm 2>/dev/null; then
        step3_ok=true
        echo -e "      ${GREEN}[성공]${RESET} 강제 동기화 완료"
    else
        # 세 번째 시도: archlinux-keyring 업데이트 후 다시 시도
        echo -e "      ${CYAN}[시도]${RESET} archlinux-keyring 업데이트 중..."
        if sudo pacman -Sy --noconfirm archlinux-keyring 2>/dev/null; then
            echo -e "      ${GREEN}[성공]${RESET} archlinux-keyring 업데이트 완료"
            if sudo pacman -Syy --noconfirm 2>/dev/null; then
                step3_ok=true
                echo -e "      ${GREEN}[성공]${RESET} 패키지 데이터베이스 동기화 완료"
            fi
        fi

        if [ "$step3_ok" = false ]; then
            echo -e "      ${RED}[실패]${RESET} 패키지 데이터베이스 동기화 실패"
            echo -e "      ${YELLOW}팁: 인터넷 연결을 확인하세요 (nmtui)${RESET}"
        fi
    fi
fi

# ─────────────────────────────────────
# 결과 요약
# ─────────────────────────────────────
echo ""
echo -e "${BLUE}──────── 준비 결과 ────────${RESET}"
[ "$step0_ok" = true ] && echo -e "  0. 시간 동기화    ${GREEN}[OK]${RESET}" || echo -e "  0. 시간 동기화    ${YELLOW}[SKIP]${RESET}"
[ "$step1_ok" = true ] && echo -e "  1. 키링 초기화    ${GREEN}[OK]${RESET}" || echo -e "  1. 키링 초기화    ${RED}[FAIL]${RESET}"
[ "$step2_ok" = true ] && echo -e "  2. 미러리스트     ${GREEN}[OK]${RESET}" || echo -e "  2. 미러리스트     ${RED}[FAIL]${RESET}"
[ "$step3_ok" = true ] && echo -e "  3. DB 동기화      ${GREEN}[OK]${RESET}" || echo -e "  3. DB 동기화      ${RED}[FAIL]${RESET}"
echo -e "${BLUE}───────────────────────────${RESET}"

# 실패한 단계가 있으면 안내 후 계속 진행
if [ "$step1_ok" = false ] || [ "$step3_ok" = false ]; then
    echo ""
    echo -e "${RED}일부 단계가 실패했습니다.${RESET}"
    echo ""
    echo "  해결 방법:"
    echo "    1. 인터넷 연결 확인: nmtui 실행 (WiFi) 또는 유선 연결 확인"
    echo "    2. 수동으로 키링 초기화:"
    echo "       sudo rm -rf /etc/pacman.d/gnupg"
    echo "       sudo pacman-key --init"
    echo "       sudo pacman-key --populate archlinux"
    echo "    3. 연결 후 다시 실행: blunux-install"
    echo ""
    read -p "그래도 설치를 계속하시겠습니까? (y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo "설치를 취소합니다."
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}[4/4] Blunux Installer를 시작합니다...${RESET}"
echo ""

# Function to copy Blunux config to installed system
copy_blunux_config() {
    local mount_point="/mnt"

    # Auto-detect username from installed system (UID 1000)
    local target_user=$(grep -E "^[^:]+:x:1000:" "$mount_point/etc/passwd" 2>/dev/null | cut -d: -f1)

    if [ -z "$target_user" ]; then
        echo -e "${RED}[오류]${RESET} 설치된 시스템에서 사용자를 찾을 수 없습니다."
        echo -e "       /mnt가 마운트되어 있는지 확인하세요."
        return 1
    fi

    echo -e "  대상 사용자: ${GREEN}$target_user${RESET}"

    local user_home="$mount_point/home/$target_user"

    if [ -d "$user_home" ]; then
        echo -e "${CYAN}Blunux 설정 복사 중...${RESET}"

        # Copy fastfetch config
        mkdir -p "$user_home/.config/fastfetch"
        if [ -f /etc/fastfetch/config.jsonc ]; then
            cp /etc/fastfetch/config.jsonc "$user_home/.config/fastfetch/"
            cp /etc/fastfetch/blunux-logo.txt "$user_home/.config/fastfetch/" 2>/dev/null || true
            echo -e "  ${GREEN}✓${RESET} fastfetch 설정 복사됨"
        elif [ -f /home/live/.config/fastfetch/config.jsonc ]; then
            cp /home/live/.config/fastfetch/config.jsonc "$user_home/.config/fastfetch/"
            cp /home/live/.config/fastfetch/blunux-logo.txt "$user_home/.config/fastfetch/" 2>/dev/null || true
            echo -e "  ${GREEN}✓${RESET} fastfetch 설정 복사됨 (live 사용자에서)"
        else
            echo -e "  ${YELLOW}!${RESET} fastfetch 설정을 찾을 수 없습니다"
        fi

        # Copy to system-wide /etc/fastfetch
        mkdir -p "$mount_point/etc/fastfetch"
        cp -r /etc/fastfetch/* "$mount_point/etc/fastfetch/" 2>/dev/null || true

        # Fix ownership
        local uid=$(grep "^$target_user:" "$mount_point/etc/passwd" | cut -d: -f3)
        local gid=$(grep "^$target_user:" "$mount_point/etc/passwd" | cut -d: -f4)
        if [ -n "$uid" ] && [ -n "$gid" ]; then
            chown -R "$uid:$gid" "$user_home"
            echo -e "  ${GREEN}✓${RESET} 홈 디렉토리 소유권 수정됨"
        fi

        echo -e "${GREEN}[완료]${RESET} Blunux 설정이 복사되었습니다."
    else
        echo -e "${YELLOW}[경고]${RESET} 사용자 홈 디렉토리를 찾을 수 없습니다: $user_home"
    fi
}

# Function to parse config.toml and return package list
get_config_packages() {
    local config_file="${1:-/etc/blunux/config.toml}"
    local packages=""

    if [ ! -f "$config_file" ]; then
        return
    fi

    # Read each setting from config.toml
    # Browser packages
    if grep -q "^firefox *= *true" "$config_file" 2>/dev/null; then
        packages="$packages firefox"
    fi

    # Office packages
    if grep -q "^libreoffice *= *true" "$config_file" 2>/dev/null; then
        packages="$packages libreoffice-fresh"
    fi

    # Development packages
    if grep -q "^git *= *true" "$config_file" 2>/dev/null; then
        packages="$packages git"
    fi

    # Multimedia packages
    if grep -q "^vlc *= *true" "$config_file" 2>/dev/null; then
        packages="$packages vlc"
    fi

    # Bluetooth packages
    if grep -q "^bluetooth *= *true" "$config_file" 2>/dev/null; then
        packages="$packages bluez bluez-utils bluedevil blueman"
    fi

    echo "$packages"
}

# Function to get AUR packages from config.toml
get_config_aur_packages() {
    local config_file="${1:-/etc/blunux/config.toml}"
    local packages=""

    if [ ! -f "$config_file" ]; then
        return
    fi

    # AUR packages
    if grep -q "^whale *= *true" "$config_file" 2>/dev/null; then
        packages="$packages naver-whale-stable"
    fi
    if grep -q "^chrome *= *true" "$config_file" 2>/dev/null; then
        packages="$packages google-chrome"
    fi
    if grep -q "^vscode *= *true" "$config_file" 2>/dev/null; then
        packages="$packages visual-studio-code-bin"
    fi
    if grep -q "^hoffice *= *true" "$config_file" 2>/dev/null; then
        packages="$packages hoffice"
    fi

    echo "$packages"
}

# Function to get input method engine from config.toml
get_config_input_method() {
    local config_file="${1:-/etc/blunux/config.toml}"

    if [ ! -f "$config_file" ]; then
        echo ""
        return
    fi

    # Check if input method is enabled
    if ! grep -q "^enabled *= *true" "$config_file" 2>/dev/null; then
        echo ""
        return
    fi

    # Get engine name
    local engine=$(grep "^engine *=" "$config_file" 2>/dev/null | sed 's/.*= *"\([^"]*\)".*/\1/')
    echo "$engine"
}

# Function to install packages after archinstall
install_config_packages() {
    local mount_point="/mnt"
    local config_file="/etc/blunux/config.toml"

    if [ ! -f "$config_file" ]; then
        echo -e "${YELLOW}[경고]${RESET} config.toml을 찾을 수 없습니다. 패키지 설치를 건너뜁니다."
        return
    fi

    # Get packages from config
    local packages=$(get_config_packages "$config_file")
    local aur_packages=$(get_config_aur_packages "$config_file")
    local input_method=$(get_config_input_method "$config_file")

    echo ""
    echo -e "${BLUE}config.toml에서 패키지 설정을 읽었습니다:${RESET}"
    [ -n "$packages" ] && echo -e "  공식 패키지: ${GREEN}$packages${RESET}"
    [ -n "$aur_packages" ] && echo -e "  AUR 패키지: ${CYAN}$aur_packages${RESET}"
    [ -n "$input_method" ] && echo -e "  입력기: ${CYAN}$input_method${RESET}"

    # Install official packages
    if [ -n "$packages" ]; then
        echo ""
        echo -e "${YELLOW}공식 패키지 설치 중...${RESET}"
        if ! arch-chroot "$mount_point" pacman -S --noconfirm --needed $packages; then
            echo -e "${RED}[경고]${RESET} 일부 패키지 설치 실패"
        else
            echo -e "${GREEN}[완료]${RESET} 공식 패키지 설치 완료"
        fi
    fi

    # Install input method
    if [ -n "$input_method" ]; then
        echo ""
        echo -e "${YELLOW}입력기 ($input_method) 설치 중...${RESET}"

        case "$input_method" in
            kime)
                # kime is in AUR, need to use yay or paru
                echo -e "  ${CYAN}kime는 AUR 패키지입니다. AUR 헬퍼 설치 후 설치됩니다.${RESET}"
                aur_packages="$aur_packages kime-bin"
                ;;
            fcitx5)
                arch-chroot "$mount_point" pacman -S --noconfirm --needed \
                    fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-hangul
                echo -e "${GREEN}[완료]${RESET} fcitx5 설치 완료"
                ;;
            ibus)
                arch-chroot "$mount_point" pacman -S --noconfirm --needed \
                    ibus ibus-hangul
                echo -e "${GREEN}[완료]${RESET} ibus 설치 완료"
                ;;
        esac
    fi

    # Install paru AUR helper (always install for user convenience)
    echo ""
    echo -e "${YELLOW}paru AUR 헬퍼 설치 중...${RESET}"

    local target_user=$(grep -E "^[^:]+:x:1000:" "$mount_point/etc/passwd" | cut -d: -f1)

    if [ -n "$target_user" ]; then
        # Install base-devel and git (required for building AUR packages)
        arch-chroot "$mount_point" pacman -S --noconfirm --needed base-devel git

        # Build and install paru as the target user
        arch-chroot "$mount_point" su - "$target_user" -c '
            cd /tmp
            git clone https://aur.archlinux.org/paru-bin.git
            cd paru-bin
            makepkg -si --noconfirm
            cd ..
            rm -rf paru-bin
        '

        if arch-chroot "$mount_point" which paru >/dev/null 2>&1; then
            echo -e "${GREEN}[완료]${RESET} paru 설치 완료"

            # Install AUR packages using paru
            if [ -n "$aur_packages" ]; then
                echo ""
                echo -e "${YELLOW}AUR 패키지 설치 중...${RESET}"
                echo -e "  패키지: ${CYAN}$aur_packages${RESET}"
                arch-chroot "$mount_point" su - "$target_user" -c "paru -S --noconfirm --needed $aur_packages" || \
                    echo -e "${YELLOW}[경고]${RESET} 일부 AUR 패키지 설치 실패. 나중에 수동 설치 필요."
            fi
        else
            echo -e "${YELLOW}[경고]${RESET} paru 설치 실패"
            if [ -n "$aur_packages" ]; then
                echo -e "  ${CYAN}설치 후 직접 paru를 설치하고 다음 패키지를 설치하세요:${RESET}"
                echo -e "    ${GREEN}$aur_packages${RESET}"
            fi
        fi
    else
        echo -e "${RED}[오류]${RESET} 대상 사용자를 찾을 수 없습니다."
    fi

    # Configure input method environment (using /etc/environment instead of deprecated .pam_environment)
    # Configure input method environment
    # Note: ~/.pam_environment is deprecated on Arch Linux since 2022-10-20
    # Using ~/.config/environment.d/*.conf (systemd user environment) instead
    if [ -n "$input_method" ]; then
        echo ""
        echo -e "${YELLOW}입력기 환경 설정 중...${RESET}"

        case "$input_method" in
            kime)
                # kime environment
                cat >> "$mount_point/etc/environment" << 'KIMEENV'

# Input Method: kime
        local target_user=$(grep -E "^[^:]+:x:1000:" "$mount_point/etc/passwd" | cut -d: -f1)
        local user_home="$mount_point/home/$target_user"
        local env_dir="$user_home/.config/environment.d"

        # Create environment.d directory
        mkdir -p "$env_dir"

        case "$input_method" in
            kime)
                # kime environment
                cat > "$env_dir/input-method.conf" << 'KIMEENV'
GTK_IM_MODULE=kime
QT_IM_MODULE=kime
XMODIFIERS=@im=kime
KIMEENV
                ;;
            fcitx5)
                cat >> "$mount_point/etc/environment" << 'FCITXENV'

# Input Method: fcitx5
                cat > "$env_dir/input-method.conf" << 'FCITXENV'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
FCITXENV
                ;;
            ibus)
                cat >> "$mount_point/etc/environment" << 'IBUSENV'

# Input Method: ibus
                cat > "$env_dir/input-method.conf" << 'IBUSENV'
GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
IBUSENV
                ;;
        esac

        # Fix ownership
        if [ -n "$target_user" ]; then
            local uid=$(grep "^$target_user:" "$mount_point/etc/passwd" | cut -d: -f3)
            local gid=$(grep "^$target_user:" "$mount_point/etc/passwd" | cut -d: -f4)
            chown -R "$uid:$gid" "$user_home/.config"
        fi

        echo -e "${GREEN}[완료]${RESET} 입력기 환경 설정 완료"
    fi
}

# Function to copy Blunux os-release branding to installed system
copy_blunux_osrelease() {
    local mount_point="/mnt"

    if [ -f /etc/os-release ]; then
        echo -e "${CYAN}Blunux OS 브랜딩 복사 중...${RESET}"

        # Copy os-release to installed system
        cp /etc/os-release "$mount_point/etc/os-release"

        # Also update /usr/lib/os-release (some tools read from here)
        mkdir -p "$mount_point/usr/lib"
        cp /etc/os-release "$mount_point/usr/lib/os-release"

        echo -e "${GREEN}[완료]${RESET} OS 브랜딩 (os-release) 복사 완료"
    else
        echo -e "${YELLOW}[경고]${RESET} /etc/os-release를 찾을 수 없습니다"
    fi
}

# Check if blunux-installer exists, otherwise fall back to archinstall
if [ -x /usr/local/bin/blunux-installer ]; then
    # Use the C++ installer with config file if available
    if [ -f /etc/blunux/config.toml ]; then
        sudo /usr/local/bin/blunux-installer /etc/blunux/config.toml
    else
        sudo /usr/local/bin/blunux-installer
    fi
else
    # Fallback to archinstall
    echo -e "${YELLOW}blunux-installer not found, using archinstall...${RESET}"
    echo ""
    echo -e "${CYAN}참고: archinstall 완료 후 config.toml의 패키지들을 자동 설치합니다.${RESET}"
    echo ""

    sudo archinstall

    # After archinstall completes, apply config.toml settings
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║     Blunux 추가 설정 적용 (archinstall 완료 후)          ║${RESET}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # Check if /mnt is mounted (archinstall should leave it mounted)
    if ! mountpoint -q /mnt 2>/dev/null; then
        echo -e "${RED}[오류]${RESET} /mnt가 마운트되어 있지 않습니다."
        echo -e "       archinstall이 제대로 완료되지 않았거나 이미 언마운트되었습니다."
        echo -e ""
        echo -e "${YELLOW}수동으로 설정을 적용하려면:${RESET}"
        echo -e "  1. 설치된 파티션을 /mnt에 마운트하세요"
        echo -e "  2. blunux-install 을 다시 실행하세요"
        exit 1
    fi

    echo -e "${GREEN}[확인]${RESET} /mnt 마운트 확인됨"
    echo ""

    # Install packages from config.toml (includes paru installation)
    echo -e "${BLUE}── 1. config.toml 패키지 설치 ──${RESET}"
    install_config_packages

    # Copy Blunux branding (os-release)
    echo ""
    echo -e "${BLUE}── 2. Blunux OS 브랜딩 ──${RESET}"
    copy_blunux_osrelease

    # Copy Blunux config (fastfetch, etc)
    echo ""
    echo -e "${BLUE}── 3. Blunux 설정 파일 복사 (펭귄 로고 등) ──${RESET}"
    copy_blunux_config

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║     Blunux 설치가 완료되었습니다!                        ║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  재부팅하려면: ${CYAN}reboot${RESET}"
    echo -e "  설치된 시스템 진입: ${CYAN}arch-chroot /mnt${RESET}"
    echo ""
fi
""")
    end

    chmod(install_script, 0o755)
    println("    Updated blunux-install script to use C++ installer")
end
