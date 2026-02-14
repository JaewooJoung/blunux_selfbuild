mod config;
mod disk;
mod installer;
mod tui;

use config::Config;
use std::env;
use std::path::Path;
use std::process;

fn print_usage(program: &str) {
    println!();
    println!("{}Usage:{}", tui::BOLD, tui::RESET);
    println!("  {program} [config.toml]");
    println!();
    println!("{}Options:{}", tui::BOLD, tui::RESET);
    println!("  --help, -h     Show this help message");
    println!("  --version, -v  Show version information");
    println!();
    println!("{}Examples:{}", tui::BOLD, tui::RESET);
    println!("  {program}                    # Interactive mode");
    println!("  {program} config.toml        # Use config file");
    println!();
}

fn check_root() -> bool {
    unsafe {
        if libc::getuid() != 0 {
            tui::print_error("This installer must be run as root!");
            println!(
                "Please run: sudo {}blunux-installer{}",
                tui::BOLD,
                tui::RESET
            );
            return false;
        }
    }
    true
}

fn check_network() -> bool {
    let hosts = ["archlinux.org", "google.com", "1.1.1.1"];
    for host in &hosts {
        let result = process::Command::new("ping")
            .args(["-c", "1", "-W", "2", host])
            .stdout(process::Stdio::null())
            .stderr(process::Stdio::null())
            .status();
        if let Ok(status) = result {
            if status.success() {
                return true;
            }
        }
    }
    false
}

fn select_config_file() -> Option<String> {
    let config_paths = [
        "/etc/blunux/config.toml",
        "/root/config.toml",
        "./config.toml",
    ];

    for path in &config_paths {
        if Path::new(path).exists() {
            return Some(path.to_string());
        }
    }

    None
}

fn interactive_setup(cfg: &mut Config) {
    tui::clear_screen();
    tui::print_banner();

    println!();
    tui::print_info("Starting interactive setup / 대화형 설정 시작\n");

    // Step 1: Select disk
    let disks = disk::get_disks();
    let selected_disk = tui::select_disk(&disks);
    match selected_disk {
        Some(d) => cfg.install.target_disk = d.device,
        None => {
            tui::print_error("No disk selected. Exiting.");
            process::exit(1);
        }
    }

    // Warn about data loss
    println!();
    tui::print_warning(&format!(
        "All data on {} will be DESTROYED!",
        cfg.install.target_disk
    ));
    if !tui::confirm("Are you sure you want to continue?", false) {
        tui::print_info("Installation cancelled.");
        process::exit(0);
    }

    // Step 2: Set hostname (skip if loaded from config.toml)
    if cfg.loaded_from_file && !cfg.install.hostname.is_empty() {
        tui::print_info(&format!(
            "Hostname: {} (from config.toml)",
            cfg.install.hostname
        ));
    } else {
        println!();
        let default = if cfg.install.hostname.is_empty() {
            "blunux"
        } else {
            &cfg.install.hostname
        };
        cfg.install.hostname = tui::input_prompt("Hostname / 호스트명", default);
    }

    // Step 3: Set username (skip if loaded from config.toml)
    if cfg.loaded_from_file && !cfg.install.username.is_empty() {
        tui::print_info(&format!(
            "Username: {} (from config.toml)",
            cfg.install.username
        ));
    } else {
        let default = if cfg.install.username.is_empty() {
            "user"
        } else {
            &cfg.install.username
        };
        cfg.install.username = tui::input_prompt("Username / 사용자명", default);
    }

    // Step 4: Set passwords
    let passwords_configured =
        !cfg.install.root_password.is_empty() && !cfg.install.user_password.is_empty();
    if !passwords_configured {
        println!();
        tui::print_info("Setting passwords / 비밀번호 설정");

        loop {
            cfg.install.root_password = tui::password_input("Root password / 루트 비밀번호");
            let confirm = tui::password_input("Confirm root password / 확인");
            if cfg.install.root_password == confirm {
                break;
            }
            tui::print_error("Passwords do not match. Try again.");
        }

        loop {
            cfg.install.user_password = tui::password_input("User password / 사용자 비밀번호");
            let confirm = tui::password_input("Confirm user password / 확인");
            if cfg.install.user_password == confirm {
                break;
            }
            tui::print_error("Passwords do not match. Try again.");
        }
    } else {
        tui::print_info("Passwords: configured (from config.toml)");
    }

    // Step 5: Timezone selection (skip if loaded from config.toml)
    if !cfg.loaded_from_file && (cfg.locale.timezone.is_empty() || cfg.locale.timezone == "UTC") {
        println!();
        let tz_options = [
            "Asia/Seoul",
            "Asia/Tokyo",
            "Asia/Shanghai",
            "Europe/Stockholm",
            "Europe/London",
            "America/New_York",
            "America/Los_Angeles",
            "UTC",
        ];
        let tz_idx = tui::menu_select("Select timezone / 시간대 선택", &tz_options, 0);
        cfg.locale.timezone = tz_options[tz_idx].to_string();
    } else {
        tui::print_info(&format!(
            "Timezone: {} (from config.toml)",
            cfg.locale.timezone
        ));
    }

    // Step 6: Keyboard layout (skip if loaded from config.toml)
    if !cfg.loaded_from_file && cfg.locale.keyboards.is_empty() {
        println!();
        let kb_options = [
            "us - US English",
            "kr - Korean",
            "jp - Japanese",
            "gb - UK English",
            "de - German",
            "fr - French",
            "se - Swedish",
        ];
        let kb_idx = tui::menu_select("Select keyboard layout / 키보드 레이아웃", &kb_options, 0);
        let kb_code = &kb_options[kb_idx][..2];
        cfg.locale.keyboards = vec![kb_code.to_string()];
    } else {
        tui::print_info(&format!(
            "Keyboard: {} (from config.toml)",
            cfg.locale.keyboards[0]
        ));
    }

    // Step 7: Kernel selection (skip if loaded from config.toml)
    let kernel_is_configured = cfg.loaded_from_file && !cfg.kernel.type_.is_empty();
    if !kernel_is_configured {
        println!();
        let kernel_options = [
            "linux - Standard kernel",
            "linux-lts - Long-term support kernel",
            "linux-zen - Performance-optimized kernel",
        ];
        let kernel_idx = tui::menu_select("Select kernel / 커널 선택", &kernel_options, 0);
        cfg.kernel.type_ = match kernel_idx {
            0 => "linux".to_string(),
            1 => "linux-lts".to_string(),
            _ => "linux-zen".to_string(),
        };
    } else {
        tui::print_info(&format!(
            "Kernel: {} (from config.toml)",
            cfg.kernel.type_
        ));
    }

    // Step 8: Encryption option
    tui::print_info(&format!(
        "Encryption: {} (from config.toml)",
        if cfg.install.use_encryption {
            "enabled"
        } else {
            "disabled"
        }
    ));
    if cfg.install.use_encryption && cfg.install.encryption_password.is_empty() {
        loop {
            cfg.install.encryption_password =
                tui::password_input("Encryption password / 암호화 비밀번호");
            let confirm = tui::password_input("Confirm encryption password / 확인");
            if cfg.install.encryption_password == confirm {
                break;
            }
            tui::print_error("Passwords do not match. Try again.");
        }
    }

    // Step 9: Swap configuration display
    tui::print_info(&format!(
        "Swap: {} (from config.toml [disk] section)",
        cfg.disk.swap.label()
    ));

    // Step 10: Input method (skip if loaded from config.toml)
    let has_lang = |prefix: &str| -> bool {
        cfg.locale.languages.iter().any(|l| l.contains(prefix))
    };
    let is_cjk_locale = has_lang("ko") || has_lang("ja") || has_lang("zh");
    let im_already_configured = cfg.loaded_from_file && !cfg.input_method.engine.is_empty();

    if is_cjk_locale && !im_already_configured {
        println!();
        let im_options = [
            "kime - Korean Input Method (Recommended for Korean)",
            "fcitx5 - Flexible Input Method (CJK)",
            "ibus - Intelligent Input Bus",
            "none - No input method",
        ];
        let im_idx = tui::menu_select("Select input method / 입력기 선택", &im_options, 0);
        if im_idx == 3 {
            cfg.input_method.enabled = false;
        } else {
            cfg.input_method.enabled = true;
            cfg.input_method.engine = match im_idx {
                0 => "kime".to_string(),
                1 => "fcitx5".to_string(),
                _ => "ibus".to_string(),
            };
        }
    } else if im_already_configured {
        tui::print_info(&format!(
            "Input method: {} (from config.toml)",
            cfg.input_method.engine
        ));
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut config_path = String::new();

    for arg in args.iter().skip(1) {
        match arg.as_str() {
            "--help" | "-h" => {
                print_usage(&args[0]);
                return;
            }
            "--version" | "-v" => {
                println!("Blunux Installer v1.0.0 (Rust)");
                return;
            }
            _ => {
                if !arg.starts_with('-') {
                    config_path = arg.clone();
                }
            }
        }
    }

    // Check root privileges
    if !check_root() {
        process::exit(1);
    }

    tui::clear_screen();
    tui::print_banner();

    // Check network
    tui::print_info("Checking network connectivity...");
    if !check_network() {
        tui::print_warning("Network check failed - continuing anyway");
        tui::print_info("(If installation fails, use 'nmtui' to connect to WiFi)");
    } else {
        tui::print_success("Network connected");
    }

    // Load or create configuration
    let mut config = Config::default();

    if config_path.is_empty() {
        if let Some(path) = select_config_file() {
            config_path = path;
        }
    }

    if !config_path.is_empty() && Path::new(&config_path).exists() {
        tui::print_info(&format!("Loading configuration from: {config_path}"));
        match Config::load(&config_path) {
            Ok(cfg) => {
                config = cfg;
                tui::print_success("Configuration loaded successfully");
            }
            Err(e) => {
                tui::print_error(&format!("Failed to load config: {e}"));
                tui::print_info("Falling back to interactive mode...");
                config = Config::default();
            }
        }
    } else {
        tui::print_info("No configuration file found. Using interactive mode.");
    }

    // Interactive setup
    interactive_setup(&mut config);

    // Show installation summary
    println!();
    tui::show_summary(
        &config.install.target_disk,
        &config.install.hostname,
        &config.install.username,
        &config.locale.timezone,
        config.locale.keyboards.first().map(|s| s.as_str()).unwrap_or("us"),
        &config.kernel.type_,
        config.install.use_encryption,
        config.disk.swap.label(),
    );

    // Final confirmation
    println!();
    tui::print_warning(&format!(
        "This will ERASE ALL DATA on {}",
        config.install.target_disk
    ));
    if !tui::confirm("Start installation? / 설치를 시작하시겠습니까?", false) {
        tui::print_info("Installation cancelled.");
        return;
    }

    // Start installation
    println!();
    tui::print_info("Starting installation... / 설치 시작...\n");

    let mut inst = installer::Installer::new(config);
    let success = inst.install();

    println!();
    if success {
        tui::draw_box(
            "Installation Complete! / 설치 완료!",
            &[
                "",
                "  Blunux has been installed successfully!",
                "  Blunux가 성공적으로 설치되었습니다!",
                "",
                "  Please remove the installation media and reboot.",
                "  설치 미디어를 제거하고 재부팅하세요.",
                "",
                "  Command: reboot",
                "",
            ],
        );
    } else {
        tui::print_error(&format!("Installation failed: {}", inst.get_error()));
        tui::print_info("Please check the error message and try again.");
        process::exit(1);
    }

    // Ask to reboot
    if tui::confirm("Reboot now? / 지금 재부팅하시겠습니까?", true) {
        let _ = process::Command::new("reboot").status();
    }
}
