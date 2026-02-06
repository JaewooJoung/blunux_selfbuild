#include "tui.hpp"
#include <iostream>
#include <iomanip>
#include <termios.h>
#include <unistd.h>
#include <cstdio>

namespace blunux {
namespace tui {

void print_banner() {
    std::cout << colors::CYAN << R"(
    ╔══════════════════════════════════════════════════════════╗
    ║)" << colors::BOLD << "         Blunux Installer v1.0" << colors::RESET << colors::CYAN << R"(                        ║
    ║        Arch Linux + KDE Plasma Installation              ║
    ╚══════════════════════════════════════════════════════════╝
)" << colors::RESET << std::endl;
}

void print_info(const std::string& msg) {
    std::cout << colors::BLUE << "[*] " << colors::RESET << msg << std::endl;
}

void print_success(const std::string& msg) {
    std::cout << colors::GREEN << "[✓] " << colors::RESET << msg << std::endl;
}

void print_error(const std::string& msg) {
    std::cout << colors::RED << "[✗] " << colors::RESET << msg << std::endl;
}

void print_warning(const std::string& msg) {
    std::cout << colors::YELLOW << "[!] " << colors::RESET << msg << std::endl;
}

void print_step(int step, int total, const std::string& msg) {
    std::cout << colors::MAGENTA << "[" << step << "/" << total << "] "
              << colors::RESET << msg << std::endl;
}

void clear_screen() {
    std::cout << "\033[2J\033[H";
}

void draw_box(const std::string& title, const std::vector<std::string>& lines) {
    const int width = 60;

    // Top border
    std::cout << colors::CYAN << "╔";
    for (int i = 0; i < width - 2; ++i) std::cout << "═";
    std::cout << "╗" << colors::RESET << std::endl;

    // Title
    std::cout << colors::CYAN << "║ " << colors::BOLD << std::left
              << std::setw(width - 4) << title << colors::RESET
              << colors::CYAN << " ║" << colors::RESET << std::endl;

    // Separator
    std::cout << colors::CYAN << "╠";
    for (int i = 0; i < width - 2; ++i) std::cout << "═";
    std::cout << "╣" << colors::RESET << std::endl;

    // Content lines
    for (const auto& line : lines) {
        std::cout << colors::CYAN << "║ " << colors::RESET
                  << std::left << std::setw(width - 4) << line
                  << colors::CYAN << " ║" << colors::RESET << std::endl;
    }

    // Bottom border
    std::cout << colors::CYAN << "╚";
    for (int i = 0; i < width - 2; ++i) std::cout << "═";
    std::cout << "╝" << colors::RESET << std::endl;
}

int menu_select(const std::string& title,
                const std::vector<std::string>& options,
                int default_selection) {
    std::cout << std::endl;
    std::cout << colors::BOLD << title << colors::RESET << std::endl;
    std::cout << std::string(40, '-') << std::endl;

    for (size_t i = 0; i < options.size(); ++i) {
        std::cout << "  " << colors::CYAN << "[" << (i + 1) << "]"
                  << colors::RESET << " " << options[i];
        if (static_cast<int>(i) == default_selection) {
            std::cout << colors::GREEN << " (default)" << colors::RESET;
        }
        std::cout << std::endl;
    }

    std::cout << std::endl;
    std::cout << "Enter selection [1-" << options.size() << "]: ";

    std::string input_str;
    std::getline(std::cin, input_str);

    if (input_str.empty()) {
        return default_selection;
    }

    try {
        int selection = std::stoi(input_str) - 1;
        if (selection >= 0 && selection < static_cast<int>(options.size())) {
            return selection;
        }
    } catch (...) {}

    return default_selection;
}

bool confirm(const std::string& question, bool default_yes) {
    std::cout << std::endl;
    std::cout << colors::YELLOW << question << colors::RESET;
    if (default_yes) {
        std::cout << " [Y/n]: ";
    } else {
        std::cout << " [y/N]: ";
    }

    std::string input_str;
    std::getline(std::cin, input_str);

    if (input_str.empty()) {
        return default_yes;
    }

    char c = std::tolower(input_str[0]);
    return (c == 'y');
}

std::string input(const std::string& prompt, const std::string& default_value) {
    std::cout << prompt;
    if (!default_value.empty()) {
        std::cout << " [" << default_value << "]";
    }
    std::cout << ": ";

    std::string input_str;
    std::getline(std::cin, input_str);

    if (input_str.empty()) {
        return default_value;
    }
    return input_str;
}

std::string password_input(const std::string& prompt) {
    std::cout << prompt << ": ";

    // Disable echo
    struct termios old_term, new_term;
    tcgetattr(STDIN_FILENO, &old_term);
    new_term = old_term;
    new_term.c_lflag &= ~ECHO;
    tcsetattr(STDIN_FILENO, TCSANOW, &new_term);

    std::string password;
    std::getline(std::cin, password);

    // Restore echo
    tcsetattr(STDIN_FILENO, TCSANOW, &old_term);
    std::cout << std::endl;

    return password;
}

void progress_bar(int current, int total, const std::string& label) {
    const int bar_width = 40;
    float progress = static_cast<float>(current) / total;
    int pos = static_cast<int>(bar_width * progress);

    std::cout << "\r" << label << " [";
    for (int i = 0; i < bar_width; ++i) {
        if (i < pos) std::cout << colors::GREEN << "█" << colors::RESET;
        else if (i == pos) std::cout << colors::YELLOW << "▓" << colors::RESET;
        else std::cout << "░";
    }
    std::cout << "] " << int(progress * 100.0) << "%" << std::flush;

    if (current == total) {
        std::cout << std::endl;
    }
}

void wait_for_enter(const std::string& message) {
    std::cout << std::endl;
    std::cout << colors::CYAN << message << colors::RESET;
    std::cin.ignore();
}

std::optional<DiskInfo> select_disk(const std::vector<DiskInfo>& disks) {
    if (disks.empty()) {
        print_error("No disks found!");
        return std::nullopt;
    }

    std::cout << std::endl;
    std::cout << colors::BOLD << "Select installation disk:" << colors::RESET << std::endl;
    std::cout << std::string(60, '-') << std::endl;

    for (size_t i = 0; i < disks.size(); ++i) {
        std::cout << "  " << colors::CYAN << "[" << (i + 1) << "]"
                  << colors::RESET << " " << disks[i].device
                  << " - " << disks[i].size
                  << " (" << disks[i].model << ")" << std::endl;
    }

    std::cout << "  " << colors::RED << "[0]" << colors::RESET << " Cancel" << std::endl;
    std::cout << std::endl;
    std::cout << "Enter selection: ";

    std::string input_str;
    std::getline(std::cin, input_str);

    try {
        int selection = std::stoi(input_str);
        if (selection == 0) {
            return std::nullopt;
        }
        if (selection > 0 && selection <= static_cast<int>(disks.size())) {
            return disks[selection - 1];
        }
    } catch (...) {}

    print_error("Invalid selection");
    return std::nullopt;
}

void show_summary(const std::string& disk,
                  const std::string& hostname,
                  const std::string& username,
                  const std::string& timezone,
                  const std::string& keyboard,
                  const std::string& kernel,
                  bool encryption) {
    std::vector<std::string> lines = {
        "",
        "  Target disk:    " + disk,
        "  Hostname:       " + hostname,
        "  Username:       " + username,
        "  Timezone:       " + timezone,
        "  Keyboard:       " + keyboard,
        "  Kernel:         " + kernel,
        "  Encryption:     " + std::string(encryption ? "Yes" : "No"),
        "  Desktop:        KDE Plasma",
        ""
    };

    draw_box("Installation Summary / 설치 요약", lines);
}

}  // namespace tui
}  // namespace blunux
