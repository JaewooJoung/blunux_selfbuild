#pragma once

#include <string>
#include <vector>
#include <map>
#include <optional>

namespace blunux {

struct BlunuxConfig {
    std::string version = "1.0";
    std::string name = "blunux";
};

struct LocaleConfig {
    std::vector<std::string> languages = {"ko_KR"};
    std::string timezone = "Asia/Seoul";
    std::vector<std::string> keyboards = {"us"};
};

struct InputMethodConfig {
    bool enabled = true;
    std::string engine = "kime";  // kime, fcitx5, ibus
};

struct KernelConfig {
    std::string type = "linux";  // linux, linux-lts, linux-zen
};

struct PackagesConfig {
    // Desktop - only KDE supported for simplicity
    bool kde = true;

    // Browsers
    bool firefox = true;
    bool whale = false;
    bool chrome = false;
    bool mullvad = false;

    // Office
    bool libreoffice = false;
    bool hoffice = false;
    bool texlive = false;

    // Development
    bool vscode = false;
    bool sublime = false;
    bool git = true;
    bool rust = false;
    bool julia = false;
    bool nodejs = false;
    bool github_cli = false;

    // Multimedia
    bool vlc = true;
    bool obs = false;
    bool freetv = false;
    bool ytdlp = false;
    bool freetube = false;

    // Gaming
    bool steam = false;
    bool unciv = false;
    bool snes9x = false;

    // Virtualization
    bool virtualbox = false;
    bool docker = false;

    // Communication
    bool teams = false;
    bool whatsapp = false;
    bool onenote = false;

    // Utility
    bool bluetooth = true;
    bool conky = false;
    bool vnc = false;
    bool samba = false;
};

struct InstallConfig {
    // Installation target
    std::string target_disk;
    std::string hostname = "blunux";
    std::string username = "user";
    std::string root_password;
    std::string user_password;

    // Partitioning
    bool use_encryption = false;
    std::string encryption_password;

    // Boot
    std::string bootloader = "grub";  // grub, systemd-boot, nmbl (EFISTUB direct boot, UEFI only)
    bool uefi = true;

    // Desktop
    bool autologin = true;  // Auto-login to KDE on boot
};

struct Config {
    BlunuxConfig blunux;
    LocaleConfig locale;
    InputMethodConfig input_method;
    KernelConfig kernel;
    PackagesConfig packages;
    InstallConfig install;

    // True when config was successfully loaded from a TOML file.
    // When true, all fields are trusted and interactive prompts are skipped.
    bool loaded_from_file = false;

    // Load config from TOML file
    static Config load(const std::string& path);

    // Get list of official packages to install (pacman)
    std::vector<std::string> get_package_list() const;

    // Get list of AUR packages to install (paru)
    std::vector<std::string> get_aur_package_list() const;

    // Get list of packages to install via individual scripts after first boot
    std::vector<std::string> get_script_package_list() const;
};

}  // namespace blunux
