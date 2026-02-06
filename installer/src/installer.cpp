#include "installer.hpp"
#include "tui.hpp"
#include <fstream>
#include <sstream>
#include <cstdlib>
#include <array>
#include <memory>
#include <filesystem>
#include <algorithm>

namespace blunux {

namespace {

std::string exec(const std::string& cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) return "";
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

}  // namespace

Installer::Installer(const Config& config) : config_(config) {}

void Installer::set_progress_callback(ProgressCallback callback) {
    progress_callback_ = callback;
}

void Installer::report_progress(int step, int total, const std::string& message) {
    if (progress_callback_) {
        progress_callback_(step, total, message);
    } else {
        tui::print_step(step, total, message);
    }
}

bool Installer::run_command(const std::string& cmd) {
    return system(cmd.c_str()) == 0;
}

bool Installer::run_chroot(const std::string& cmd) {
    std::string full_cmd = "arch-chroot " + mount_point_ + " " + cmd;
    return run_command(full_cmd);
}

bool Installer::write_file(const std::string& path, const std::string& content) {
    std::ofstream file(path);
    if (!file) {
        error_message_ = "Failed to write file: " + path;
        return false;
    }
    file << content;
    return true;
}

bool Installer::append_file(const std::string& path, const std::string& content) {
    std::ofstream file(path, std::ios::app);
    if (!file) {
        error_message_ = "Failed to append to file: " + path;
        return false;
    }
    file << content;
    return true;
}

std::vector<std::string> Installer::get_base_packages() const {
    // Determine kernel to install via pacstrap
    // linux-bore is AUR, so use "linux" as fallback for initial install
    std::string kernel = config_.kernel.type;
    if (kernel == "linux-bore") {
        kernel = "linux";  // Fallback - linux-bore installed via AUR after first boot
    }

    std::vector<std::string> packages = {
        // Base system
        "base",
        kernel,
        kernel + "-headers",
        "linux-firmware",

        // Essential tools
        "base-devel",
        "sudo",
        "nano",
        "vim",
        "networkmanager",
        "network-manager-applet",

        // Bootloader
        "efibootmgr",

        // Filesystem tools
        "dosfstools",
        "ntfs-3g",
        "btrfs-progs",

        // Hardware support
        "intel-ucode",
        "amd-ucode",

        // Fonts (base)
        "noto-fonts",
        "noto-fonts-cjk",
        "noto-fonts-emoji",
        "ttf-liberation",

        // Utilities
        "git",
        "wget",
        "curl",
        "fastfetch",
        "htop",
        "man-db",
        "man-pages"
    };

    // Add GRUB packages only when not using NMBL (EFISTUB)
    if (config_.install.bootloader != "nmbl") {
        packages.push_back("grub");
        packages.push_back("os-prober");
    }

    return packages;
}

std::vector<std::string> Installer::get_desktop_packages() const {
    // KDE Plasma packages
    return {
        // Display server and compositor
        "xorg-server",
        "xorg-xinit",
        "wayland",

        // KDE Plasma (without kde-applications-meta to avoid kmix)
        "plasma-meta",
        "sddm",

        // Essential KDE applications
        "konsole",
        "dolphin",
        "kate",
        "ark",
        "gwenview",
        "okular",
        "spectacle",
        "kwalletmanager",
        "kcalc",
        "plasma-systemmonitor",
        "kde-gtk-config",
        "kio-extras",
        "kdegraphics-thumbnailers",
        "ffmpegthumbs",
        "plasma-pa",
        "plasma-nm",
        "plasma-firewall",
        "partitionmanager",
        "filelight",
        "ksystemlog",

        // Pipewire audio
        "pipewire",
        "pipewire-alsa",
        "pipewire-pulse",
        "pipewire-jack",
        "wireplumber",

        // Printing support (optional)
        "cups",
        "print-manager"
    };
}

std::vector<std::string> Installer::get_font_packages() const {
    std::vector<std::string> fonts;

    // Base fonts
    fonts.push_back("noto-fonts");
    fonts.push_back("noto-fonts-emoji");

    // CJK fonts based on locale
    auto has_lang = [&](const std::string& prefix) {
        for (const auto& lang : config_.locale.languages) {
            if (lang.find(prefix) != std::string::npos) return true;
        }
        return false;
    };

    if (has_lang("ko") || has_lang("ja") || has_lang("zh")) {
        fonts.push_back("noto-fonts-cjk");

        // Korean specific
        if (has_lang("ko")) {
            fonts.push_back("ttf-baekmuk");
        }
    }

    return fonts;
}

std::vector<std::string> Installer::get_input_method_packages() const {
    std::vector<std::string> packages;

    if (!config_.input_method.enabled) {
        return packages;
    }

    if (config_.input_method.engine == "kime") {
        // kime-git is AUR, handled separately
        // But we need Qt/GTK integration libraries (official repos)
        packages.push_back("gtk3");
        packages.push_back("gtk4");
        packages.push_back("qt5-base");
        packages.push_back("qt6-base");
        packages.push_back("qt6-tools");
    } else if (config_.input_method.engine == "fcitx5") {
        packages.push_back("fcitx5");
        packages.push_back("fcitx5-configtool");
        packages.push_back("fcitx5-gtk");
        packages.push_back("fcitx5-qt");

        // Language-specific addons
        auto has_lang = [&](const std::string& prefix) {
            for (const auto& lang : config_.locale.languages) {
                if (lang.find(prefix) != std::string::npos) return true;
            }
            return false;
        };

        if (has_lang("ko")) {
            packages.push_back("fcitx5-hangul");
        }
        if (has_lang("ja")) {
            packages.push_back("fcitx5-mozc");
        }
        if (has_lang("zh")) {
            packages.push_back("fcitx5-chinese-addons");
        }
    } else if (config_.input_method.engine == "ibus") {
        packages.push_back("ibus");

        auto has_lang = [&](const std::string& prefix) {
            for (const auto& lang : config_.locale.languages) {
                if (lang.find(prefix) != std::string::npos) return true;
            }
            return false;
        };

        if (has_lang("ko")) {
            packages.push_back("ibus-hangul");
        }
        if (has_lang("ja")) {
            packages.push_back("ibus-mozc");
        }
    }

    return packages;
}

bool Installer::install() {
    const int total_steps = 9;

    // Step 1: Prepare disk
    report_progress(1, total_steps, "Preparing disk / 디스크 준비 중...");
    if (!prepare_disk()) {
        return false;
    }

    // Step 2: Install base system
    report_progress(2, total_steps, "Installing base system / 기본 시스템 설치 중...");
    if (!install_base_system()) {
        return false;
    }

    // Step 3: Generate fstab
    report_progress(3, total_steps, "Generating fstab / fstab 생성 중...");
    if (!disk::generate_fstab(mount_point_)) {
        error_message_ = "Failed to generate fstab";
        return false;
    }

    // Step 4: Configure system
    report_progress(4, total_steps, "Configuring system / 시스템 설정 중...");
    if (!configure_system()) {
        return false;
    }

    // Step 5: Install packages
    report_progress(5, total_steps, "Installing packages / 패키지 설치 중...");
    if (!install_packages()) {
        return false;
    }

    // Step 6: Configure locale and input method
    report_progress(6, total_steps, "Configuring locale / 로케일 설정 중...");
    if (!configure_locale()) {
        return false;
    }
    if (!configure_input_method()) {
        return false;
    }

    // Step 7: Configure users
    report_progress(7, total_steps, "Configuring users / 사용자 설정 중...");
    if (!configure_users()) {
        return false;
    }

    // Step 8: Install bootloader
    report_progress(8, total_steps, "Installing bootloader / 부트로더 설치 중...");
    if (!install_bootloader()) {
        return false;
    }

    // Step 9: Finalize
    report_progress(9, total_steps, "Finalizing / 마무리 중...");
    if (!finalize()) {
        return false;
    }

    return true;
}

bool Installer::prepare_disk() {
    disk::PartitionScheme scheme = disk::is_uefi()
        ? disk::PartitionScheme::GPT_UEFI
        : disk::PartitionScheme::MBR_BIOS;

    auto layout = disk::partition_disk(config_.install.target_disk, scheme);
    if (!layout) {
        error_message_ = "Failed to partition disk";
        return false;
    }

    partition_layout_ = *layout;

    if (!disk::format_partitions(partition_layout_,
                                  config_.install.use_encryption,
                                  config_.install.encryption_password)) {
        error_message_ = "Failed to format partitions";
        return false;
    }

    if (!disk::mount_partitions(partition_layout_, mount_point_)) {
        error_message_ = "Failed to mount partitions";
        return false;
    }

    return true;
}

bool Installer::install_base_system() {
    // Collect core system packages only
    // Optional packages (browsers, office, dev tools, etc.) are installed
    // after first boot via ~/install-packages.sh
    auto base_packages = get_base_packages();
    auto desktop_packages = get_desktop_packages();
    auto font_packages = get_font_packages();
    auto im_packages = get_input_method_packages();

    // Merge all core packages
    std::vector<std::string> all_packages;
    all_packages.insert(all_packages.end(), base_packages.begin(), base_packages.end());
    all_packages.insert(all_packages.end(), desktop_packages.begin(), desktop_packages.end());
    all_packages.insert(all_packages.end(), font_packages.begin(), font_packages.end());
    all_packages.insert(all_packages.end(), im_packages.begin(), im_packages.end());

    // Build pacstrap command
    std::string cmd = "pacstrap -K " + mount_point_;
    for (const auto& pkg : all_packages) {
        cmd += " " + pkg;
    }

    tui::print_info("Installing packages with pacstrap...");
    tui::print_info("This may take several minutes...");

    if (!run_command(cmd)) {
        error_message_ = "pacstrap failed";
        return false;
    }

    return true;
}

bool Installer::configure_system() {
    // Set timezone
    std::string tz_cmd = "ln -sf /usr/share/zoneinfo/" + config_.locale.timezone +
                         " /etc/localtime";
    run_chroot(tz_cmd);
    run_chroot("hwclock --systohc");

    // Set hostname
    write_file(mount_point_ + "/etc/hostname", config_.install.hostname + "\n");

    // Configure hosts file
    std::string hosts = "127.0.0.1    localhost\n"
                        "::1          localhost\n"
                        "127.0.1.1    " + config_.install.hostname + ".localdomain " +
                        config_.install.hostname + "\n";
    write_file(mount_point_ + "/etc/hosts", hosts);

    // Enable essential services
    run_chroot("systemctl enable NetworkManager");
    run_chroot("systemctl enable sddm");

    // Note: bluetooth service is enabled by bluetooth.sh post-install script

    // Enable CUPS if printing support is needed
    run_chroot("systemctl enable cups 2>/dev/null || true");

    // Create 8GB swap file
    tui::print_info("Creating 8GB swap file...");
    std::string swapfile = mount_point_ + "/swapfile";

    // Create swap file using dd (8GB = 8192 MB)
    run_command("dd if=/dev/zero of=" + swapfile + " bs=1M count=8192 status=progress");
    run_command("chmod 600 " + swapfile);
    run_chroot("mkswap /swapfile");

    // Add swap to fstab for persistent activation
    std::string fstab_path = mount_point_ + "/etc/fstab";
    append_file(fstab_path, "\n# Swap file\n/swapfile none swap defaults 0 0\n");

    tui::print_success("8GB swap file created and configured");

    return true;
}

bool Installer::install_packages() {
    // Additional packages from config (already done in base system)
    // This step can be used for AUR packages in the future
    return true;
}

bool Installer::configure_locale() {
    // Configure locale.gen - add all configured languages
    std::string locale_gen_path = mount_point_ + "/etc/locale.gen";
    std::string locale;
    for (const auto& lang : config_.locale.languages) {
        locale += lang + ".UTF-8 UTF-8\n";
    }
    // Always include en_US as fallback
    if (std::find(config_.locale.languages.begin(), config_.locale.languages.end(), "en_US") == config_.locale.languages.end()) {
        locale += "en_US.UTF-8 UTF-8\n";
    }
    append_file(locale_gen_path, locale);

    // Generate locales
    run_chroot("locale-gen");

    // Set default locale (first language in the list)
    std::string default_lang = config_.locale.languages.empty() ? "en_US" : config_.locale.languages[0];
    std::string locale_conf = "LANG=" + default_lang + ".UTF-8\n";
    write_file(mount_point_ + "/etc/locale.conf", locale_conf);

    // Configure keyboard
    if (!config_.locale.keyboards.empty()) {
        std::string vconsole = "KEYMAP=" + config_.locale.keyboards[0] + "\n";
        write_file(mount_point_ + "/etc/vconsole.conf", vconsole);
    }

    return true;
}

bool Installer::configure_input_method() {
    if (!config_.input_method.enabled) {
        return true;
    }

    // Create environment file for input method
    std::string env_content;

    if (config_.input_method.engine == "kime") {
        env_content = R"(
# Kime Korean Input Method
GTK_IM_MODULE=kime
QT_IM_MODULE=kime
XMODIFIERS=@im=kime
)";
    } else if (config_.input_method.engine == "fcitx5") {
        env_content = R"(
# Fcitx5 Input Method
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
)";
    } else if (config_.input_method.engine == "ibus") {
        env_content = R"(
# IBus Input Method
GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
)";
    }

    if (!env_content.empty()) {
        write_file(mount_point_ + "/etc/environment.d/input-method.conf", env_content);
    }

    return true;
}

bool Installer::configure_users() {
    // Set root password
    std::string root_cmd = "echo 'root:" + config_.install.root_password +
                           "' | chpasswd";
    run_chroot("sh -c \"" + root_cmd + "\"");

    // Create user
    run_chroot("useradd -m -G wheel,audio,video,storage,optical -s /bin/bash " +
               config_.install.username);

    // Set user password
    std::string user_cmd = "echo '" + config_.install.username + ":" +
                           config_.install.user_password + "' | chpasswd";
    run_chroot("sh -c \"" + user_cmd + "\"");

    // Configure sudo for wheel group
    std::string sudoers = mount_point_ + "/etc/sudoers.d/wheel";
    write_file(sudoers, "%wheel ALL=(ALL:ALL) ALL\n");
    run_command("chmod 440 " + sudoers);

    // Configure SDDM autologin if enabled
    if (config_.install.autologin) {
        std::string sddm_conf_dir = mount_point_ + "/etc/sddm.conf.d";
        run_command("mkdir -p " + sddm_conf_dir);

        std::string autologin_conf = sddm_conf_dir + "/autologin.conf";
        std::string autologin_content =
            "[Autologin]\n"
            "User=" + config_.install.username + "\n"
            "Session=plasma\n"
            "Relogin=true\n";

        write_file(autologin_conf, autologin_content);
        tui::print_success("SDDM autologin configured for user: " + config_.install.username);
    }

    return true;
}

bool Installer::install_bootloader() {
    if (config_.install.bootloader == "nmbl") {
        // NMBL: No More Boot Loader - EFISTUB direct boot (UEFI only)
        if (!disk::is_uefi()) {
            tui::print_error("NMBL (EFISTUB) requires UEFI. This system uses BIOS.");
            tui::print_info("Falling back to GRUB...");
            // Fall through to GRUB below
        } else {
            tui::print_info("NMBL: Configuring EFISTUB direct boot (no bootloader)...");

            // Determine kernel name
            std::string kernel = config_.kernel.type;
            if (kernel == "linux-bore") {
                kernel = "linux";  // Fallback until linux-bore is installed post-boot
            }

            // Get root partition UUID
            std::string root_uuid = exec("blkid -s UUID -o value " + partition_layout_.root_partition);
            // Trim newline
            while (!root_uuid.empty() && (root_uuid.back() == '\n' || root_uuid.back() == '\r')) {
                root_uuid.pop_back();
            }

            // Build kernel parameters
            std::string root_param;
            if (config_.install.use_encryption) {
                root_param = "cryptdevice=UUID=" + root_uuid + ":cryptroot root=/dev/mapper/cryptroot";
            } else {
                root_param = "root=UUID=" + root_uuid;
            }
            std::string kernel_params = root_param + " rw quiet loglevel=3";

            // Copy kernel and initramfs to ESP for direct UEFI access
            run_chroot("mkdir -p /boot/efi/EFI/Blunux");
            run_chroot("cp /boot/vmlinuz-" + kernel + " /boot/efi/EFI/Blunux/vmlinuz-" + kernel);
            run_chroot("cp /boot/initramfs-" + kernel + ".img /boot/efi/EFI/Blunux/initramfs-" + kernel + ".img");

            // Get the ESP disk and partition number for efibootmgr
            std::string efi_part = partition_layout_.efi_partition;
            std::string efi_disk;
            std::string efi_part_num;

            // Parse: /dev/sda1 -> disk=/dev/sda, part=1
            //        /dev/nvme0n1p1 -> disk=/dev/nvme0n1, part=1
            if (efi_part.find("nvme") != std::string::npos || efi_part.find("mmcblk") != std::string::npos) {
                // /dev/nvme0n1p1 -> disk=/dev/nvme0n1, part_num=1
                size_t p_pos = efi_part.rfind('p');
                efi_disk = efi_part.substr(0, p_pos);
                efi_part_num = efi_part.substr(p_pos + 1);
            } else {
                // /dev/sda1 -> disk=/dev/sda, part_num=1
                size_t num_start = efi_part.find_last_not_of("0123456789") + 1;
                efi_disk = efi_part.substr(0, num_start);
                efi_part_num = efi_part.substr(num_start);
            }

            // Create UEFI boot entry via efibootmgr
            std::string efi_cmd = "efibootmgr --create"
                " --disk " + efi_disk +
                " --part " + efi_part_num +
                " --label \"Blunux\"" +
                " --loader \"\\EFI\\Blunux\\vmlinuz-" + kernel + "\"" +
                " --unicode \"" + kernel_params +
                " initrd=\\EFI\\Blunux\\initramfs-" + kernel + ".img\"";

            if (!run_chroot(efi_cmd)) {
                tui::print_error("Failed to create UEFI boot entry");
                return false;
            }

            // Create a pacman hook to update ESP kernel on upgrades
            std::string hooks_dir = mount_point_ + "/etc/pacman.d/hooks";
            run_command("mkdir -p " + hooks_dir);

            std::string hook_content =
                "[Trigger]\n"
                "Type = Package\n"
                "Operation = Upgrade\n"
                "Target = " + kernel + "\n"
                "\n"
                "[Action]\n"
                "Description = Updating kernel in ESP for EFISTUB boot...\n"
                "When = PostTransaction\n"
                "Exec = /usr/local/bin/nmbl-update\n"
                "Depends = coreutils\n";
            write_file(hooks_dir + "/99-nmbl-kernel-update.hook", hook_content);

            // Create the update script
            std::string update_script =
                "#!/bin/bash\n"
                "# NMBL: Copy updated kernel/initramfs to ESP\n"
                "cp /boot/vmlinuz-" + kernel + " /boot/efi/EFI/Blunux/vmlinuz-" + kernel + "\n"
                "cp /boot/initramfs-" + kernel + ".img /boot/efi/EFI/Blunux/initramfs-" + kernel + ".img\n";
            write_file(mount_point_ + "/usr/local/bin/nmbl-update", update_script);
            run_command("chmod +x " + mount_point_ + "/usr/local/bin/nmbl-update");

            tui::print_success("NMBL: EFISTUB direct boot configured - no bootloader installed!");
            return true;
        }
    }

    // GRUB (default)
    if (disk::is_uefi()) {
        // Install GRUB for UEFI
        run_chroot("grub-install --target=x86_64-efi --efi-directory=/boot/efi "
                   "--bootloader-id=Blunux");
    } else {
        // Install GRUB for BIOS
        run_chroot("grub-install --target=i386-pc " + config_.install.target_disk);
    }

    // Configure GRUB to boot directly without showing menu
    // User can still access menu by holding Shift during boot
    tui::print_info("Configuring GRUB for direct boot...");
    run_chroot("sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub");
    run_chroot("sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub");
    // Add GRUB_TIMEOUT_STYLE if it doesn't exist
    run_chroot("grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub || echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub");

    // Generate GRUB config
    run_chroot("grub-mkconfig -o /boot/grub/grub.cfg");

    return true;
}

bool Installer::finalize() {
    std::string user_home = mount_point_ + "/home/" + config_.install.username;
    std::string username = config_.install.username;

    // ========================================
    // 1. Copy Blunux branding (fastfetch, os-release)
    // ========================================
    tui::print_info("Copying Blunux configuration...");

    // Fastfetch config
    std::string ff_config_dir = user_home + "/.config/fastfetch";
    run_command("mkdir -p " + ff_config_dir);
    if (run_command("test -f /etc/fastfetch/config.jsonc")) {
        run_command("cp /etc/fastfetch/config.jsonc " + ff_config_dir + "/");
        run_command("cp /etc/fastfetch/blunux-logo.txt " + ff_config_dir + "/ 2>/dev/null || true");
    }
    run_command("mkdir -p " + mount_point_ + "/etc/fastfetch");
    run_command("cp -r /etc/fastfetch/* " + mount_point_ + "/etc/fastfetch/ 2>/dev/null || true");

    // OS branding
    if (run_command("test -f /etc/os-release")) {
        run_command("cp /etc/os-release " + mount_point_ + "/etc/os-release");
        run_command("mkdir -p " + mount_point_ + "/usr/lib");
        run_command("cp /etc/os-release " + mount_point_ + "/usr/lib/os-release");
    }
    tui::print_success("Blunux branding configured");

    // ========================================
    // 2. Create package installation script (post-first-boot)
    // ========================================
    // All optional packages (browsers, office, dev tools, etc.) are installed
    // after first boot by downloading individual scripts from the Blunux repository.
    // This avoids unreliable yay/AUR builds inside chroot during installation.
    auto script_packages = config_.get_script_package_list();
    if (!script_packages.empty()) {
        tui::print_info("Creating package installation script...");
        std::string script_path = user_home + "/install-packages.sh";
        std::string pkg_script = R"(#!/bin/bash
# Blunux Package Installation Script (auto-generated by installer)
# Run this after first boot to install selected packages
# Each package is installed via its own script from the Blunux repository

BASE_URL="https://jaewoojoung.github.io/linux"

# Install yay if not present (needed by most package scripts)
if ! command -v yay &> /dev/null; then
    echo "=========================================="
    echo "  Installing yay AUR helper"
    echo "=========================================="
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    rm -rf yay-bin
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin
    echo ""
fi

FAILED_PACKAGES=()

install_package() {
    local pkg="$1"
    local script="/tmp/blunux-install-$pkg.sh"
    echo "=========================================="
    echo "  Installing: $pkg"
    echo "=========================================="
    if curl -fsSL "$BASE_URL/$pkg.sh" -o "$script"; then
        chmod +x "$script"
        if bash "$script"; then
            echo "$pkg installed successfully"
        else
            echo "WARNING: $pkg installation failed"
            FAILED_PACKAGES+=("$pkg")
        fi
        rm -f "$script"
    else
        echo "WARNING: Failed to download $pkg.sh"
        FAILED_PACKAGES+=("$pkg")
    fi
    echo ""
}

# Selected packages:
)";
        for (const auto& pkg : script_packages) {
            pkg_script += "install_package \"" + pkg + "\"\n";
        }
        pkg_script += R"(
echo "=========================================="
echo "  Package installation complete!"
echo "=========================================="
echo ""
if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo "The following packages failed to install:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo "  - $pkg"
    done
    echo ""
    echo "You can retry failed packages by running:"
    echo "  bash ~/install-packages.sh"
else
    echo "All packages installed successfully!"
fi
echo ""
echo "Please log out and log back in for changes to take effect."
)";
        write_file(script_path, pkg_script);
        run_command("chmod +x " + script_path);
        tui::print_success("Created ~/install-packages.sh - run after first boot to install selected packages");
    }

    // ========================================
    // 4. Create kime installation script for post-install (backup)
    // ========================================
    if (config_.input_method.enabled && config_.input_method.engine == "kime") {
        // Create a backup script in case AUR installation failed
        std::string script_path = user_home + "/kime-install.sh";
        std::string kime_script = R"(#!/bin/bash
# KIME Installation Script (auto-generated by Blunux installer)
# Run this if kime was not installed during system installation

set -e

echo "Installing kime-git..."

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "Installing yay first..."
    cd /tmp
    rm -rf yay-bin
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin
fi

# Install kime-git
yay -S --noconfirm --needed kime-git

echo "kime-git installed successfully!"
echo "Please log out and log back in for changes to take effect."
)";
        write_file(script_path, kime_script);
        run_command("chmod +x " + script_path);
        tui::print_info("Created ~/kime-install.sh backup script");
    }

    // ========================================
    // 4b. Create linux-bore setup script (if selected)
    // ========================================
    if (config_.kernel.type == "linux-bore") {
        tui::print_info("linux-bore kernel selected - will be installed after first boot");
        std::string bore_script_path = user_home + "/setup-linux-bore.sh";
        std::string bore_script = R"(#!/bin/bash
# Linux-BORE Kernel Setup Script (auto-generated by Blunux installer)
# Run this after first boot to complete linux-bore installation

set -e

echo "=========================================="
echo "  Linux-BORE Kernel Setup"
echo "=========================================="

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "Installing yay first..."
    cd /tmp
    rm -rf yay-bin
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin
fi

# Install linux-cachyos kernel (BORE scheduler)
echo "Installing linux-cachyos kernel with BORE scheduler (this may take a while)..."
yay -S --noconfirm --needed linux-cachyos linux-cachyos-headers

# Update boot configuration
if [ -f /usr/local/bin/nmbl-update ]; then
    echo "Updating EFISTUB boot entry (NMBL)..."
    sudo /usr/local/bin/nmbl-update
    # Update efibootmgr entry with new kernel
    ROOT_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE /))
    sudo efibootmgr --create --disk $(findmnt -n -o SOURCE /boot/efi | sed 's/[0-9]*$//') \
        --part $(findmnt -n -o SOURCE /boot/efi | grep -o '[0-9]*$') \
        --label "Blunux" \
        --loader "\\EFI\\Blunux\\vmlinuz-linux-cachyos" \
        --unicode "root=UUID=$ROOT_UUID rw quiet loglevel=3 initrd=\\EFI\\Blunux\\initramfs-linux-cachyos.img"
else
    echo "Updating GRUB configuration..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

echo ""
echo "=========================================="
echo "  Linux-CachyOS (BORE) installation complete!"
echo "=========================================="
echo ""
echo "Please reboot to use the linux-cachyos kernel."
)";
        write_file(bore_script_path, bore_script);
        run_command("chmod +x " + bore_script_path);
        tui::print_info("Created ~/setup-linux-bore.sh - run after first boot!");
    }

    // Note: Rust/Julia setup is now handled by rust.sh and julia.sh
    // via ~/install-packages.sh (see section 2 above)

    // ========================================
    // 4c. Create system check script (syschk.sh)
    // ========================================
    {
        std::string syschk_script_path = user_home + "/syschk.sh";
        std::string syschk_script = R"(#!/bin/bash
# System Check Script (auto-generated by Blunux installer)
# Downloads and runs syschk.jl with Julia

set -e

SYSCHK_URL="https://jaewoojoung.github.io/linux/syschk.jl"
SYSCHK_FILE="$(dirname "$0")/syschk.jl"

echo "Downloading syschk.jl..."
curl -fsSL "$SYSCHK_URL" -o "$SYSCHK_FILE"

echo "Running system check..."
julia "$SYSCHK_FILE"
)";
        write_file(syschk_script_path, syschk_script);
        run_command("chmod +x " + syschk_script_path);
        tui::print_info("Created ~/syschk.sh - system check script");
    }

    // ========================================
    // 5. Configure kime input method
    // ========================================
    if (config_.input_method.enabled && config_.input_method.engine == "kime") {
        tui::print_info("Configuring kime input method...");

        // Create kime config directory
        std::string kime_config_dir = user_home + "/.config/kime";
        run_command("mkdir -p " + kime_config_dir);

        // Write kime config.yaml (matching user's preferred configuration)
        std::string kime_config = R"(indicator:
  icon_color: Black

engine:
  default_category: Latin

  global_hotkeys:
    Alt_R:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    Hangul:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    Super-Space:
      behavior: !Toggle
        - Hangul
        - Latin
      result: Consume
    Esc:
      behavior: !Switch Latin
      result: Bypass

  hangul:
    layout: dubeolsik
    word_commit: false
    auto_reorder: true
)";
        write_file(kime_config_dir + "/config.yaml", kime_config);

        // Create autostart entry
        std::string autostart_dir = user_home + "/.config/autostart";
        run_command("mkdir -p " + autostart_dir);

        std::string kime_desktop = R"([Desktop Entry]
Type=Application
Name=Kime Input Method
Exec=/usr/bin/kime
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
)";
        write_file(autostart_dir + "/kime.desktop", kime_desktop);

        // Create systemd user service
        std::string systemd_dir = user_home + "/.config/systemd/user";
        run_command("mkdir -p " + systemd_dir);

        std::string kime_service = R"([Unit]
Description=Korean Input Method Editor
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/kime
Restart=on-failure
RestartSec=3
Environment="GTK_IM_MODULE=kime"
Environment="QT_IM_MODULE=kime"
Environment="XMODIFIERS=@im=kime"

[Install]
WantedBy=graphical-session.target
)";
        write_file(systemd_dir + "/kime.service", kime_service);

        // Enable kime service
        run_chroot("su - " + username + " -c 'systemctl --user enable kime.service' 2>/dev/null || true");

        // Configure KDE Plasma virtual keyboard (kwinrc)
        std::string kwinrc_path = user_home + "/.config/kwinrc";
        std::string kwinrc_content = R"([Wayland]
InputMethod[$e]=/usr/share/applications/kime.desktop
)";
        // Check if kwinrc exists and append/create accordingly
        if (std::filesystem::exists(kwinrc_path)) {
            // Append Wayland section if not already present
            append_file(kwinrc_path, "\n" + kwinrc_content);
        } else {
            write_file(kwinrc_path, kwinrc_content);
        }

        // Create environment files
        std::string bash_profile = R"(# Kime Input Method
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
export LANG=ko_KR.UTF-8
)";
        append_file(user_home + "/.bash_profile", bash_profile);

        std::string xprofile = R"(export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
)";
        write_file(user_home + "/.xprofile", xprofile);

        // System-wide environment
        std::string env_d_content = R"(GTK_IM_MODULE=kime
QT_IM_MODULE=kime
XMODIFIERS=@im=kime
)";
        run_command("mkdir -p " + mount_point_ + "/etc/environment.d");
        write_file(mount_point_ + "/etc/environment.d/kime.conf", env_d_content);

        tui::print_success("kime input method configured");
    }

    // ========================================
    // 6. Fix home directory ownership
    // ========================================
    tui::print_info("Fixing home directory ownership...");
    run_command("chown -R 1000:1000 " + user_home);
    run_command("chmod 700 " + user_home);
    run_command("chmod 700 " + user_home + "/.config");
    tui::print_success("Home directory ownership fixed");

    // ========================================
    // 7. Unmount and finish
    // ========================================
    disk::unmount_partitions(mount_point_);

    return true;
}

}  // namespace blunux
