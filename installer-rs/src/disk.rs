use crate::tui;
use std::path::Path;
use std::process::Command;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PartitionScheme {
    GptUefi,
    MbrBios,
}

#[derive(Debug, Clone)]
pub struct PartitionLayout {
    pub efi_partition: String,
    pub root_partition: String,
    pub scheme: PartitionScheme,
}

/// Execute a command and capture stdout
fn exec(cmd: &str) -> String {
    Command::new("sh")
        .args(["-c", cmd])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string())
        .unwrap_or_default()
}

/// Run a command and return success/failure
fn run_cmd(cmd: &str) -> bool {
    Command::new("sh")
        .args(["-c", cmd])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Get list of available disks
pub fn get_disks() -> Vec<tui::DiskInfo> {
    let output = exec("lsblk -d -n -o NAME,SIZE,MODEL,TYPE 2>/dev/null");
    let mut disks = Vec::new();

    for line in output.lines() {
        if line.is_empty() {
            continue;
        }

        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 2 {
            continue;
        }

        let name = parts[0];
        let size = parts[1];

        // Last token is type, everything between size and type is model
        let type_ = parts.last().unwrap_or(&"");

        if *type_ != "disk" {
            continue;
        }

        let model = if parts.len() > 3 {
            parts[2..parts.len() - 1].join(" ")
        } else {
            "Unknown".to_string()
        };

        disks.push(tui::DiskInfo {
            device: format!("/dev/{name}"),
            size: size.to_string(),
            model,
        });
    }

    disks
}

/// Check if system booted in UEFI mode
pub fn is_uefi() -> bool {
    Path::new("/sys/firmware/efi").exists()
}

/// Wipe and partition disk
pub fn partition_disk(disk: &str, scheme: PartitionScheme) -> Option<PartitionLayout> {
    let mut layout = PartitionLayout {
        efi_partition: String::new(),
        root_partition: String::new(),
        scheme,
    };

    // First, unmount any existing partitions on this disk
    tui::print_info(&format!(
        "Checking for mounted partitions on {disk}..."
    ));

    let partitions = exec(&format!(
        "lsblk -ln -o NAME {disk} 2>/dev/null | tail -n +2"
    ));
    for part_name in partitions.lines() {
        let part_name = part_name.trim();
        if !part_name.is_empty() {
            let part_dev = format!("/dev/{part_name}");
            run_cmd(&format!("umount -f {part_dev} 2>/dev/null"));
            run_cmd(&format!("swapoff {part_dev} 2>/dev/null"));
        }
    }

    // Close any LUKS devices
    run_cmd("cryptsetup close cryptroot 2>/dev/null");
    run_cmd("sleep 1");

    // Wipe existing partition table
    tui::print_info(&format!("Wiping disk: {disk}"));
    if !run_cmd(&format!("wipefs -af {disk} 2>/dev/null")) {
        tui::print_warning("Could not wipe disk signatures");
    }

    run_cmd(&format!("partprobe {disk} 2>/dev/null"));
    run_cmd("sleep 1");

    let is_nvme = disk.contains("nvme") || disk.contains("mmcblk");

    match scheme {
        PartitionScheme::GptUefi => {
            tui::print_info("Creating GPT partition table...");

            if !run_cmd(&format!("parted -s {disk} mklabel gpt")) {
                tui::print_error("Failed to create GPT partition table");
                return None;
            }

            // Create EFI partition (512MB)
            if !run_cmd(&format!(
                "parted -s {disk} mkpart primary fat32 1MiB 513MiB"
            )) {
                tui::print_error("Failed to create EFI partition");
                return None;
            }

            // Set ESP flag
            run_cmd(&format!("parted -s {disk} set 1 esp on"));

            // Create root partition (rest of disk)
            if !run_cmd(&format!(
                "parted -s {disk} mkpart primary ext4 513MiB 100%"
            )) {
                tui::print_error("Failed to create root partition");
                return None;
            }

            if is_nvme {
                layout.efi_partition = format!("{disk}p1");
                layout.root_partition = format!("{disk}p2");
            } else {
                layout.efi_partition = format!("{disk}1");
                layout.root_partition = format!("{disk}2");
            }
        }
        PartitionScheme::MbrBios => {
            tui::print_info("Creating MBR partition table...");

            if !run_cmd(&format!("parted -s {disk} mklabel msdos")) {
                tui::print_error("Failed to create MBR partition table");
                return None;
            }

            if !run_cmd(&format!(
                "parted -s {disk} mkpart primary ext4 1MiB 100%"
            )) {
                tui::print_error("Failed to create root partition");
                return None;
            }

            run_cmd(&format!("parted -s {disk} set 1 boot on"));

            if is_nvme {
                layout.root_partition = format!("{disk}p1");
            } else {
                layout.root_partition = format!("{disk}1");
            }
        }
    }

    // Wait for kernel to recognize partitions
    run_cmd(&format!("partprobe {disk}"));
    run_cmd("sleep 2");

    tui::print_success("Partitioning complete");
    Some(layout)
}

/// Format partitions
pub fn format_partitions(
    layout: &PartitionLayout,
    use_encryption: bool,
    encryption_password: &str,
) -> bool {
    // Format EFI partition if UEFI
    if layout.scheme == PartitionScheme::GptUefi {
        tui::print_info("Formatting EFI partition...");
        if !run_cmd(&format!("mkfs.fat -F32 {}", layout.efi_partition)) {
            tui::print_error("Failed to format EFI partition");
            return false;
        }
    }

    // Format root partition
    if use_encryption {
        tui::print_info("Setting up encryption on root partition...");

        let cmd = format!(
            "echo -n '{}' | cryptsetup luksFormat --type luks2 {} -",
            encryption_password, layout.root_partition
        );
        if !run_cmd(&cmd) {
            tui::print_error("Failed to encrypt root partition");
            return false;
        }

        let cmd = format!(
            "echo -n '{}' | cryptsetup open {} cryptroot -",
            encryption_password, layout.root_partition
        );
        if !run_cmd(&cmd) {
            tui::print_error("Failed to open encrypted partition");
            return false;
        }

        if !run_cmd("mkfs.ext4 -F /dev/mapper/cryptroot") {
            tui::print_error("Failed to format encrypted root partition");
            return false;
        }
    } else {
        tui::print_info("Formatting root partition...");
        if !run_cmd(&format!("mkfs.ext4 -F {}", layout.root_partition)) {
            tui::print_error("Failed to format root partition");
            return false;
        }
    }

    tui::print_success("Formatting complete");
    true
}

/// Mount partitions for installation
pub fn mount_partitions(layout: &PartitionLayout, mount_point: &str) -> bool {
    run_cmd(&format!("mkdir -p {mount_point}"));

    // Mount root partition
    let root_dev = if Path::new("/dev/mapper/cryptroot").exists() {
        "/dev/mapper/cryptroot".to_string()
    } else {
        layout.root_partition.clone()
    };

    tui::print_info("Mounting root partition...");
    if !run_cmd(&format!("mount {root_dev} {mount_point}")) {
        tui::print_error("Failed to mount root partition");
        return false;
    }

    // Mount EFI partition if UEFI
    if layout.scheme == PartitionScheme::GptUefi {
        tui::print_info("Mounting EFI partition...");
        run_cmd(&format!("mkdir -p {mount_point}/boot/efi"));
        if !run_cmd(&format!(
            "mount {} {mount_point}/boot/efi",
            layout.efi_partition
        )) {
            tui::print_error("Failed to mount EFI partition");
            return false;
        }
    }

    tui::print_success("Partitions mounted");
    true
}

/// Unmount partitions
pub fn unmount_partitions(mount_point: &str) -> bool {
    run_cmd(&format!("umount -R {mount_point} 2>/dev/null"));
    run_cmd("cryptsetup close cryptroot 2>/dev/null");
    true
}

/// Generate fstab
pub fn generate_fstab(mount_point: &str) -> bool {
    tui::print_info("Generating fstab...");
    run_cmd(&format!(
        "genfstab -U {mount_point} >> {mount_point}/etc/fstab"
    ))
}

/// Get total system RAM in MB
pub fn get_ram_mb() -> u64 {
    let output = exec("free -m | awk '/^Mem:/ {print $2}'");
    output.trim().parse::<u64>().unwrap_or(4096)
}
