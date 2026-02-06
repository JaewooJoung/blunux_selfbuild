#pragma once

#include <string>
#include <vector>
#include <functional>
#include <optional>

namespace blunux {
namespace tui {

// ANSI color codes
namespace colors {
    constexpr const char* RESET   = "\033[0m";
    constexpr const char* BOLD    = "\033[1m";
    constexpr const char* RED     = "\033[31m";
    constexpr const char* GREEN   = "\033[32m";
    constexpr const char* YELLOW  = "\033[33m";
    constexpr const char* BLUE    = "\033[34m";
    constexpr const char* MAGENTA = "\033[35m";
    constexpr const char* CYAN    = "\033[36m";
    constexpr const char* WHITE   = "\033[37m";
    constexpr const char* BG_BLUE = "\033[44m";
}

// Display banner
void print_banner();

// Print colored messages
void print_info(const std::string& msg);
void print_success(const std::string& msg);
void print_error(const std::string& msg);
void print_warning(const std::string& msg);
void print_step(int step, int total, const std::string& msg);

// Clear screen
void clear_screen();

// Draw a box around text
void draw_box(const std::string& title, const std::vector<std::string>& lines);

// Menu selection - returns selected index
int menu_select(const std::string& title,
                const std::vector<std::string>& options,
                int default_selection = 0);

// Yes/No prompt
bool confirm(const std::string& question, bool default_yes = true);

// Text input
std::string input(const std::string& prompt, const std::string& default_value = "");

// Password input (hidden)
std::string password_input(const std::string& prompt);

// Progress bar
void progress_bar(int current, int total, const std::string& label = "");

// Wait for key press
void wait_for_enter(const std::string& message = "Press Enter to continue...");

// Display disk selection menu
struct DiskInfo {
    std::string device;     // /dev/sda
    std::string model;      // Samsung SSD
    std::string size;       // 500G
    std::string type;       // disk
};

std::optional<DiskInfo> select_disk(const std::vector<DiskInfo>& disks);

// Display installation summary
void show_summary(const std::string& disk,
                  const std::string& hostname,
                  const std::string& username,
                  const std::string& timezone,
                  const std::string& keyboard,
                  const std::string& kernel,
                  bool encryption);

}  // namespace tui
}  // namespace blunux
