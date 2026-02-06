#include <iostream>
#include <string>
#include <vector>
#include <cstdlib>
#include <filesystem>
#include <unistd.h>

#include "config.hpp"
#include "tui.hpp"
#include "disk.hpp"
#include "installer.hpp"

using namespace blunux;

void print_usage(const char* program) {
    std::cout << "\n";
    std::cout << tui::colors::BOLD << "Usage:" << tui::colors::RESET << "\n";
    std::cout << "  " << program << " [config.toml]\n\n";
    std::cout << tui::colors::BOLD << "Options:" << tui::colors::RESET << "\n";
    std::cout << "  --help, -h     Show this help message\n";
    std::cout << "  --version, -v  Show version information\n\n";
    std::cout << tui::colors::BOLD << "Examples:" << tui::colors::RESET << "\n";
    std::cout << "  " << program << "                    # Interactive mode\n";
    std::cout << "  " << program << " config.toml        # Use config file\n";
    std::cout << "\n";
}

bool check_root() {
    if (getuid() != 0) {
        tui::print_error("This installer must be run as root!");
        std::cout << "Please run: sudo " << tui::colors::BOLD << "blunux-installer"
                  << tui::colors::RESET << "\n";
        return false;
    }
    return true;
}

bool check_network() {
    // Try multiple hosts for network check (some might be blocked)
    std::vector<std::string> hosts = {"archlinux.org", "google.com", "1.1.1.1"};
    for (const auto& host : hosts) {
        int result = system(("ping -c 1 -W 2 " + host + " > /dev/null 2>&1").c_str());
        if (result == 0) return true;
    }
    return false;
}

std::string select_config_file() {
    // Check for config files in current directory and /etc/blunux
    std::vector<std::string> config_paths = {
        "/etc/blunux/config.toml",
        "/root/config.toml",
        "./config.toml"
    };

    for (const auto& path : config_paths) {
        if (std::filesystem::exists(path)) {
            return path;
        }
    }

    return "";
}

Config interactive_setup(Config& cfg) {
    tui::clear_screen();
    tui::print_banner();

    std::cout << "\n";
    tui::print_info("Starting interactive setup / 대화형 설정 시작\n");

    // Step 1: Select disk
    auto disks = disk::get_disks();
    auto selected_disk = tui::select_disk(disks);
    if (!selected_disk) {
        tui::print_error("No disk selected. Exiting.");
        exit(1);
    }
    cfg.install.target_disk = selected_disk->device;

    // Warn about data loss
    std::cout << "\n";
    tui::print_warning("All data on " + cfg.install.target_disk + " will be DESTROYED!");
    if (!tui::confirm("Are you sure you want to continue?", false)) {
        tui::print_info("Installation cancelled.");
        exit(0);
    }

    // Step 2: Set hostname (skip if already configured)
    if (cfg.install.hostname.empty() || cfg.install.hostname == "blunux") {
        std::cout << "\n";
        cfg.install.hostname = tui::input("Hostname / 호스트명", cfg.install.hostname.empty() ? "blunux" : cfg.install.hostname);
    } else {
        tui::print_info("Hostname: " + cfg.install.hostname + " (from config.toml)");
    }

    // Step 3: Set username (skip if already configured)
    if (cfg.install.username.empty() || cfg.install.username == "user") {
        cfg.install.username = tui::input("Username / 사용자명", cfg.install.username.empty() ? "user" : cfg.install.username);
    } else {
        tui::print_info("Username: " + cfg.install.username + " (from config.toml)");
    }

    // Step 4: Set passwords (skip if already configured in config.toml)
    bool passwords_configured = !cfg.install.root_password.empty() && !cfg.install.user_password.empty();
    if (!passwords_configured) {
        std::cout << "\n";
        tui::print_info("Setting passwords / 비밀번호 설정");

        while (true) {
            cfg.install.root_password = tui::password_input("Root password / 루트 비밀번호");
            std::string confirm_pass = tui::password_input("Confirm root password / 확인");
            if (cfg.install.root_password == confirm_pass) {
                break;
            }
            tui::print_error("Passwords do not match. Try again.");
        }

        while (true) {
            cfg.install.user_password = tui::password_input("User password / 사용자 비밀번호");
            std::string confirm_pass = tui::password_input("Confirm user password / 확인");
            if (cfg.install.user_password == confirm_pass) {
                break;
            }
            tui::print_error("Passwords do not match. Try again.");
        }
    } else {
        tui::print_info("Passwords: configured (from config.toml)");
    }

    // Step 5: Timezone selection (skip if already configured)
    if (cfg.locale.timezone.empty() || cfg.locale.timezone == "UTC") {
        std::cout << "\n";
        std::vector<std::string> tz_options = {
            "Asia/Seoul",
            "Asia/Tokyo",
            "Asia/Shanghai",
            "Europe/Stockholm",
            "Europe/London",
            "America/New_York",
            "America/Los_Angeles",
            "UTC"
        };
        int tz_idx = tui::menu_select("Select timezone / 시간대 선택", tz_options, 0);
        cfg.locale.timezone = tz_options[tz_idx];
    } else {
        tui::print_info("Timezone: " + cfg.locale.timezone + " (from config.toml)");
    }

    // Step 6: Keyboard layout (skip if already configured)
    if (cfg.locale.keyboards.empty()) {
        std::cout << "\n";
        std::vector<std::string> kb_options = {
            "us - US English",
            "kr - Korean",
            "jp - Japanese",
            "gb - UK English",
            "de - German",
            "fr - French",
            "se - Swedish"
        };
        int kb_idx = tui::menu_select("Select keyboard layout / 키보드 레이아웃", kb_options, 0);
        std::string kb_code = kb_options[kb_idx].substr(0, 2);
        cfg.locale.keyboards = {kb_code};
    } else {
        tui::print_info("Keyboard: " + cfg.locale.keyboards[0] + " (from config.toml)");
    }

    // Step 7: Kernel selection (skip if already configured to non-default)
    // If kernel is set to anything other than empty or default "linux", use config.toml value
    bool kernel_is_configured = !cfg.kernel.type.empty() && cfg.kernel.type != "linux";
    if (!kernel_is_configured) {
        std::cout << "\n";
        std::vector<std::string> kernel_options = {
            "linux - Standard kernel",
            "linux-lts - Long-term support kernel",
            "linux-zen - Performance-optimized kernel"
        };
        int kernel_idx = tui::menu_select("Select kernel / 커널 선택", kernel_options, 0);
        if (kernel_idx == 0) cfg.kernel.type = "linux";
        else if (kernel_idx == 1) cfg.kernel.type = "linux-lts";
        else cfg.kernel.type = "linux-zen";
    } else {
        tui::print_info("Kernel: " + cfg.kernel.type + " (from config.toml)");
    }

    // Step 8: Encryption option (skip if configured in config.toml)
    // Note: use_encryption defaults to false, so we use a marker to detect if it was explicitly set
    // If encryption is true in config.toml, skip asking
    tui::print_info("Encryption: " + std::string(cfg.install.use_encryption ? "enabled" : "disabled") + " (from config.toml)");
    if (cfg.install.use_encryption && cfg.install.encryption_password.empty()) {
        // Encryption is enabled but no password - ask for it
        while (true) {
            cfg.install.encryption_password = tui::password_input("Encryption password / 암호화 비밀번호");
            std::string confirm_pass = tui::password_input("Confirm encryption password / 확인");
            if (cfg.install.encryption_password == confirm_pass) {
                break;
            }
            tui::print_error("Passwords do not match. Try again.");
        }
    }

    // Step 9: Input method (for CJK locales)
    // Skip if already configured in config.toml
    auto has_lang = [&](const std::string& prefix) {
        for (const auto& lang : cfg.locale.languages) {
            if (lang.find(prefix) != std::string::npos) return true;
        }
        return false;
    };
    bool is_cjk_locale = has_lang("ko") || has_lang("ja") || has_lang("zh");
    bool im_already_configured = !cfg.input_method.engine.empty();

    if (is_cjk_locale && !im_already_configured) {
        std::cout << "\n";
        std::vector<std::string> im_options = {
            "kime - Korean Input Method (Recommended for Korean)",
            "fcitx5 - Flexible Input Method (CJK)",
            "ibus - Intelligent Input Bus",
            "none - No input method"
        };
        int im_idx = tui::menu_select("Select input method / 입력기 선택", im_options, 0);
        if (im_idx == 3) {
            cfg.input_method.enabled = false;
        } else {
            cfg.input_method.enabled = true;
            if (im_idx == 0) cfg.input_method.engine = "kime";
            else if (im_idx == 1) cfg.input_method.engine = "fcitx5";
            else cfg.input_method.engine = "ibus";
        }
    } else if (im_already_configured) {
        tui::print_info("Input method: " + cfg.input_method.engine + " (from config.toml)");
    }

    return cfg;
}

int main(int argc, char* argv[]) {
    // Parse command line arguments
    std::string config_path;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--help" || arg == "-h") {
            print_usage(argv[0]);
            return 0;
        }
        if (arg == "--version" || arg == "-v") {
            std::cout << "Blunux Installer v1.0.0\n";
            return 0;
        }
        if (!arg.empty() && arg[0] != '-') {
            config_path = arg;
        }
    }

    // Check root privileges
    if (!check_root()) {
        return 1;
    }

    tui::clear_screen();
    tui::print_banner();

    // Check network connectivity (don't block - just warn)
    tui::print_info("Checking network connectivity...");
    if (!check_network()) {
        tui::print_warning("Network check failed - continuing anyway");
        tui::print_info("(If installation fails, use 'nmtui' to connect to WiFi)");
    } else {
        tui::print_success("Network connected");
    }

    // Load or create configuration
    Config config;

    if (config_path.empty()) {
        config_path = select_config_file();
    }

    if (!config_path.empty() && std::filesystem::exists(config_path)) {
        tui::print_info("Loading configuration from: " + config_path);
        try {
            config = Config::load(config_path);
            tui::print_success("Configuration loaded successfully");
        } catch (const std::exception& e) {
            tui::print_error("Failed to load config: " + std::string(e.what()));
            tui::print_info("Falling back to interactive mode...");
            config = Config();
        }
    } else {
        tui::print_info("No configuration file found. Using interactive mode.");
    }

    // Interactive setup for missing settings
    config = interactive_setup(config);

    // Show installation summary
    std::cout << "\n";
    tui::show_summary(
        config.install.target_disk,
        config.install.hostname,
        config.install.username,
        config.locale.timezone,
        config.locale.keyboards.empty() ? "us" : config.locale.keyboards[0],
        config.kernel.type,
        config.install.use_encryption
    );

    // Final confirmation
    std::cout << "\n";
    tui::print_warning("This will ERASE ALL DATA on " + config.install.target_disk);
    if (!tui::confirm("Start installation? / 설치를 시작하시겠습니까?", false)) {
        tui::print_info("Installation cancelled.");
        return 0;
    }

    // Start installation
    std::cout << "\n";
    tui::print_info("Starting installation... / 설치 시작...\n");

    Installer installer(config);
    installer.set_progress_callback([](int step, int total, const std::string& msg) {
        tui::print_step(step, total, msg);
    });

    bool success = installer.install();

    std::cout << "\n";
    if (success) {
        tui::draw_box("Installation Complete! / 설치 완료!", {
            "",
            "  Blunux has been installed successfully!",
            "  Blunux가 성공적으로 설치되었습니다!",
            "",
            "  Please remove the installation media and reboot.",
            "  설치 미디어를 제거하고 재부팅하세요.",
            "",
            "  Command: reboot",
            ""
        });
    } else {
        tui::print_error("Installation failed: " + installer.get_error());
        tui::print_info("Please check the error message and try again.");
        return 1;
    }

    // Ask to reboot
    if (tui::confirm("Reboot now? / 지금 재부팅하시겠습니까?", true)) {
        system("reboot");
    }

    return 0;
}
