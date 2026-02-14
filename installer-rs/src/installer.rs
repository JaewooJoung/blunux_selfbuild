use crate::config::{Config, SwapMode};
use crate::disk::{self, PartitionLayout, PartitionScheme};
use crate::tui;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::Path;
use std::process::Command;

pub struct Installer {
    config: Config,
    error_message: String,
    mount_point: String,
    partition_layout: PartitionLayout,
}

impl Installer {
    pub fn new(config: Config) -> Self {
        Self {
            config,
            error_message: String::new(),
            mount_point: "/mnt".to_string(),
            partition_layout: PartitionLayout {
                efi_partition: String::new(),
                root_partition: String::new(),
                scheme: PartitionScheme::GptUefi,
            },
        }
    }

    pub fn get_error(&self) -> &str {
        &self.error_message
    }

    fn run_command(&self, cmd: &str) -> bool {
        Command::new("sh")
            .args(["-c", cmd])
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    }

    fn run_chroot(&self, cmd: &str) -> bool {
        let full_cmd = format!("arch-chroot {} {}", self.mount_point, cmd);
        self.run_command(&full_cmd)
    }

    fn exec_output(&self, cmd: &str) -> String {
        Command::new("sh")
            .args(["-c", cmd])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_default()
    }

    fn write_file(&self, path: &str, content: &str) -> bool {
        fs::write(path, content).is_ok()
    }

    fn append_file(&self, path: &str, content: &str) -> bool {
        OpenOptions::new()
            .append(true)
            .create(true)
            .open(path)
            .and_then(|mut f| f.write_all(content.as_bytes()))
            .is_ok()
    }

    /// Run the full installation
    pub fn install(&mut self) -> bool {
        let total_steps = 10;

        // Step 1: Prepare disk
        tui::print_step(1, total_steps, "Preparing disk / 디스크 준비 중...");
        if !self.prepare_disk() {
            return false;
        }

        // Step 2: Install base system
        tui::print_step(2, total_steps, "Installing base system / 기본 시스템 설치 중...");
        if !self.install_base_system() {
            return false;
        }

        // Step 3: Generate fstab
        tui::print_step(3, total_steps, "Generating fstab / fstab 생성 중...");
        if !disk::generate_fstab(&self.mount_point) {
            self.error_message = "Failed to generate fstab".to_string();
            return false;
        }

        // Step 4: Configure system (includes swap setup from config.toml)
        tui::print_step(4, total_steps, "Configuring system / 시스템 설정 중...");
        if !self.configure_system() {
            return false;
        }

        // Step 5: Detect and install hardware drivers
        tui::print_step(5, total_steps, "Detecting hardware drivers / 하드웨어 드라이버 감지 중...");
        self.detect_and_install_drivers();

        // Step 6: Install packages
        tui::print_step(6, total_steps, "Installing packages / 패키지 설치 중...");
        if !self.install_packages() {
            return false;
        }

        // Step 7: Configure locale and input method
        tui::print_step(7, total_steps, "Configuring locale / 로케일 설정 중...");
        if !self.configure_locale() {
            return false;
        }
        if !self.configure_input_method() {
            return false;
        }

        // Step 8: Configure users
        tui::print_step(8, total_steps, "Configuring users / 사용자 설정 중...");
        if !self.configure_users() {
            return false;
        }

        // Step 9: Install bootloader
        tui::print_step(9, total_steps, "Installing bootloader / 부트로더 설치 중...");
        if !self.install_bootloader() {
            return false;
        }

        // Step 10: Finalize
        tui::print_step(10, total_steps, "Finalizing / 마무리 중...");
        if !self.finalize() {
            return false;
        }

        true
    }

    fn prepare_disk(&mut self) -> bool {
        let scheme = if disk::is_uefi() {
            PartitionScheme::GptUefi
        } else {
            PartitionScheme::MbrBios
        };

        let layout = match disk::partition_disk(&self.config.install.target_disk, scheme) {
            Some(l) => l,
            None => {
                self.error_message = "Failed to partition disk".to_string();
                return false;
            }
        };

        self.partition_layout = layout.clone();

        if !disk::format_partitions(
            &self.partition_layout,
            self.config.install.use_encryption,
            &self.config.install.encryption_password,
        ) {
            self.error_message = "Failed to format partitions".to_string();
            return false;
        }

        if !disk::mount_partitions(&self.partition_layout, &self.mount_point) {
            self.error_message = "Failed to mount partitions".to_string();
            return false;
        }

        true
    }

    fn get_base_packages(&self) -> Vec<String> {
        let mut kernel = self.config.kernel.type_.clone();
        if kernel == "linux-bore" {
            kernel = "linux".to_string();
        }

        let mut packages = vec![
            "base".to_string(),
            kernel.clone(),
            format!("{kernel}-headers"),
            "linux-firmware".to_string(),
            "base-devel".to_string(),
            "sudo".to_string(),
            "nano".to_string(),
            "vim".to_string(),
            "networkmanager".to_string(),
            "network-manager-applet".to_string(),
            // WiFi support (wpa_supplicant is required by NetworkManager for WiFi)
            "wpa_supplicant".to_string(),
            "iwd".to_string(),
            "wireless_tools".to_string(),
            "efibootmgr".to_string(),
            "dosfstools".to_string(),
            "ntfs-3g".to_string(),
            "btrfs-progs".to_string(),
            "intel-ucode".to_string(),
            "amd-ucode".to_string(),
            // GPU base drivers (always needed)
            "mesa".to_string(),
            "vulkan-icd-loader".to_string(),
            // Hardware detection
            "pciutils".to_string(),
            // Console font (required by systemd-vconsole-setup.service)
            "terminus-font".to_string(),
            "noto-fonts".to_string(),
            "noto-fonts-cjk".to_string(),
            "noto-fonts-emoji".to_string(),
            "ttf-liberation".to_string(),
            "git".to_string(),
            "wget".to_string(),
            "curl".to_string(),
            "fastfetch".to_string(),
            "htop".to_string(),
            "man-db".to_string(),
            "man-pages".to_string(),
        ];

        if self.config.install.bootloader != "nmbl" {
            packages.push("grub".to_string());
            packages.push("os-prober".to_string());
        }

        packages
    }

    fn get_desktop_packages(&self) -> Vec<String> {
        vec![
            "xorg-server".to_string(),
            "xorg-xinit".to_string(),
            "wayland".to_string(),
            "plasma-meta".to_string(),
            "sddm".to_string(),
            "konsole".to_string(),
            "dolphin".to_string(),
            "kate".to_string(),
            "ark".to_string(),
            "gwenview".to_string(),
            "okular".to_string(),
            "spectacle".to_string(),
            "kwalletmanager".to_string(),
            "kcalc".to_string(),
            "plasma-systemmonitor".to_string(),
            "kde-gtk-config".to_string(),
            "kio-extras".to_string(),
            "kdegraphics-thumbnailers".to_string(),
            "ffmpegthumbs".to_string(),
            "plasma-pa".to_string(),
            "plasma-nm".to_string(),
            "plasma-firewall".to_string(),
            "partitionmanager".to_string(),
            "filelight".to_string(),
            "ksystemlog".to_string(),
            "pipewire".to_string(),
            "pipewire-alsa".to_string(),
            "pipewire-pulse".to_string(),
            "pipewire-jack".to_string(),
            "wireplumber".to_string(),
            "cups".to_string(),
            "print-manager".to_string(),
        ]
    }

    fn get_font_packages(&self) -> Vec<String> {
        let mut fonts = vec![
            "noto-fonts".to_string(),
            "noto-fonts-emoji".to_string(),
        ];

        let has_lang = |prefix: &str| -> bool {
            self.config
                .locale
                .languages
                .iter()
                .any(|l| l.contains(prefix))
        };

        if has_lang("ko") || has_lang("ja") || has_lang("zh") {
            fonts.push("noto-fonts-cjk".to_string());
            if has_lang("ko") {
                fonts.push("ttf-baekmuk".to_string());
            }
        }

        fonts
    }

    fn get_input_method_packages(&self) -> Vec<String> {
        let mut packages = Vec::new();

        if !self.config.input_method.enabled {
            return packages;
        }

        match self.config.input_method.engine.as_str() {
            "kime" => {
                packages.extend_from_slice(&[
                    "gtk3".to_string(),
                    "gtk4".to_string(),
                    "qt5-base".to_string(),
                    "qt6-base".to_string(),
                    "qt6-tools".to_string(),
                ]);
            }
            "fcitx5" => {
                packages.extend_from_slice(&[
                    "fcitx5".to_string(),
                    "fcitx5-configtool".to_string(),
                    "fcitx5-gtk".to_string(),
                    "fcitx5-qt".to_string(),
                ]);

                let has_lang = |prefix: &str| -> bool {
                    self.config
                        .locale
                        .languages
                        .iter()
                        .any(|l| l.contains(prefix))
                };

                if has_lang("ko") {
                    packages.push("fcitx5-hangul".to_string());
                }
                if has_lang("ja") {
                    packages.push("fcitx5-mozc".to_string());
                }
                if has_lang("zh") {
                    packages.push("fcitx5-chinese-addons".to_string());
                }
            }
            "ibus" => {
                packages.push("ibus".to_string());

                let has_lang = |prefix: &str| -> bool {
                    self.config
                        .locale
                        .languages
                        .iter()
                        .any(|l| l.contains(prefix))
                };

                if has_lang("ko") {
                    packages.push("ibus-hangul".to_string());
                }
                if has_lang("ja") {
                    packages.push("ibus-mozc".to_string());
                }
            }
            _ => {}
        }

        packages
    }

    fn install_base_system(&mut self) -> bool {
        let mut all_packages = Vec::new();
        all_packages.extend(self.get_base_packages());
        all_packages.extend(self.get_desktop_packages());
        all_packages.extend(self.get_font_packages());
        all_packages.extend(self.get_input_method_packages());

        let pkg_list = all_packages.join(" ");
        let cmd = format!("pacstrap -K {} {}", self.mount_point, pkg_list);

        tui::print_info("Installing packages with pacstrap...");
        tui::print_info("This may take several minutes...");

        if !self.run_command(&cmd) {
            self.error_message = "pacstrap failed".to_string();
            return false;
        }

        true
    }

    fn configure_system(&mut self) -> bool {
        // Set timezone
        let tz_cmd = format!(
            "ln -sf /usr/share/zoneinfo/{} /etc/localtime",
            self.config.locale.timezone
        );
        self.run_chroot(&tz_cmd);
        self.run_chroot("hwclock --systohc");

        // Set hostname
        self.write_file(
            &format!("{}/etc/hostname", self.mount_point),
            &format!("{}\n", self.config.install.hostname),
        );

        // Configure hosts file
        let hosts = format!(
            "127.0.0.1    localhost\n\
             ::1          localhost\n\
             127.0.1.1    {host}.localdomain {host}\n",
            host = self.config.install.hostname
        );
        self.write_file(&format!("{}/etc/hosts", self.mount_point), &hosts);

        // Enable essential services
        self.run_chroot("systemctl enable NetworkManager");
        self.run_chroot("systemctl enable wpa_supplicant 2>/dev/null || true");
        self.run_chroot("systemctl enable bluetooth 2>/dev/null || true");
        self.run_chroot("systemctl enable sddm");
        self.run_chroot("systemctl enable cups 2>/dev/null || true");

        // Mask conflicting network services (systemd-networkd conflicts with NM)
        self.run_chroot("systemctl mask systemd-networkd.service 2>/dev/null || true");
        self.run_chroot("systemctl mask systemd-networkd.socket 2>/dev/null || true");
        self.run_chroot("systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true");
        // Disable iwd.service so it doesn't conflict with wpa_supplicant
        self.run_chroot("systemctl mask iwd.service 2>/dev/null || true");

        // =====================================================
        // COMPLETE WIFI MANAGEMENT SETUP for installed system
        // =====================================================
        self.setup_wifi_management();

        // =====================================================
        // COPY WIFI CONNECTIONS from Live session to installed system
        // So the user stays connected after reboot
        // =====================================================
        self.copy_wifi_connections();

        // =====================================================
        // SWAP CONFIGURATION - Uses [disk] swap from config.toml
        // This is the FIX for the hardcoded 8GB swap problem
        // =====================================================
        self.setup_swap();

        true
    }

    /// Copy WiFi connections from the live session to the installed system
    /// This ensures the user's WiFi connection persists after reboot
    fn copy_wifi_connections(&self) {
        let live_nm_dir = "/etc/NetworkManager/system-connections";
        let target_nm_dir = format!("{}/etc/NetworkManager/system-connections", self.mount_point);

        // Create target directory
        self.run_command(&format!("mkdir -p {target_nm_dir}"));

        // Copy all connection files from live session
        self.run_command(&format!(
            "cp -f {live_nm_dir}/*.nmconnection {target_nm_dir}/ 2>/dev/null || true"
        ));

        // Fix permissions (NM requires 600 for connection files)
        self.run_command(&format!("chmod 600 {target_nm_dir}/*.nmconnection 2>/dev/null || true"));

        tui::print_info("Copied WiFi connections from live session to installed system");
    }

    /// Complete WiFi management setup for the installed system
    /// Sets up NetworkManager config, polkit rules, DNS, and wpa_supplicant
    fn setup_wifi_management(&self) {
        // ---------------------------------------------------
        // 1. NetworkManager main configuration
        // ---------------------------------------------------
        let nm_conf_dir = format!("{}/etc/NetworkManager/conf.d", self.mount_point);
        self.run_command(&format!("mkdir -p {nm_conf_dir}"));

        // Main NM config: keyfile plugin + WiFi-friendly defaults
        // wpa_supplicant is used automatically (iwd.service is masked)
        let nm_main_conf = "\
[main]\n\
plugins=keyfile\n\
\n\
[device]\n\
wifi.scan-rand-mac-address=no\n\
\n\
[connection]\n\
wifi.cloned-mac-address=preserve\n\
wifi.powersave=2\n";

        self.write_file(&format!("{nm_conf_dir}/10-blunux-wifi.conf"), nm_main_conf);

        // ---------------------------------------------------
        // 2. Polkit rules: allow wheel group to manage NetworkManager
        //    Without this, plasma-nm WiFi button is grayed out
        // ---------------------------------------------------
        let polkit_dir = format!(
            "{}/etc/polkit-1/rules.d",
            self.mount_point
        );
        self.run_command(&format!("mkdir -p {polkit_dir}"));

        let polkit_rules = "\
/* Blunux: Allow wheel group to manage NetworkManager without password */\n\
polkit.addRule(function(action, subject) {\n\
    if (action.id.indexOf(\"org.freedesktop.NetworkManager.\") == 0 &&\n\
        subject.isInGroup(\"wheel\")) {\n\
        return polkit.Result.YES;\n\
    }\n\
});\n\
\n\
/* Allow wheel group to manage system-wide network settings */\n\
polkit.addRule(function(action, subject) {\n\
    if (action.id == \"org.freedesktop.NetworkManager.settings.modify.system\" &&\n\
        subject.isInGroup(\"wheel\")) {\n\
        return polkit.Result.YES;\n\
    }\n\
});\n";

        self.write_file(
            &format!("{polkit_dir}/49-blunux-networkmanager.rules"),
            polkit_rules,
        );

        // ---------------------------------------------------
        // 3. DNS fallback configuration
        // ---------------------------------------------------
        let resolv_conf = format!("{}/etc/resolv.conf", self.mount_point);
        // Remove any symlink (systemd-resolved creates one)
        self.run_command(&format!("rm -f {resolv_conf}"));
        let dns_conf = "\
# DNS configuration - managed by NetworkManager\n\
# Fallback DNS servers (used until NM takes over)\n\
nameserver 8.8.8.8\n\
nameserver 1.1.1.1\n";
        self.write_file(&resolv_conf, dns_conf);

        // ---------------------------------------------------
        // 4. Ensure system-connections directory exists
        // ---------------------------------------------------
        let nm_conn_dir = format!(
            "{}/etc/NetworkManager/system-connections",
            self.mount_point
        );
        self.run_command(&format!("mkdir -p {nm_conn_dir}"));
        self.run_command(&format!("chmod 755 {nm_conn_dir}"));

        tui::print_success("WiFi management configured (NetworkManager + wpa_supplicant + polkit)");
    }

    /// Configure swap based on [disk] swap setting from config.toml
    /// Previously hardcoded to 8GB - now dynamically calculated from RAM
    fn setup_swap(&self) {
        let swap_mode = &self.config.disk.swap;

        match swap_mode {
            SwapMode::None => {
                tui::print_info("Swap: none (as configured in config.toml [disk] swap = \"none\")");
                // No swap file or partition created
            }
            SwapMode::Small => {
                // RAM / 2
                let ram_mb = disk::get_ram_mb();
                let swap_mb = ram_mb / 2;
                tui::print_info(&format!(
                    "Swap: small ({swap_mb} MB = RAM/2, from config.toml [disk] swap = \"small\")"
                ));
                self.create_swap_file(swap_mb);
            }
            SwapMode::Suspend => {
                // RAM * 1 for hibernation support
                let ram_mb = disk::get_ram_mb();
                let swap_mb = ram_mb;
                tui::print_info(&format!(
                    "Swap: suspend ({swap_mb} MB = RAM size, from config.toml [disk] swap = \"suspend\")"
                ));
                self.create_swap_file(swap_mb);
            }
            SwapMode::File => {
                // Fixed reasonable default: min(RAM, 8GB)
                let ram_mb = disk::get_ram_mb();
                let swap_mb = ram_mb.min(8192);
                tui::print_info(&format!(
                    "Swap: file ({swap_mb} MB, from config.toml [disk] swap = \"file\")"
                ));
                self.create_swap_file(swap_mb);
            }
        }
    }

    /// Create a swap file of the given size in MB
    fn create_swap_file(&self, size_mb: u64) {
        if size_mb == 0 {
            return;
        }

        let swapfile = format!("{}/swapfile", self.mount_point);

        tui::print_info(&format!("Creating {size_mb} MB swap file..."));

        // Create swap file using dd
        self.run_command(&format!(
            "dd if=/dev/zero of={swapfile} bs=1M count={size_mb} status=progress"
        ));
        self.run_command(&format!("chmod 600 {swapfile}"));
        self.run_chroot("mkswap /swapfile");

        // Add swap to fstab
        let fstab_path = format!("{}/etc/fstab", self.mount_point);
        self.append_file(&fstab_path, "\n# Swap file\n/swapfile none swap defaults 0 0\n");

        let size_display = if size_mb >= 1024 {
            format!("{:.1} GB", size_mb as f64 / 1024.0)
        } else {
            format!("{size_mb} MB")
        };
        tui::print_success(&format!("{size_display} swap file created and configured"));
    }

    fn install_packages(&self) -> bool {
        // Additional packages from config (already done in base system)
        true
    }

    /// Detect hardware via lspci and install appropriate GPU/WiFi drivers
    fn detect_and_install_drivers(&self) {
        // Read lspci output from the host (hardware is the same)
        let lspci_output = self.exec_output("lspci -nn 2>/dev/null");
        let lspci_lower = lspci_output.to_lowercase();

        let mut driver_packages: Vec<String> = Vec::new();

        // ── GPU Detection ──────────────────────────────────────
        let has_nvidia = lspci_lower.contains("nvidia");
        let has_amd_gpu = lspci_lower.contains("[amd/ati]")
            || lspci_lower.contains("radeon")
            || (lspci_lower.contains("amd") && lspci_lower.contains("vga"));
        let has_intel_gpu = lspci_lower.contains("intel")
            && (lspci_lower.contains("vga") || lspci_lower.contains("display"));

        if has_nvidia {
            tui::print_info("Detected NVIDIA GPU - installing drivers...");
            driver_packages.extend_from_slice(&[
                "nvidia".to_string(),
                "nvidia-utils".to_string(),
                "nvidia-settings".to_string(),
                "lib32-nvidia-utils".to_string(),
                "libva-nvidia-driver".to_string(),
            ]);
        }

        if has_amd_gpu {
            tui::print_info("Detected AMD/ATI GPU - installing drivers...");
            driver_packages.extend_from_slice(&[
                "xf86-video-amdgpu".to_string(),
                "vulkan-radeon".to_string(),
                "lib32-vulkan-radeon".to_string(),
                "libva-mesa-driver".to_string(),
                "lib32-libva-mesa-driver".to_string(),
                "mesa-vdpau".to_string(),
            ]);
        }

        if has_intel_gpu {
            tui::print_info("Detected Intel GPU - installing drivers...");
            driver_packages.extend_from_slice(&[
                "vulkan-intel".to_string(),
                "lib32-vulkan-intel".to_string(),
                "intel-media-driver".to_string(),
            ]);
        }

        if !has_nvidia && !has_amd_gpu && !has_intel_gpu {
            tui::print_info("No dedicated GPU detected - using mesa software rendering");
        }

        // ── WiFi / Network Detection ───────────────────────────
        let has_broadcom = lspci_lower.contains("broadcom")
            && (lspci_lower.contains("wireless") || lspci_lower.contains("network")
                || lspci_lower.contains("bcm43"));

        if has_broadcom {
            tui::print_info("Detected Broadcom wireless - installing driver...");
            driver_packages.push("broadcom-wl-dkms".to_string());
        }

        let has_realtek_wifi = lspci_lower.contains("realtek")
            && (lspci_lower.contains("wireless") || lspci_lower.contains("rtl8"));

        if has_realtek_wifi {
            tui::print_info("Detected Realtek wireless - linux-firmware should cover it");
            // Most Realtek chips are covered by linux-firmware
            // rtw88/rtw89 drivers are in-kernel since linux 6.x
        }

        // ── Install detected driver packages ───────────────────
        if !driver_packages.is_empty() {
            let pkg_list = driver_packages.join(" ");
            tui::print_info(&format!("Installing hardware drivers: {}", driver_packages.len()));

            // Install via pacman in chroot
            let cmd = format!("pacman -S --noconfirm --needed {pkg_list}");
            if self.run_chroot(&cmd) {
                tui::print_success("Hardware drivers installed successfully");
            } else {
                tui::print_warning("Some driver packages may have failed - system should still work");
            }
        } else {
            tui::print_success("Base GPU drivers (mesa) already included");
        }

        // ── Enable multilib repository for 32-bit libs ─────────
        let has_32bit = driver_packages.iter().any(|p| p.starts_with("lib32-"));
        if has_32bit {
            let pacman_conf = format!("{}/etc/pacman.conf", self.mount_point);
            let conf_content = self.exec_output(&format!("cat {pacman_conf}"));
            if !conf_content.contains("[multilib]") || conf_content.contains("#[multilib]") {
                tui::print_info("Enabling multilib repository for 32-bit driver support...");
                self.run_chroot(
                    "sed -i '/^#\\[multilib\\]/,/^#Include/ s/^#//' /etc/pacman.conf",
                );
                self.run_chroot("pacman -Sy --noconfirm");
                // Retry 32-bit packages after enabling multilib
                let lib32_pkgs: Vec<&str> = driver_packages
                    .iter()
                    .filter(|p| p.starts_with("lib32-"))
                    .map(|s| s.as_str())
                    .collect();
                if !lib32_pkgs.is_empty() {
                    let cmd = format!(
                        "pacman -S --noconfirm --needed {}",
                        lib32_pkgs.join(" ")
                    );
                    self.run_chroot(&cmd);
                }
            }
        }
    }

    fn configure_locale(&self) -> bool {
        let locale_gen_path = format!("{}/etc/locale.gen", self.mount_point);
        let mut locale = String::new();
        for lang in &self.config.locale.languages {
            locale.push_str(&format!("{lang}.UTF-8 UTF-8\n"));
        }
        if !self.config.locale.languages.contains(&"en_US".to_string()) {
            locale.push_str("en_US.UTF-8 UTF-8\n");
        }
        self.append_file(&locale_gen_path, &locale);

        self.run_chroot("locale-gen");

        let default_lang = self
            .config
            .locale
            .languages
            .first()
            .cloned()
            .unwrap_or_else(|| "en_US".to_string());
        let locale_conf = format!("LANG={default_lang}.UTF-8\n");
        self.write_file(
            &format!("{}/etc/locale.conf", self.mount_point),
            &locale_conf,
        );

        // Always write vconsole.conf with KEYMAP and FONT
        // Missing FONT causes systemd-vconsole-setup.service to fail at boot
        let keymap = self
            .config
            .locale
            .keyboards
            .first()
            .cloned()
            .unwrap_or_else(|| "us".to_string());
        let vconsole = format!("KEYMAP={keymap}\nFONT=ter-v16n\n");
        self.write_file(
            &format!("{}/etc/vconsole.conf", self.mount_point),
            &vconsole,
        );

        true
    }

    fn configure_input_method(&self) -> bool {
        if !self.config.input_method.enabled {
            return true;
        }

        let env_content = match self.config.input_method.engine.as_str() {
            "kime" => "\n# Kime Korean Input Method\nGTK_IM_MODULE=kime\nQT_IM_MODULE=kime\nXMODIFIERS=@im=kime\n",
            "fcitx5" => "\n# Fcitx5 Input Method\nGTK_IM_MODULE=fcitx\nQT_IM_MODULE=fcitx\nXMODIFIERS=@im=fcitx\n",
            "ibus" => "\n# IBus Input Method\nGTK_IM_MODULE=ibus\nQT_IM_MODULE=ibus\nXMODIFIERS=@im=ibus\n",
            _ => return true,
        };

        let env_dir = format!("{}/etc/environment.d", self.mount_point);
        self.run_command(&format!("mkdir -p {env_dir}"));
        self.write_file(&format!("{env_dir}/input-method.conf"), env_content);

        true
    }

    fn configure_users(&self) -> bool {
        // Set root password
        let root_cmd = format!(
            "echo 'root:{}' | chpasswd",
            self.config.install.root_password
        );
        self.run_chroot(&format!("sh -c \"{root_cmd}\""));

        // Create user (network group for WiFi/NM management)
        self.run_chroot(&format!(
            "useradd -m -G wheel,audio,video,storage,optical,network,power,input -s /bin/bash {}",
            self.config.install.username
        ));

        // Set user password
        let user_cmd = format!(
            "echo '{}:{}' | chpasswd",
            self.config.install.username, self.config.install.user_password
        );
        self.run_chroot(&format!("sh -c \"{user_cmd}\""));

        // Configure sudo
        let sudoers = format!("{}/etc/sudoers.d/wheel", self.mount_point);
        self.write_file(&sudoers, "%wheel ALL=(ALL:ALL) ALL\n");
        self.run_command(&format!("chmod 440 {sudoers}"));

        // Configure SDDM autologin
        if self.config.install.autologin {
            let sddm_conf_dir = format!("{}/etc/sddm.conf.d", self.mount_point);
            self.run_command(&format!("mkdir -p {sddm_conf_dir}"));

            let autologin_content = format!(
                "[Autologin]\nUser={}\nSession=plasma\nRelogin=true\n",
                self.config.install.username
            );
            self.write_file(
                &format!("{sddm_conf_dir}/autologin.conf"),
                &autologin_content,
            );
            tui::print_success(&format!(
                "SDDM autologin configured for user: {}",
                self.config.install.username
            ));
        }

        true
    }

    fn install_bootloader(&self) -> bool {
        if self.config.install.bootloader == "nmbl" {
            if !disk::is_uefi() {
                tui::print_error("NMBL (EFISTUB) requires UEFI. This system uses BIOS.");
                tui::print_info("Falling back to GRUB...");
                // Fall through to GRUB below
            } else {
                tui::print_info("NMBL: Configuring EFISTUB direct boot (no bootloader)...");

                let mut kernel = self.config.kernel.type_.clone();
                if kernel == "linux-bore" {
                    kernel = "linux".to_string();
                }

                let root_uuid = self.exec_output(&format!(
                    "blkid -s UUID -o value {}",
                    self.partition_layout.root_partition
                ));

                let root_param = if self.config.install.use_encryption {
                    format!(
                        "cryptdevice=UUID={root_uuid}:cryptroot root=/dev/mapper/cryptroot"
                    )
                } else {
                    format!("root=UUID={root_uuid}")
                };
                let kernel_params = format!("{root_param} rw quiet loglevel=3");

                // Copy kernel and initramfs to ESP
                self.run_chroot("mkdir -p /boot/efi/EFI/Blunux");
                self.run_chroot(&format!(
                    "cp /boot/vmlinuz-{kernel} /boot/efi/EFI/Blunux/vmlinuz-{kernel}"
                ));
                self.run_chroot(&format!(
                    "cp /boot/initramfs-{kernel}.img /boot/efi/EFI/Blunux/initramfs-{kernel}.img"
                ));

                // Parse EFI partition for efibootmgr
                let efi_part = &self.partition_layout.efi_partition;
                let (efi_disk, efi_part_num) =
                    if efi_part.contains("nvme") || efi_part.contains("mmcblk") {
                        let p_pos = efi_part.rfind('p').unwrap_or(efi_part.len());
                        (
                            efi_part[..p_pos].to_string(),
                            efi_part[p_pos + 1..].to_string(),
                        )
                    } else {
                        // Find where trailing digits start: /dev/sda1 -> split at 'a'/'1' boundary
                        let bytes = efi_part.as_bytes();
                        let mut num_start = bytes.len();
                        for i in (0..bytes.len()).rev() {
                            if bytes[i].is_ascii_digit() {
                                num_start = i;
                            } else {
                                break;
                            }
                        }
                        (
                            efi_part[..num_start].to_string(),
                            efi_part[num_start..].to_string(),
                        )
                    };

                let efi_cmd = format!(
                    "efibootmgr --create \
                     --disk {efi_disk} \
                     --part {efi_part_num} \
                     --label \"Blunux\" \
                     --loader \"\\EFI\\Blunux\\vmlinuz-{kernel}\" \
                     --unicode \"{kernel_params} initrd=\\EFI\\Blunux\\initramfs-{kernel}.img\""
                );

                if !self.run_chroot(&efi_cmd) {
                    tui::print_error("Failed to create UEFI boot entry");
                    return false;
                }

                // Create pacman hook for kernel updates
                let hooks_dir = format!("{}/etc/pacman.d/hooks", self.mount_point);
                self.run_command(&format!("mkdir -p {hooks_dir}"));

                let hook_content = format!(
                    "[Trigger]\n\
                     Type = Package\n\
                     Operation = Upgrade\n\
                     Target = {kernel}\n\
                     \n\
                     [Action]\n\
                     Description = Updating kernel in ESP for EFISTUB boot...\n\
                     When = PostTransaction\n\
                     Exec = /usr/local/bin/nmbl-update\n\
                     Depends = coreutils\n"
                );
                self.write_file(
                    &format!("{hooks_dir}/99-nmbl-kernel-update.hook"),
                    &hook_content,
                );

                let update_script = format!(
                    "#!/bin/bash\n\
                     # NMBL: Copy updated kernel/initramfs to ESP\n\
                     cp /boot/vmlinuz-{kernel} /boot/efi/EFI/Blunux/vmlinuz-{kernel}\n\
                     cp /boot/initramfs-{kernel}.img /boot/efi/EFI/Blunux/initramfs-{kernel}.img\n"
                );
                self.write_file(
                    &format!("{}/usr/local/bin/nmbl-update", self.mount_point),
                    &update_script,
                );
                self.run_command(&format!(
                    "chmod +x {}/usr/local/bin/nmbl-update",
                    self.mount_point
                ));

                tui::print_success(
                    "NMBL: EFISTUB direct boot configured - no bootloader installed!",
                );
                return true;
            }
        }

        // GRUB (default)
        if disk::is_uefi() {
            self.run_chroot(
                "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Blunux",
            );
        } else {
            self.run_chroot(&format!(
                "grub-install --target=i386-pc {}",
                self.config.install.target_disk
            ));
        }

        tui::print_info("Configuring GRUB for direct boot...");
        self.run_chroot("sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub");
        self.run_chroot(
            "sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub",
        );
        self.run_chroot("grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub || echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub");
        self.run_chroot("grub-mkconfig -o /boot/grub/grub.cfg");

        true
    }

    fn finalize(&self) -> bool {
        let user_home = format!(
            "{}/home/{}",
            self.mount_point, self.config.install.username
        );
        let username = &self.config.install.username;

        // 1. Copy Blunux branding
        tui::print_info("Copying Blunux configuration...");

        let ff_config_dir = format!("{user_home}/.config/fastfetch");
        self.run_command(&format!("mkdir -p {ff_config_dir}"));
        if self.run_command("test -f /etc/fastfetch/config.jsonc") {
            self.run_command(&format!(
                "cp /etc/fastfetch/config.jsonc {ff_config_dir}/"
            ));
            self.run_command(&format!(
                "cp /etc/fastfetch/blunux-logo.txt {ff_config_dir}/ 2>/dev/null || true"
            ));
        }
        self.run_command(&format!(
            "mkdir -p {}/etc/fastfetch",
            self.mount_point
        ));
        self.run_command(&format!(
            "cp -r /etc/fastfetch/* {}/etc/fastfetch/ 2>/dev/null || true",
            self.mount_point
        ));

        if self.run_command("test -f /etc/os-release") {
            self.run_command(&format!(
                "cp /etc/os-release {}/etc/os-release",
                self.mount_point
            ));
            self.run_command(&format!(
                "mkdir -p {}/usr/lib",
                self.mount_point
            ));
            self.run_command(&format!(
                "cp /etc/os-release {}/usr/lib/os-release",
                self.mount_point
            ));
        }
        // Copy Blunux logo icon (used by KDE "About This System" via LOGO= in os-release)
        if self.run_command("test -f /usr/share/pixmaps/blunux.png") {
            self.run_command(&format!(
                "mkdir -p {}/usr/share/pixmaps",
                self.mount_point
            ));
            self.run_command(&format!(
                "cp /usr/share/pixmaps/blunux.png {}/usr/share/pixmaps/blunux.png",
                self.mount_point
            ));
        }
        tui::print_success("Blunux branding configured");

        // 2. Create package installation script
        let script_packages = self.config.get_script_package_list();
        if !script_packages.is_empty() {
            tui::print_info("Creating package installation script...");
            let script_path = format!("{user_home}/install-packages.sh");

            let mut pkg_script = r#"#!/bin/bash
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
    BUILDDIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$BUILDDIR/yay-bin"
    cd "$BUILDDIR/yay-bin"
    makepkg -si --noconfirm
    cd /
    rm -rf "$BUILDDIR"
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
"#
            .to_string();

            for pkg in &script_packages {
                pkg_script.push_str(&format!("install_package \"{pkg}\"\n"));
            }

            pkg_script.push_str(
                r#"
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
"#,
            );

            self.write_file(&script_path, &pkg_script);
            self.run_command(&format!("chmod +x {script_path}"));
            tui::print_success(
                "Created ~/install-packages.sh - run after first boot to install selected packages",
            );
        }

        // 3. Create kime installation script (backup)
        if self.config.input_method.enabled && self.config.input_method.engine == "kime" {
            let script_path = format!("{user_home}/kime-install.sh");
            let kime_script = r#"#!/bin/bash
# KIME Installation Script (auto-generated by Blunux installer)
# Run this if kime was not installed during system installation

set -e

echo "Installing kime-git..."

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "Installing yay first..."
    BUILDDIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$BUILDDIR/yay-bin"
    cd "$BUILDDIR/yay-bin"
    makepkg -si --noconfirm
    cd /
    rm -rf "$BUILDDIR"
fi

# Install kime-git
yay -S --noconfirm --needed kime-git

echo "kime-git installed successfully!"
echo "Please log out and log back in for changes to take effect."
"#;
            self.write_file(&script_path, kime_script);
            self.run_command(&format!("chmod +x {script_path}"));
            tui::print_info("Created ~/kime-install.sh backup script");
        }

        // 4. Create linux-bore setup script (if selected)
        if self.config.kernel.type_ == "linux-bore" {
            tui::print_info("linux-bore kernel selected - will be installed after first boot");
            let bore_script_path = format!("{user_home}/setup-linux-bore.sh");
            let bore_script = r#"#!/bin/bash
# Linux-BORE Kernel Setup Script (auto-generated by Blunux installer)
# Run this after first boot to complete linux-bore installation

set -e

echo "=========================================="
echo "  Linux-BORE Kernel Setup"
echo "=========================================="

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "Installing yay first..."
    BUILDDIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$BUILDDIR/yay-bin"
    cd "$BUILDDIR/yay-bin"
    makepkg -si --noconfirm
    cd /
    rm -rf "$BUILDDIR"
fi

# Install linux-cachyos kernel (BORE scheduler)
echo "Installing linux-cachyos kernel with BORE scheduler (this may take a while)..."
yay -S --noconfirm --needed linux-cachyos linux-cachyos-headers

# Update boot configuration
if [ -f /usr/local/bin/nmbl-update ]; then
    echo "Updating EFISTUB boot entry (NMBL)..."
    sudo /usr/local/bin/nmbl-update
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
"#;
            self.write_file(&bore_script_path, bore_script);
            self.run_command(&format!("chmod +x {bore_script_path}"));
            tui::print_info("Created ~/setup-linux-bore.sh - run after first boot!");
        }

        // 5. Create system check script
        {
            let syschk_script_path = format!("{user_home}/syschk.sh");
            let syschk_script = r#"#!/bin/bash
# System Check Script (auto-generated by Blunux installer)
# Downloads and runs syschk.jl with Julia

set -e

SYSCHK_URL="https://jaewoojoung.github.io/linux/syschk.jl"
SYSCHK_FILE="$(dirname "$0")/syschk.jl"

echo "Downloading syschk.jl..."
curl -fsSL "$SYSCHK_URL" -o "$SYSCHK_FILE"

echo "Running system check..."
julia "$SYSCHK_FILE"
"#;
            self.write_file(&syschk_script_path, syschk_script);
            self.run_command(&format!("chmod +x {syschk_script_path}"));
            tui::print_info("Created ~/syschk.sh - system check script");
        }

        // 6. Configure kime input method
        if self.config.input_method.enabled && self.config.input_method.engine == "kime" {
            tui::print_info("Configuring kime input method...");

            let kime_config_dir = format!("{user_home}/.config/kime");
            self.run_command(&format!("mkdir -p {kime_config_dir}"));

            let kime_config = r#"indicator:
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
"#;
            self.write_file(&format!("{kime_config_dir}/config.yaml"), kime_config);

            // Create autostart entry
            let autostart_dir = format!("{user_home}/.config/autostart");
            self.run_command(&format!("mkdir -p {autostart_dir}"));

            let kime_desktop = "[Desktop Entry]\n\
                                Type=Application\n\
                                Name=Kime Input Method\n\
                                Exec=/usr/bin/kime\n\
                                Terminal=false\n\
                                Categories=Utility;\n\
                                X-GNOME-Autostart-enabled=true\n";
            self.write_file(&format!("{autostart_dir}/kime.desktop"), kime_desktop);

            // Create systemd user service
            let systemd_dir = format!("{user_home}/.config/systemd/user");
            self.run_command(&format!("mkdir -p {systemd_dir}"));

            let kime_service = "[Unit]\n\
                                Description=Korean Input Method Editor\n\
                                After=graphical-session.target\n\
                                PartOf=graphical-session.target\n\
                                \n\
                                [Service]\n\
                                Type=simple\n\
                                ExecStart=/usr/bin/kime\n\
                                Restart=on-failure\n\
                                RestartSec=3\n\
                                Environment=\"GTK_IM_MODULE=kime\"\n\
                                Environment=\"QT_IM_MODULE=kime\"\n\
                                Environment=\"XMODIFIERS=@im=kime\"\n\
                                \n\
                                [Install]\n\
                                WantedBy=graphical-session.target\n";
            self.write_file(&format!("{systemd_dir}/kime.service"), kime_service);

            self.run_chroot(&format!(
                "su - {username} -c 'systemctl --user enable kime.service' 2>/dev/null || true"
            ));

            // Configure KDE Plasma virtual keyboard
            let kwinrc_path = format!("{user_home}/.config/kwinrc");
            let kwinrc_content = "[Wayland]\nInputMethod[$e]=/usr/share/applications/kime.desktop\n";
            if Path::new(&kwinrc_path).exists() {
                self.append_file(&kwinrc_path, &format!("\n{kwinrc_content}"));
            } else {
                self.write_file(&kwinrc_path, kwinrc_content);
            }

            // Create environment files
            let bash_profile = "# Kime Input Method\n\
                                export GTK_IM_MODULE=kime\n\
                                export QT_IM_MODULE=kime\n\
                                export XMODIFIERS=@im=kime\n\
                                export LANG=ko_KR.UTF-8\n";
            self.append_file(&format!("{user_home}/.bash_profile"), bash_profile);

            let xprofile = "export GTK_IM_MODULE=kime\n\
                            export QT_IM_MODULE=kime\n\
                            export XMODIFIERS=@im=kime\n";
            self.write_file(&format!("{user_home}/.xprofile"), xprofile);

            // System-wide environment
            let env_d_content = "GTK_IM_MODULE=kime\n\
                                 QT_IM_MODULE=kime\n\
                                 XMODIFIERS=@im=kime\n";
            self.run_command(&format!(
                "mkdir -p {}/etc/environment.d",
                self.mount_point
            ));
            self.write_file(
                &format!("{}/etc/environment.d/kime.conf", self.mount_point),
                env_d_content,
            );

            tui::print_success("kime input method configured");
        }

        // 7. Fix home directory ownership
        tui::print_info("Fixing home directory ownership...");
        self.run_command(&format!("chown -R 1000:1000 {user_home}"));
        self.run_command(&format!("chmod 700 {user_home}"));
        self.run_command(&format!("chmod 700 {user_home}/.config"));
        tui::print_success("Home directory ownership fixed");

        // 8. Unmount and finish
        disk::unmount_partitions(&self.mount_point);

        true
    }
}
