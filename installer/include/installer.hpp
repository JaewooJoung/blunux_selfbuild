#pragma once

#include <string>
#include <vector>
#include <functional>
#include "config.hpp"
#include "disk.hpp"

namespace blunux {

class Installer {
public:
    using ProgressCallback = std::function<void(int step, int total, const std::string& message)>;

    explicit Installer(const Config& config);

    // Set progress callback
    void set_progress_callback(ProgressCallback callback);

    // Run the full installation
    bool install();

    // Individual installation steps
    bool prepare_disk();
    bool install_base_system();
    bool configure_system();
    bool install_packages();
    bool install_bootloader();
    bool configure_users();
    bool configure_locale();
    bool configure_input_method();
    bool finalize();

    // Get error message if installation failed
    std::string get_error() const { return error_message_; }

private:
    Config config_;
    ProgressCallback progress_callback_;
    std::string error_message_;
    std::string mount_point_ = "/mnt";
    disk::PartitionLayout partition_layout_;

    // Helper functions
    bool run_command(const std::string& cmd);
    bool run_chroot(const std::string& cmd);
    bool write_file(const std::string& path, const std::string& content);
    bool append_file(const std::string& path, const std::string& content);
    void report_progress(int step, int total, const std::string& message);

    // Get base packages for installation
    std::vector<std::string> get_base_packages() const;

    // Get desktop packages (KDE)
    std::vector<std::string> get_desktop_packages() const;

    // Get font packages based on locale
    std::vector<std::string> get_font_packages() const;

    // Get input method packages
    std::vector<std::string> get_input_method_packages() const;
};

}  // namespace blunux
