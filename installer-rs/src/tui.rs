use std::io::{self, BufRead, Write};

// ANSI color codes
pub const RESET: &str = "\x1b[0m";
pub const BOLD: &str = "\x1b[1m";
pub const RED: &str = "\x1b[31m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const BLUE: &str = "\x1b[34m";
pub const MAGENTA: &str = "\x1b[35m";
pub const CYAN: &str = "\x1b[36m";

#[derive(Debug, Clone)]
pub struct DiskInfo {
    pub device: String,
    pub model: String,
    pub size: String,
}

pub fn print_banner() {
    println!(
        "{CYAN}
    ╔══════════════════════════════════════════════════════════╗
    ║{BOLD}         Blunux Installer v1.0 (Rust){RESET}{CYAN}                    ║
    ║        Arch Linux + KDE Plasma Installation              ║
    ╚══════════════════════════════════════════════════════════╝
{RESET}"
    );
}

pub fn print_info(msg: &str) {
    println!("{BLUE}[*] {RESET}{msg}");
}

pub fn print_success(msg: &str) {
    println!("{GREEN}[✓] {RESET}{msg}");
}

pub fn print_error(msg: &str) {
    println!("{RED}[✗] {RESET}{msg}");
}

pub fn print_warning(msg: &str) {
    println!("{YELLOW}[!] {RESET}{msg}");
}

pub fn print_step(step: i32, total: i32, msg: &str) {
    println!("{MAGENTA}[{step}/{total}] {RESET}{msg}");
}

pub fn clear_screen() {
    print!("\x1b[2J\x1b[H");
    let _ = io::stdout().flush();
}

pub fn draw_box(title: &str, lines: &[&str]) {
    let width = 60usize;

    // Top border
    print!("{CYAN}╔");
    for _ in 0..width - 2 {
        print!("═");
    }
    println!("╗{RESET}");

    // Title
    println!(
        "{CYAN}║ {BOLD}{title:<w$}{RESET}{CYAN} ║{RESET}",
        w = width - 4
    );

    // Separator
    print!("{CYAN}╠");
    for _ in 0..width - 2 {
        print!("═");
    }
    println!("╣{RESET}");

    // Content lines
    for line in lines {
        println!(
            "{CYAN}║ {RESET}{line:<w$}{CYAN} ║{RESET}",
            w = width - 4
        );
    }

    // Bottom border
    print!("{CYAN}╚");
    for _ in 0..width - 2 {
        print!("═");
    }
    println!("╝{RESET}");
}

pub fn menu_select(title: &str, options: &[&str], default_selection: usize) -> usize {
    println!();
    println!("{BOLD}{title}{RESET}");
    println!("{}", "-".repeat(40));

    for (i, option) in options.iter().enumerate() {
        if i == default_selection {
            println!("  {CYAN}[{}]{RESET} {option} {GREEN}(default){RESET}", i + 1);
        } else {
            println!("  {CYAN}[{}]{RESET} {option}", i + 1);
        }
    }

    println!();
    print!("Enter selection [1-{}]: ", options.len());
    let _ = io::stdout().flush();

    let mut input = String::new();
    io::stdin().lock().read_line(&mut input).unwrap_or(0);
    let input = input.trim();

    if input.is_empty() {
        return default_selection;
    }

    match input.parse::<usize>() {
        Ok(n) if n >= 1 && n <= options.len() => n - 1,
        _ => default_selection,
    }
}

pub fn confirm(question: &str, default_yes: bool) -> bool {
    println!();
    if default_yes {
        print!("{YELLOW}{question}{RESET} [Y/n]: ");
    } else {
        print!("{YELLOW}{question}{RESET} [y/N]: ");
    }
    let _ = io::stdout().flush();

    let mut input = String::new();
    io::stdin().lock().read_line(&mut input).unwrap_or(0);
    let input = input.trim();

    if input.is_empty() {
        return default_yes;
    }

    input.to_lowercase().starts_with('y')
}

pub fn input_prompt(prompt: &str, default_value: &str) -> String {
    if default_value.is_empty() {
        print!("{prompt}: ");
    } else {
        print!("{prompt} [{default_value}]: ");
    }
    let _ = io::stdout().flush();

    let mut input = String::new();
    io::stdin().lock().read_line(&mut input).unwrap_or(0);
    let input = input.trim().to_string();

    if input.is_empty() {
        default_value.to_string()
    } else {
        input
    }
}

pub fn password_input(prompt: &str) -> String {
    print!("{prompt}: ");
    let _ = io::stdout().flush();

    // Disable echo using termios
    let password = disable_echo_and_read();
    println!(); // newline after hidden input
    password
}

fn disable_echo_and_read() -> String {
    let stdin = io::stdin();

    // Save current terminal settings
    let old_termios = match nix::sys::termios::tcgetattr(&stdin) {
        Ok(t) => t,
        Err(_) => {
            // Fallback: read without hiding
            let mut input = String::new();
            stdin.lock().read_line(&mut input).unwrap_or(0);
            return input.trim().to_string();
        }
    };

    // Disable echo
    let mut new_termios = old_termios.clone();
    new_termios.local_flags &= !nix::sys::termios::LocalFlags::ECHO;
    let _ = nix::sys::termios::tcsetattr(
        &stdin,
        nix::sys::termios::SetArg::TCSANOW,
        &new_termios,
    );

    let mut input = String::new();
    stdin.lock().read_line(&mut input).unwrap_or(0);

    // Restore terminal settings
    let _ = nix::sys::termios::tcsetattr(
        &stdin,
        nix::sys::termios::SetArg::TCSANOW,
        &old_termios,
    );

    input.trim().to_string()
}

pub fn select_disk(disks: &[DiskInfo]) -> Option<DiskInfo> {
    if disks.is_empty() {
        print_error("No disks found!");
        return None;
    }

    println!();
    println!("{BOLD}Select installation disk:{RESET}");
    println!("{}", "-".repeat(60));

    for (i, disk) in disks.iter().enumerate() {
        println!(
            "  {CYAN}[{}]{RESET} {} - {} ({})",
            i + 1,
            disk.device,
            disk.size,
            disk.model
        );
    }

    println!("  {RED}[0]{RESET} Cancel");
    println!();
    print!("Enter selection: ");
    let _ = io::stdout().flush();

    let mut input = String::new();
    io::stdin().lock().read_line(&mut input).unwrap_or(0);
    let input = input.trim();

    match input.parse::<usize>() {
        Ok(0) => None,
        Ok(n) if n >= 1 && n <= disks.len() => Some(disks[n - 1].clone()),
        _ => {
            print_error("Invalid selection");
            None
        }
    }
}

pub fn show_summary(
    disk: &str,
    hostname: &str,
    username: &str,
    timezone: &str,
    keyboard: &str,
    kernel: &str,
    encryption: bool,
    swap_mode: &str,
) {
    let enc_str = if encryption { "Yes" } else { "No" };
    let l_disk = format!("  Target disk:    {disk}");
    let l_host = format!("  Hostname:       {hostname}");
    let l_user = format!("  Username:       {username}");
    let l_tz = format!("  Timezone:       {timezone}");
    let l_kb = format!("  Keyboard:       {keyboard}");
    let l_kern = format!("  Kernel:         {kernel}");
    let l_enc = format!("  Encryption:     {enc_str}");
    let l_swap = format!("  Swap:           {swap_mode}");

    let lines: Vec<&str> = vec![
        "",
        &l_disk,
        &l_host,
        &l_user,
        &l_tz,
        &l_kb,
        &l_kern,
        &l_enc,
        &l_swap,
        "  Desktop:        KDE Plasma",
        "",
    ];

    draw_box("Installation Summary / 설치 요약", &lines);
}
