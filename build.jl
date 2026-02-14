#!/usr/bin/env julia
#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 build.jl                                                          ┃
#┃ 📙Brief     📝 Blunux Self-Build Tool - Main Entry Point                         ┃
#┃ 🧾Details   🔎 TOML config parser, CLI handler, and ISO build orchestrator       ┃
#┃ 🚩OAuthor   🦋 Blunux Project                                                    ┃
#┃ 👨‍🔧LAuthor   👤 Blunux Project                                                    ┃
#┃ 📆LastDate  📍 2026-01-25 🔄Please support to keep update🔄                      ┃
#┃ 🏭License   📜 MIT License                                                       ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#=
Blunux Self-Build Tool
Build your own custom Blunux ISO from a TOML configuration file.

Usage:
    julia build.jl config.toml [--output=output_dir] [--work=work_dir]
=#

using TOML
using Dates

# Include modules
include("src/build_id.jl")
include("src/packages.jl")
include("src/archiso.jl")
include("src/locale.jl")
include("src/installer_build.jl")

# Constants
const VERSION = "1.0.0"
const DEFAULT_OUTPUT_DIR = "out"
const DEFAULT_WORK_DIR = "work"

# Color codes for terminal output
const RED = "\e[31m"
const GREEN = "\e[32m"
const YELLOW = "\e[33m"
const BLUE = "\e[34m"
const MAGENTA = "\e[35m"
const CYAN = "\e[36m"
const RESET = "\e[0m"
const BOLD = "\e[1m"

"""
    print_banner()

Print the Blunux builder banner.
"""
function print_banner()
    println("""
$(CYAN)    ╔══════════════════════════════════════════════════════════╗
    ║$(BOLD)           Blunux Self-Build Tool v$(VERSION)$(RESET)$(CYAN)                 ║
    ║        Build your custom Arch-based Linux ISO            ║
    ╚══════════════════════════════════════════════════════════╝$(RESET)
    """)
end

"""
    print_error(msg)

Print an error message with formatting.
"""
function print_error(msg)
    println("\n$(RED)$(BOLD)[오류/Error]$(RESET) $(RED)$msg$(RESET)\n")
end

"""
    print_success(msg)

Print a success message with formatting.
"""
function print_success(msg)
    println("$(GREEN)[✓]$(RESET) $msg")
end

"""
    print_info(msg)

Print an info message with formatting.
"""
function print_info(msg)
    println("$(BLUE)[*]$(RESET) $msg")
end

"""
    print_warn(msg)

Print a warning message with formatting.
"""
function print_warn(msg)
    println("$(YELLOW)[!]$(RESET) $msg")
end

"""
    parse_args(args)

Parse command line arguments.
"""
function parse_args(args)
    if isempty(args)
        println("""
$(BOLD)사용법 / Usage:$(RESET)
    sudo julia build.jl <config.toml> [옵션]

$(BOLD)옵션 / Options:$(RESET)
    --output=dir    ISO 출력 디렉토리 (기본값: out)
    --work=dir      작업 디렉토리 (기본값: work)
    --help          도움말 표시

$(BOLD)예시 / Examples:$(RESET)
    sudo julia build.jl my-config.toml
    sudo julia build.jl config.toml --output=/home/user/iso

$(BOLD)설정 파일이 없다면 / If you don't have a config file:$(RESET)
    1. https://blunux.com/builder/ 에서 생성하거나
    2. examples/ 폴더의 예시 파일을 복사하세요:
       cp examples/korean-desktop.toml config.toml
""")
        exit(0)
    end

    config_file = nothing
    output_dir = DEFAULT_OUTPUT_DIR
    work_dir = DEFAULT_WORK_DIR

    for arg in args
        if arg == "--help" || arg == "-h"
            parse_args([])  # Show help and exit
        elseif startswith(arg, "--output=")
            output_dir = arg[10:end]
        elseif startswith(arg, "--work=")
            work_dir = arg[8:end]
        elseif !startswith(arg, "--")
            config_file = arg
        end
    end

    if config_file === nothing
        print_error("설정 파일을 지정해주세요.\nPlease specify a configuration file.")
        println("사용법: sudo julia build.jl <config.toml>")
        exit(1)
    end

    return (config_file=config_file, output_dir=output_dir, work_dir=work_dir)
end

"""
    validate_config(config)

Validate the TOML configuration.
"""
function validate_config(config)
    # Check required sections
    if !haskey(config, "blunux")
        print_error("[blunux] 섹션이 없습니다.\nMissing [blunux] section in config")
        exit(1)
    end

    # Validate blunux section
    blunux = config["blunux"]
    if !haskey(blunux, "version")
        print_warn("버전이 지정되지 않았습니다. 1.0 사용")
    end
    if !haskey(blunux, "name")
        print_error("[blunux] 섹션에 'name'이 없습니다.\nMissing 'name' in [blunux] section")
        exit(1)
    end

    # Validate locale if present
    if haskey(config, "locale")
        locale = config["locale"]
        if haskey(locale, "language")
            lang = locale["language"]
            # Support both string and array of strings
            langs = lang isa AbstractString ? [lang] : lang
            for l in langs
                if !occursin(r"^[a-z]{2}_[A-Z]{2}$", l)
                    print_warn("로케일 '$l' 형식이 올바르지 않을 수 있습니다 (예: ko_KR)")
                end
            end
        end
    end

    # Validate kernel if present
    if haskey(config, "kernel")
        kernel = config["kernel"]
        if haskey(kernel, "type")
            valid_kernels = ["linux", "linux-bore", "linux-zen", "linux-lts"]
            if !(kernel["type"] in valid_kernels)
                print_error("잘못된 커널 타입: $(kernel["type"])\n사용 가능: $(join(valid_kernels, ", "))")
                exit(1)
            end
        end
    end

    return true
end

"""
    install_package(pkg)

Install a package using pacman.
"""
function install_package(pkg)
    println("    $(CYAN)패키지 설치 중 / Installing:$(RESET) $pkg")
    try
        run(`sudo pacman -S --noconfirm --needed $pkg`)
        return true
    catch e
        print_error("패키지 설치 실패: $pkg")
        return false
    end
end

"""
    check_and_install_requirements()

Check if all required tools are installed, and offer to install missing ones.
"""
function check_and_install_requirements()
    print_info("빌드 요구사항 확인 중... / Checking build requirements...")

    # Required packages and their corresponding pacman package names
    requirements = [
        ("mkarchiso", "archiso", "archiso 패키지가 필요합니다"),
        ("pacman", "pacman", "pacman이 필요합니다"),
    ]

    missing_packages = String[]

    for (cmd, pkg, msg) in requirements
        if success(`which $cmd`)
            print_success("$cmd 발견")
        else
            println("  $(RED)[✗]$(RESET) $cmd 없음 - $msg")
            push!(missing_packages, pkg)
        end
    end

    # Check for yay/paru for AUR packages
    aur_helper = nothing
    for helper in ["yay", "paru"]
        if success(`which $helper`)
            print_success("AUR 헬퍼 발견: $helper")
            aur_helper = helper
            break
        end
    end

    if aur_helper === nothing
        print_warn("AUR 헬퍼(yay/paru)가 없습니다. AUR 패키지는 건너뜁니다.")
    end

    # Check root privileges
    uid = ccall(:getuid, Cuint, ())
    if uid != 0
        println()
        print_error("루트 권한이 필요합니다!\nRoot privileges required!")
        println("다음 명령어로 실행하세요: $(BOLD)sudo julia build.jl config.toml$(RESET)")
        exit(1)
    end

    # If there are missing packages, offer to install them
    if !isempty(missing_packages)
        println()
        print_warn("누락된 패키지가 있습니다: $(join(missing_packages, ", "))")
        println()
        print("$(BOLD)자동으로 설치할까요? / Install automatically? [Y/n]:$(RESET) ")

        response = readline()
        if isempty(response) || lowercase(response) == "y" || lowercase(response) == "yes"
            println()
            print_info("패키지 설치 중... / Installing packages...")

            for pkg in missing_packages
                if !install_package(pkg)
                    print_error("필수 패키지 설치에 실패했습니다: $pkg")
                    exit(1)
                end
            end

            println()
            print_success("모든 패키지가 설치되었습니다!")
        else
            println()
            print_error("필수 패키지가 설치되지 않았습니다.")
            println("수동으로 설치하세요: $(BOLD)sudo pacman -S $(join(missing_packages, " "))$(RESET)")
            exit(1)
        end
    end

    return (all_met=true, aur_helper=aur_helper)
end

"""
    build_installer_step()

Build the Rust installer before creating the LiveOS.
Falls back to legacy C++ build if Rust toolchain is unavailable.
Returns the path to the compiled binary, or nothing if build fails.
"""
function build_installer_step()
    script_dir = dirname(@__FILE__)

    # Primary: Rust installer
    rust_dir = joinpath(script_dir, "installer-rs")
    # Fallback: Legacy C++ installer
    cpp_dir = joinpath(script_dir, "installer")

    if isdir(rust_dir) && isfile(joinpath(rust_dir, "Cargo.toml"))
        # Try Rust build - auto-install toolchain if missing
        if !success(`which cargo`) || !success(`which rustc`)
            println()
            println("$(YELLOW)┌─────────────────────────────────────────────────────────────┐$(RESET)")
            println("$(YELLOW)│  Rust 툴체인 누락 - 자동 설치 중...                         │$(RESET)")
            println("$(YELLOW)└─────────────────────────────────────────────────────────────┘$(RESET)")
            println()

            # Auto-install Rust toolchain via pacman (Arch Linux)
            rust_installed = false
            if success(`which pacman`)
                print_info("pacman -S --noconfirm rust 설치 중...")
                try
                    run(`sudo pacman -S --noconfirm --needed rust`)
                    rust_installed = true
                    println("    $(GREEN)[✓]$(RESET) Rust 툴체인 설치 완료")
                catch e
                    println("    $(YELLOW)[!]$(RESET) pacman 설치 실패: $e")
                end
            end

            # If pacman failed or not available, try rustup
            if !rust_installed && !success(`which cargo`)
                print_info("rustup으로 Rust 설치 시도 중...")
                try
                    run(pipeline(`curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs`,
                                 `sh -s -- -y --default-toolchain stable`))
                    # Add cargo to PATH for this session
                    ENV["PATH"] = string(get(ENV, "HOME", "/root"), "/.cargo/bin:", ENV["PATH"])
                    rust_installed = true
                    println("    $(GREEN)[✓]$(RESET) Rust 툴체인 설치 완료 (rustup)")
                catch e
                    println("    $(RED)[✗]$(RESET) rustup 설치 실패: $e")
                end
            end

            # If still no Rust, try C++ fallback
            if !rust_installed && (!success(`which cargo`) || !success(`which rustc`))
                println("    $(YELLOW)[!]$(RESET) Rust 설치 실패, C++ 폴백 빌드를 시도합니다...")

                if isdir(cpp_dir) && isfile(joinpath(cpp_dir, "CMakeLists.txt"))
                    if success(`which cmake`) && success(`which g++`)
                        print_info("Building legacy C++ installer (fallback)...")
                        return build_installer(cpp_dir, "Release")
                    end
                end

                print_warn("No installer could be built. archinstall will be used as fallback.")
                return nothing
            end
        end

        print_info("Rust 인스톨러 빌드 중...")
        return build_installer(rust_dir, "Release")
    elseif isdir(cpp_dir) && isfile(joinpath(cpp_dir, "CMakeLists.txt"))
        # Legacy C++ path
        print_warn("Rust installer source not found, trying legacy C++ build...")
        return build_installer(cpp_dir, "Release")
    else
        print_warn("No installer source directory found")
        return nothing
    end
end

"""
    build_iso(config, args, aur_helper)

Main function to build the ISO.
"""
function build_iso(config, args, aur_helper)
    build_name = config["blunux"]["name"]
    work_dir = abspath(args.work_dir)
    output_dir = abspath(args.output_dir)
    config_file = abspath(args.config_file)

    println()
    print_info("Blunux 빌드 시작: $(BOLD)$build_name$(RESET)")
    println("    작업 디렉토리: $work_dir")
    println("    출력 디렉토리: $output_dir")

    # Step 0: Build Rust installer (fallback: C++)
    println("\n$(MAGENTA)[0/13]$(RESET) Rust 인스톨러 빌드 중...")
    installer_binary = build_installer_step()

    # Step 1: Initialize archiso profile
    # Determine language from locale config (default: korean)
    locale_config = get(config, "locale", Dict())
    language_code = get(locale_config, "language", "ko_KR")
    # Map locale codes to language names for ISO filename
    language_map = Dict(
        "ko_KR" => "korean",
        "en_US" => "english",
        "ja_JP" => "japanese",
        "zh_CN" => "chinese",
        "de_DE" => "german",
        "fr_FR" => "french",
        "es_ES" => "spanish",
        "pt_BR" => "portuguese",
        "ru_RU" => "russian",
        "sv_SE" => "swedish",
    )
    iso_language = get(language_map, language_code, "korean")

    println("\n$(MAGENTA)[1/14]$(RESET) archiso 프로파일 초기화 중...")
    profile_dir = init_archiso_profile(work_dir, build_name; language=iso_language)

    # Step 2: Configure mkinitcpio (keyboard/mouse support)
    println("\n$(MAGENTA)[2/14]$(RESET) mkinitcpio 설정 중 (키보드/마우스 지원)...")
    configure_mkinitcpio(profile_dir)

    # Step 3: Configure systemd services (pacman-init, NetworkManager, etc.)
    println("\n$(MAGENTA)[3/14]$(RESET) systemd 서비스 설정 중 (pacman-init, 네트워크)...")
    configure_systemd_services(profile_dir)

    # Step 4: Collect packages
    println("\n$(MAGENTA)[4/14]$(RESET) 패키지 목록 수집 중...")
    packages = collect_packages(config, aur_helper)
    println("    총 패키지: $(length(packages.pacman)) pacman, $(length(packages.aur)) AUR")

    # Step 5: Configure packages in profile
    println("\n$(MAGENTA)[5/14]$(RESET) 패키지 설정 중...")
    configure_packages(profile_dir, packages)

    # Step 6: Configure locale settings
    println("\n$(MAGENTA)[6/14]$(RESET) 로케일 설정 중...")
    locale_config = get(config, "locale", Dict())
    configure_locale(profile_dir, locale_config)

    # Step 7: Configure input method
    println("\n$(MAGENTA)[7/14]$(RESET) 입력기 설정 중...")
    input_config = get(config, "input_method", Dict())
    configure_input_method(profile_dir, input_config, packages)

    # Step 8: Configure desktop autologin
    println("\n$(MAGENTA)[8/14]$(RESET) 데스크톱 자동 로그인 설정 중...")
    desktop = get(get(config, "packages", Dict()), "desktop", Dict())
    configure_desktop_autologin(profile_dir, desktop)

    # Step 9: Configure install icon on desktop
    println("\n$(MAGENTA)[9/14]$(RESET) 설치 아이콘 생성 중...")
    configure_install_icon(profile_dir)

    # Step 10: Configure fastfetch with Blunux logo and os-release
    println("\n$(MAGENTA)[10/14]$(RESET) Fastfetch 및 OS 브랜딩 설정 중...")
    configure_fastfetch(profile_dir, build_name)

    # Step 11: Configure boot menu (Live + Install mode)
    println("\n$(MAGENTA)[11/14]$(RESET) 부트 메뉴 설정 중...")
    configure_boot_menu(profile_dir)

    # Step 12: Install Rust installer to profile
    println("\n$(MAGENTA)[12/14]$(RESET) Rust 인스톨러 설치 중...")
    if installer_binary !== nothing
        install_installer_to_profile(installer_binary, profile_dir)
        copy_config_to_profile(config_file, profile_dir)
    else
        print_warn("Installer not available, using archinstall fallback")
    end
    # Always update the install script with preparation steps
    update_install_script_for_installer(profile_dir)

    # Step 13: Build ISO
    println("\n$(MAGENTA)[13/14]$(RESET) ISO 빌드 중... (시간이 걸릴 수 있습니다)")
    iso_path = build_archiso(profile_dir, output_dir, build_name)

    # Step 14: Cleanup (optional)
    println("\n$(MAGENTA)[14/14]$(RESET) 정리 중...")

    return iso_path
end

"""
    main()

Main entry point.
"""
function main()
    print_banner()

    # Parse arguments
    args = parse_args(ARGS)

    # Check if config file exists
    print_info("설정 파일 로딩 중: $(BOLD)$(args.config_file)$(RESET)")

    if !isfile(args.config_file)
        println()
        print_error("설정 파일을 찾을 수 없습니다: $(BOLD)$(args.config_file)$(RESET)")
        println("""
$(YELLOW)해결 방법 / Solutions:$(RESET)

  1. 파일 이름을 확인하세요:
     $(CYAN)ls -la $(args.config_file)$(RESET)

  2. 예시 파일을 복사해서 사용하세요:
     $(CYAN)cp examples/korean-desktop.toml $(args.config_file)$(RESET)

  3. 웹 빌더에서 설정 파일을 다운로드하세요:
     $(CYAN)https://blunux.com/builder/$(RESET)

$(BOLD)사용 가능한 예시 파일:$(RESET)
""")
        # List example files if they exist
        examples_dir = joinpath(dirname(@__FILE__), "examples")
        if isdir(examples_dir)
            for f in readdir(examples_dir)
                if endswith(f, ".toml")
                    println("  - examples/$f")
                end
            end
        end
        println()
        exit(1)
    end

    config = TOML.parsefile(args.config_file)
    println("    빌드 이름: $(BOLD)$(config["blunux"]["name"])$(RESET)")

    # Validate config
    print_info("설정 파일 검증 중...")
    validate_config(config)
    print_success("설정 파일이 유효합니다.")

    # Check and install requirements
    req = check_and_install_requirements()

    # Build ISO
    try
        iso_path = build_iso(config, args, req.aur_helper)
        println()
        println("$(GREEN)" * "="^60 * "$(RESET)")
        println("$(GREEN)$(BOLD)[성공/SUCCESS]$(RESET) $(GREEN)ISO 빌드가 완료되었습니다!$(RESET)")
        println("    출력 파일: $(BOLD)$iso_path$(RESET)")
        println("$(GREEN)" * "="^60 * "$(RESET)")
        println()
        println("$(CYAN)다음 단계:$(RESET)")
        println("  1. USB에 ISO 쓰기: $(BOLD)sudo dd if=$iso_path of=/dev/sdX bs=4M status=progress$(RESET)")
        println("  2. 또는 Ventoy 사용: ISO 파일을 Ventoy USB에 복사")
        println()
    catch e
        println()
        print_error("빌드 실패: $e")
        rethrow(e)
    end
end

# Run main
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
