#include "disk.hpp"
#include <fstream>
#include <sstream>
#include <cstdlib>
#include <array>
#include <memory>
#include <regex>
#include <filesystem>

namespace blunux {
namespace disk {

namespace {

std::string exec(const std::string& cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) {
        return "";
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

bool run_cmd(const std::string& cmd) {
    return system(cmd.c_str()) == 0;
}

}  // namespace

std::vector<tui::DiskInfo> get_disks() {
    std::vector<tui::DiskInfo> disks;

    // Use lsblk to get disk information
    std::string output = exec("lsblk -d -n -o NAME,SIZE,MODEL,TYPE 2>/dev/null");

    std::istringstream iss(output);
    std::string line;

    while (std::getline(iss, line)) {
        if (line.empty()) continue;

        // Parse line: NAME SIZE MODEL TYPE
        std::istringstream line_stream(line);
        std::string name, size, type;
        std::string model;

        line_stream >> name >> size;

        // Read the rest for model and type
        std::string rest;
        std::getline(line_stream, rest);

        // Find type (last word)
        size_t last_space = rest.rfind(' ');
        if (last_space != std::string::npos) {
            type = rest.substr(last_space + 1);
            model = rest.substr(0, last_space);
            // Trim model
            size_t start = model.find_first_not_of(" \t");
            size_t end = model.find_last_not_of(" \t");
            if (start != std::string::npos) {
                model = model.substr(start, end - start + 1);
            }
        } else {
            type = rest;
        }

        // Only include disk type devices (not partitions, loop devices, etc.)
        if (type == "disk") {
            tui::DiskInfo info;
            info.device = "/dev/" + name;
            info.size = size;
            info.model = model.empty() ? "Unknown" : model;
            info.type = type;
            disks.push_back(info);
        }
    }

    return disks;
}

bool is_uefi() {
    return std::filesystem::exists("/sys/firmware/efi");
}

std::optional<PartitionLayout> partition_disk(
    const std::string& disk,
    PartitionScheme scheme
) {
    PartitionLayout layout;
    layout.scheme = scheme;

    // First, unmount any existing partitions on this disk
    tui::print_info("Checking for mounted partitions on " + disk + "...");

    // Get all partitions on this disk and unmount them
    std::string partitions = exec("lsblk -ln -o NAME " + disk + " 2>/dev/null | tail -n +2");
    std::istringstream part_stream(partitions);
    std::string part_name;
    while (std::getline(part_stream, part_name)) {
        if (!part_name.empty()) {
            // Trim whitespace
            size_t start = part_name.find_first_not_of(" \t\n\r");
            size_t end = part_name.find_last_not_of(" \t\n\r");
            if (start != std::string::npos) {
                part_name = part_name.substr(start, end - start + 1);
            }
            std::string part_dev = "/dev/" + part_name;
            run_cmd("umount -f " + part_dev + " 2>/dev/null");
            run_cmd("swapoff " + part_dev + " 2>/dev/null");
        }
    }

    // Close any LUKS devices that might be using this disk
    run_cmd("cryptsetup close cryptroot 2>/dev/null");

    // Wait a moment for unmounts to complete
    run_cmd("sleep 1");

    // Wipe existing partition table
    tui::print_info("Wiping disk: " + disk);
    if (!run_cmd("wipefs -af " + disk + " 2>/dev/null")) {
        tui::print_warning("Could not wipe disk signatures");
    }

    // Force kernel to re-read partition table
    run_cmd("partprobe " + disk + " 2>/dev/null");
    run_cmd("sleep 1");

    if (scheme == PartitionScheme::GPT_UEFI) {
        // Create GPT partition table
        tui::print_info("Creating GPT partition table...");

        // Use parted for GPT partitioning
        std::string cmd = "parted -s " + disk + " mklabel gpt";
        if (!run_cmd(cmd)) {
            tui::print_error("Failed to create GPT partition table");
            return std::nullopt;
        }

        // Create EFI partition (512MB)
        cmd = "parted -s " + disk + " mkpart primary fat32 1MiB 513MiB";
        if (!run_cmd(cmd)) {
            tui::print_error("Failed to create EFI partition");
            return std::nullopt;
        }

        // Set ESP flag
        cmd = "parted -s " + disk + " set 1 esp on";
        run_cmd(cmd);

        // Create root partition (rest of disk)
        cmd = "parted -s " + disk + " mkpart primary ext4 513MiB 100%";
        if (!run_cmd(cmd)) {
            tui::print_error("Failed to create root partition");
            return std::nullopt;
        }

        // Determine partition naming scheme (/dev/sda1 vs /dev/nvme0n1p1)
        if (disk.find("nvme") != std::string::npos ||
            disk.find("mmcblk") != std::string::npos) {
            layout.efi_partition = disk + "p1";
            layout.root_partition = disk + "p2";
        } else {
            layout.efi_partition = disk + "1";
            layout.root_partition = disk + "2";
        }

    } else {
        // MBR for legacy BIOS
        tui::print_info("Creating MBR partition table...");

        std::string cmd = "parted -s " + disk + " mklabel msdos";
        if (!run_cmd(cmd)) {
            tui::print_error("Failed to create MBR partition table");
            return std::nullopt;
        }

        // Create single root partition
        cmd = "parted -s " + disk + " mkpart primary ext4 1MiB 100%";
        if (!run_cmd(cmd)) {
            tui::print_error("Failed to create root partition");
            return std::nullopt;
        }

        // Set boot flag
        cmd = "parted -s " + disk + " set 1 boot on";
        run_cmd(cmd);

        if (disk.find("nvme") != std::string::npos ||
            disk.find("mmcblk") != std::string::npos) {
            layout.root_partition = disk + "p1";
        } else {
            layout.root_partition = disk + "1";
        }
    }

    // Wait for kernel to recognize partitions
    run_cmd("partprobe " + disk);
    run_cmd("sleep 2");

    tui::print_success("Partitioning complete");
    return layout;
}

bool format_partitions(const PartitionLayout& layout, bool use_encryption,
                       const std::string& encryption_password) {
    // Format EFI partition if UEFI
    if (layout.scheme == PartitionScheme::GPT_UEFI) {
        tui::print_info("Formatting EFI partition...");
        if (!run_cmd("mkfs.fat -F32 " + layout.efi_partition)) {
            tui::print_error("Failed to format EFI partition");
            return false;
        }
    }

    // Format root partition
    if (use_encryption) {
        tui::print_info("Setting up encryption on root partition...");

        // Create encrypted partition
        std::string cmd = "echo -n '" + encryption_password +
                         "' | cryptsetup luksFormat --type luks2 " +
                         layout.root_partition + " -";
        if (!run_cmd(cmd)) {
            tui::print_error("Failed to encrypt root partition");
            return false;
        }

        // Open encrypted partition
        cmd = "echo -n '" + encryption_password +
              "' | cryptsetup open " + layout.root_partition + " cryptroot -";
        if (!run_cmd(cmd)) {
            tui::print_error("Failed to open encrypted partition");
            return false;
        }

        // Format the encrypted container
        if (!run_cmd("mkfs.ext4 -F /dev/mapper/cryptroot")) {
            tui::print_error("Failed to format encrypted root partition");
            return false;
        }
    } else {
        tui::print_info("Formatting root partition...");
        if (!run_cmd("mkfs.ext4 -F " + layout.root_partition)) {
            tui::print_error("Failed to format root partition");
            return false;
        }
    }

    tui::print_success("Formatting complete");
    return true;
}

bool mount_partitions(const PartitionLayout& layout, const std::string& mount_point) {
    // Create mount point
    run_cmd("mkdir -p " + mount_point);

    // Mount root partition
    std::string root_dev = layout.root_partition;
    // Check if encrypted
    if (std::filesystem::exists("/dev/mapper/cryptroot")) {
        root_dev = "/dev/mapper/cryptroot";
    }

    tui::print_info("Mounting root partition...");
    if (!run_cmd("mount " + root_dev + " " + mount_point)) {
        tui::print_error("Failed to mount root partition");
        return false;
    }

    // Mount EFI partition if UEFI
    if (layout.scheme == PartitionScheme::GPT_UEFI) {
        tui::print_info("Mounting EFI partition...");
        run_cmd("mkdir -p " + mount_point + "/boot/efi");
        if (!run_cmd("mount " + layout.efi_partition + " " + mount_point + "/boot/efi")) {
            tui::print_error("Failed to mount EFI partition");
            return false;
        }
    }

    tui::print_success("Partitions mounted");
    return true;
}

bool unmount_partitions(const std::string& mount_point) {
    // Unmount in reverse order
    run_cmd("umount -R " + mount_point + " 2>/dev/null");
    run_cmd("cryptsetup close cryptroot 2>/dev/null");
    return true;
}

std::string get_disk_size(const std::string& device) {
    std::string output = exec("lsblk -d -n -o SIZE " + device + " 2>/dev/null");
    // Remove trailing newline
    if (!output.empty() && output.back() == '\n') {
        output.pop_back();
    }
    return output;
}

bool has_partitions(const std::string& device) {
    std::string output = exec("lsblk -n -o TYPE " + device + " 2>/dev/null");
    return output.find("part") != std::string::npos;
}

bool generate_fstab(const std::string& mount_point) {
    tui::print_info("Generating fstab...");
    return run_cmd("genfstab -U " + mount_point + " >> " + mount_point + "/etc/fstab");
}

}  // namespace disk
}  // namespace blunux
