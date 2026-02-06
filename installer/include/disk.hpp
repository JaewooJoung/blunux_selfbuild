#pragma once

#include <string>
#include <vector>
#include <optional>
#include "tui.hpp"

namespace blunux {
namespace disk {

// Get list of available disks
std::vector<tui::DiskInfo> get_disks();

// Partition schemes
enum class PartitionScheme {
    GPT_UEFI,      // GPT with EFI partition (modern)
    MBR_BIOS       // MBR for legacy BIOS
};

// Partition layout for installation
struct PartitionLayout {
    std::string efi_partition;    // /dev/sda1 (500M, only for UEFI)
    std::string root_partition;   // /dev/sda2 (rest)
    PartitionScheme scheme;
};

// Check if system booted in UEFI mode
bool is_uefi();

// Wipe and partition disk
// Returns partition layout on success
std::optional<PartitionLayout> partition_disk(
    const std::string& disk,
    PartitionScheme scheme
);

// Format partitions
bool format_partitions(const PartitionLayout& layout, bool use_encryption = false,
                       const std::string& encryption_password = "");

// Mount partitions for installation
bool mount_partitions(const PartitionLayout& layout, const std::string& mount_point = "/mnt");

// Unmount partitions
bool unmount_partitions(const std::string& mount_point = "/mnt");

// Get disk size in human-readable format
std::string get_disk_size(const std::string& device);

// Check if disk has partitions
bool has_partitions(const std::string& device);

// Generate fstab
bool generate_fstab(const std::string& mount_point = "/mnt");

}  // namespace disk
}  // namespace blunux
