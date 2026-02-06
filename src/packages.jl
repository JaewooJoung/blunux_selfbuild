#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 packages.jl                                                       ┃
#┃ 📙Brief     📝 Package Mapping Module for Blunux Self-Build                      ┃
#┃ 🧾Details   🔎 Maps TOML config keys to pacman/AUR packages with categories      ┃
#┃ 🚩OAuthor   🦋 Blunux Project                                                    ┃
#┃ 👨‍🔧LAuthor   👤 Blunux Project                                                    ┃
#┃ 📆LastDate  📍 2026-01-25 🔄Please support to keep update🔄                      ┃
#┃ 🏭License   📜 MIT License                                                       ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#=
Package mapping module for Blunux Self-Build Tool

Maps TOML configuration keys to actual pacman and AUR packages.
=#

"""
Package mapping structure.
Keys are TOML config keys, values are tuples of (pacman_packages, aur_packages).
"""
const PACKAGE_MAPPING = Dict{String, Dict{String, Tuple{Vector{String}, Vector{String}}}}(
    # Desktop environments
    "desktop" => Dict(
        # KDE Plasma 6 with SDDM - using individual packages instead of kde-applications-meta to avoid kmix
        # Using Wayland session by default, xorg-xwayland for X11 app compatibility
        "kde" => (["plasma-meta", "sddm", "xorg-xwayland",
                   # Essential KDE applications (without kmix)
                   "dolphin", "konsole", "kate", "ark", "gwenview", "okular", "spectacle",
                   "kwalletmanager", "kcalc", "plasma-systemmonitor", "kde-gtk-config",
                   "kio-extras", "kdegraphics-thumbnailers", "ffmpegthumbs",
                   "plasma-pa", "plasma-nm", "plasma-firewall",
                   "partitionmanager", "filelight", "ksystemlog"
                  ], String[]),
        "gnome" => (["gnome", "gnome-extra", "gdm"], String[]),
        "xfce" => (["xfce4", "xfce4-goodies", "lightdm", "lightdm-gtk-greeter"], String[]),
        "cinnamon" => (["cinnamon", "nemo", "lightdm", "lightdm-gtk-greeter"], String[]),
        "mate" => (["mate", "mate-extra", "lightdm", "lightdm-gtk-greeter"], String[]),
        "budgie" => (["budgie-desktop", "gnome-terminal", "nautilus", "lightdm", "lightdm-gtk-greeter"], String[]),
        "lxqt" => (["lxqt", "sddm", "xorg-server", "xorg-xinit"], String[]),  # LXQt still needs X11
        "deepin" => (["deepin", "deepin-extra", "lightdm", "lightdm-deepin-greeter"], String[]),
    ),

    # Web browsers
    "browser" => Dict(
        "firefox" => (["firefox"], String[]),
        "chromium" => (["chromium"], String[]),
        "whale" => (String[], ["naver-whale-stable"]),
        "chrome" => (String[], ["google-chrome"]),
        "mullvad" => (String[], ["mullvad-browser-bin"]),
        "brave" => (String[], ["brave-bin"]),
        "vivaldi" => (["vivaldi"], String[]),
        "epiphany" => (["epiphany"], String[]),
    ),

    # Office applications
    "office" => Dict(
        "libreoffice" => (["libreoffice-fresh"], String[]),
        "hoffice" => (String[], ["hoffice"]),
        "onlyoffice" => (String[], ["onlyoffice-bin"]),
        "wps" => (String[], ["wps-office"]),
        "texlive" => (["texlive-core", "texlive-bin", "texstudio"], String[]),
        "latex" => (["texlive-core", "texlive-bin", "texlive-latexextra"], String[]),
    ),

    # Development tools
    "development" => Dict(
        "vscode" => (String[], ["visual-studio-code-bin"]),
        "vscodium" => (String[], ["vscodium-bin"]),
        "sublime" => (String[], ["sublime-text-4"]),
        "atom" => (String[], ["atom-bin"]),
        "neovim" => (["neovim"], String[]),
        "emacs" => (["emacs"], String[]),
        "rust" => (["rustup"], String[]),
        "julia" => (String[], ["juliaup"]),
        "nodejs" => (["nodejs", "npm"], String[]),
        "python" => (["python", "python-pip"], String[]),
        "go" => (["go"], String[]),
        "java" => (["jdk-openjdk"], String[]),
        "github_cli" => (["github-cli"], String[]),
        "git" => (["git", "git-lfs"], String[]),
        "docker" => (["docker", "docker-compose"], String[]),
    ),

    # Multimedia
    "multimedia" => Dict(
        "obs" => (["obs-studio", "v4l2loopback-dkms"], String[]),
        "vlc" => (["vlc"], String[]),
        "mpv" => (["mpv"], String[]),
        "freetv" => (String[], ["freetuxtv"]),
        "ytdlp" => (["yt-dlp"], String[]),
        "freetube" => (String[], ["freetube-bin"]),
        "spotify" => (String[], ["spotify"]),
        "audacity" => (["audacity"], String[]),
        "gimp" => (["gimp"], String[]),
        "inkscape" => (["inkscape"], String[]),
        "kdenlive" => (["kdenlive"], String[]),
        "blender" => (["blender"], String[]),
        "krita" => (["krita"], String[]),
    ),

    # Gaming
    "gaming" => Dict(
        "steam" => (["steam"], String[]),
        "lutris" => (["lutris"], String[]),
        "wine" => (["wine", "wine-mono", "wine-gecko", "winetricks"], String[]),
        "unciv" => (String[], ["unciv-bin"]),
        "snes9x" => (String[], ["snes9x-git"]),
        "retroarch" => (["retroarch"], String[]),
        "gamemode" => (["gamemode", "lib32-gamemode"], String[]),
        "mangohud" => (["mangohud", "lib32-mangohud"], String[]),
    ),

    # Virtualization
    "virtualization" => Dict(
        "virtualbox" => (["virtualbox", "virtualbox-host-modules-arch"], String[]),
        "qemu" => (["qemu-full", "virt-manager", "libvirt", "dnsmasq"], String[]),
        "docker" => (["docker", "docker-compose"], String[]),
        "podman" => (["podman", "buildah", "skopeo"], String[]),
        "vmware" => (String[], ["vmware-workstation"]),
    ),

    # Communication
    "communication" => Dict(
        "discord" => (["discord"], String[]),
        "teams" => (String[], ["teams-for-linux"]),
        "slack" => (String[], ["slack-desktop"]),
        "whatsapp" => (String[], ["whatsapp-for-linux"]),
        "telegram" => (["telegram-desktop"], String[]),
        "signal" => (["signal-desktop"], String[]),
        "element" => (["element-desktop"], String[]),
        "onenote" => (String[], ["p3x-onenote-bin"]),
        "zoom" => (String[], ["zoom"]),
    ),

    # System utilities
    "utility" => Dict(
        "conky" => (["conky"], String[]),
        "vnc" => (String[], ["realvnc-vnc-server"]),
        "tigervnc" => (["tigervnc"], String[]),
        "samba" => (["samba"], String[]),
        "bluetooth" => (["bluez", "bluez-utils", "bluedevil", "blueman"], String[]),
        "printing" => (["cups", "cups-pdf", "system-config-printer"], String[]),
        "flatpak" => (["flatpak"], String[]),
        "snapd" => (String[], ["snapd"]),
        "timeshift" => (String[], ["timeshift"]),
        "htop" => (["htop"], String[]),
        "neofetch" => (["neofetch"], String[]),
        "fastfetch" => (["fastfetch"], String[]),
        "bashtop" => (["bashtop"], String[]),
    ),
)

"""
Input method packages mapping.
"""
const INPUT_METHOD_MAPPING = Dict{String, Tuple{Vector{String}, Vector{String}}}(
    # Korean
    "kime" => (String[], ["kime", "kime-qt6"]),
    "fcitx5-hangul" => (["fcitx5", "fcitx5-hangul", "fcitx5-qt", "fcitx5-gtk"], String[]),
    "ibus-hangul" => (["ibus", "ibus-hangul"], String[]),

    # Chinese
    "fcitx5" => (["fcitx5", "fcitx5-chinese-addons", "fcitx5-qt", "fcitx5-gtk"], String[]),
    "fcitx5-rime" => (["fcitx5", "fcitx5-rime", "fcitx5-qt", "fcitx5-gtk"], String[]),
    "ibus-libpinyin" => (["ibus", "ibus-libpinyin"], String[]),

    # Japanese
    "fcitx5-mozc" => (["fcitx5", "fcitx5-mozc", "fcitx5-qt", "fcitx5-gtk"], String[]),
    "fcitx5-anthy" => (["fcitx5", "fcitx5-anthy", "fcitx5-qt", "fcitx5-gtk"], String[]),
    "ibus-mozc" => (["ibus"], ["ibus-mozc"]),
    "ibus-anthy" => (["ibus", "ibus-anthy"], String[]),
)

"""
Kernel packages mapping.
"""
const KERNEL_MAPPING = Dict{String, Tuple{Vector{String}, Vector{String}}}(
    "linux" => (["linux", "linux-headers"], String[]),
    "linux-bore" => (String[], ["linux-cachyos", "linux-cachyos-headers"]),
    "linux-zen" => (["linux-zen", "linux-zen-headers"], String[]),
    "linux-lts" => (["linux-lts", "linux-lts-headers"], String[]),
    "linux-hardened" => (["linux-hardened", "linux-hardened-headers"], String[]),
    "linux-cachyos" => (String[], ["linux-cachyos", "linux-cachyos-headers"]),
)

"""
Base packages always included in the build.
"""
const BASE_PACKAGES = [
    # Core system
    "base",
    "base-devel",
    "linux-firmware",
    "networkmanager",
    "nano",
    "vim",
    "sudo",
    # ============================================
    # CPU microcode (critical for stability)
    # ============================================
    "amd-ucode",                 # AMD CPU microcode updates
    "intel-ucode",               # Intel CPU microcode updates
    # Bootloader
    "grub",
    "efibootmgr",
    "os-prober",
    # Filesystem
    "ntfs-3g",
    "dosfstools",
    "mtools",
    "btrfs-progs",               # Btrfs filesystem tools
    # Package management
    "archlinux-keyring",
    "reflector",
    "pacman-contrib",
    # System info & hardware detection
    "fastfetch",
    "hwdetect",                  # Hardware detection
    "hwinfo",                    # Hardware info
    "dmidecode",                 # BIOS/hardware info
    # ============================================
    # Input device drivers (keyboard/mouse/touchpad)
    # ============================================
    # Per CachyOS: Removed xorg dependencies for Wayland desktops
    # KDE Plasma 6 uses Wayland by default, X11 apps run via XWayland
    "libinput",                  # Input device library (Wayland native)
    "xdg-desktop-portal",        # Desktop integration portals
    "xdg-desktop-portal-kde",    # KDE portal backend
    # Fonts (Korean/CJK support)
    "noto-fonts",                # Base Noto fonts
    "noto-fonts-cjk",            # Chinese/Japanese/Korean glyphs
    "noto-fonts-emoji",          # Emoji support
    "adobe-source-han-sans-kr-fonts",   # Source Han Sans Korean
    "adobe-source-han-serif-kr-fonts",  # Source Han Serif Korean
    "terminus-font",             # Console font for vconsole.conf
    # USB support
    "usbutils",                  # USB debugging tools (lsusb)
    "usbmuxd",                   # USB multiplexing daemon
    # ============================================
    # VM guest support (for running in VirtualBox/QEMU/VMware)
    # ============================================
    "spice-vdagent",             # QEMU/KVM guest agent (clipboard, resolution)
    "qemu-guest-agent",          # QEMU guest agent
    "open-vm-tools",             # VMware guest tools
    "virtualbox-guest-utils",    # VirtualBox guest additions (X11 version, -nox removed from releng)
]

"""
    CollectedPackages

Structure to hold collected packages separated by source.
"""
struct CollectedPackages
    pacman::Vector{String}
    aur::Vector{String}
end

"""
    collect_packages(config, aur_helper)

Collect all packages from the configuration.
Returns a CollectedPackages struct with pacman and AUR packages.
"""
function collect_packages(config, aur_helper)
    pacman_pkgs = copy(BASE_PACKAGES)
    aur_pkgs = String[]

    # Remove GRUB packages if bootloader is "nmbl" (EFISTUB direct boot)
    bootloader = get(get(config, "install", Dict()), "bootloader", "grub")
    if bootloader == "nmbl"
        filter!(p -> p ∉ ["grub", "os-prober"], pacman_pkgs)
        println("    Bootloader: nmbl (EFISTUB direct boot, no GRUB)")
    else
        println("    Bootloader: $bootloader")
    end

    # Add kernel packages
    kernel_type = get(get(config, "kernel", Dict()), "type", "linux-bore")
    if haskey(KERNEL_MAPPING, kernel_type)
        kern_pacman, kern_aur = KERNEL_MAPPING[kernel_type]
        append!(pacman_pkgs, kern_pacman)
        append!(aur_pkgs, kern_aur)
        println("    Kernel: $kernel_type")
    else
        @warn "Unknown kernel type: $kernel_type, using linux"
        append!(pacman_pkgs, ["linux", "linux-headers"])
    end

    # Add input method packages
    if haskey(config, "input_method")
        im_config = config["input_method"]
        if get(im_config, "enabled", false)
            engine = get(im_config, "engine", "")
            if haskey(INPUT_METHOD_MAPPING, engine)
                im_pacman, im_aur = INPUT_METHOD_MAPPING[engine]
                append!(pacman_pkgs, im_pacman)
                append!(aur_pkgs, im_aur)
                println("    Input method: $engine")
            else
                @warn "Unknown input method engine: $engine"
            end
        end
    end

    # Process packages section
    if haskey(config, "packages")
        packages_config = config["packages"]

        for (category, items) in packages_config
            if !haskey(PACKAGE_MAPPING, category)
                @warn "Unknown package category: $category"
                continue
            end

            category_mapping = PACKAGE_MAPPING[category]

            for (pkg_name, enabled) in items
                if enabled == true || enabled == 1
                    if haskey(category_mapping, pkg_name)
                        pkg_pacman, pkg_aur = category_mapping[pkg_name]
                        append!(pacman_pkgs, pkg_pacman)
                        append!(aur_pkgs, pkg_aur)
                        println("    [$category] $pkg_name")
                    else
                        @warn "Unknown package in $category: $pkg_name"
                    end
                end
            end
        end
    end

    # Remove duplicates
    pacman_pkgs = unique(pacman_pkgs)
    aur_pkgs = unique(aur_pkgs)

    # Warn if AUR packages but no helper
    if !isempty(aur_pkgs) && aur_helper === nothing
        @warn "AUR packages selected but no AUR helper available: $(join(aur_pkgs, ", "))"
    end

    return CollectedPackages(pacman_pkgs, aur_pkgs)
end

"""
    get_package_list_string(packages::CollectedPackages)

Get a string representation of all packages for inclusion in archiso.
"""
function get_package_list_string(packages::CollectedPackages)
    all_pkgs = vcat(packages.pacman, packages.aur)
    return join(all_pkgs, "\n")
end
