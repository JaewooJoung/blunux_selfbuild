#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 archiso.jl                                                        ┃
#┃ 📙Brief     📝 Archiso Build Module for Blunux Self-Build                        ┃
#┃ 🧾Details   🔎 Profile initialization, package config, and ISO generation        ┃
#┃ 🚩OAuthor   🦋 Blunux Project                                                    ┃
#┃ 👨‍🔧LAuthor   👤 Blunux Project                                                    ┃
#┃ 📆LastDate  📍 2026-01-25 🔄Please support to keep update🔄                      ┃
#┃ 🏭License   📜 MIT License                                                       ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#=
Archiso build module for Blunux Self-Build Tool

Handles archiso profile initialization and ISO building.
=#

"""
    init_archiso_profile(work_dir, build_name; language="korean")

Initialize an archiso profile by copying the releng profile.
Returns the path to the profile directory.

ISO filename format: blunux-XXXXXX-language-yyyy.mm.dd-x86_64.iso
Where XXXXXX is a 6-digit hex build ID (checksum + time).
"""
function init_archiso_profile(work_dir, build_name; language::String="korean")
    profile_dir = joinpath(work_dir, "profile")

    # Remove existing profile if exists
    if isdir(profile_dir)
        println("    Removing existing profile directory...")
        rm(profile_dir, recursive=true)
    end

    # Create work directory
    mkpath(work_dir)

    # Copy archiso releng profile
    releng_path = "/usr/share/archiso/configs/releng"
    if !isdir(releng_path)
        error("Archiso releng profile not found at $releng_path. Is archiso installed?")
    end

    println("    Copying releng profile...")
    # Use shell cp -a to handle symlinks properly (Julia's cp fails on broken symlinks)
    run(`cp -a $releng_path $profile_dir`)

    # Generate build ID for ISO naming
    build_datetime = Dates.now()
    build_id = generate_build_id(build_datetime)
    date_str = Dates.format(build_datetime, "yyyy.mm.dd")
    time_str = Dates.format(build_datetime, "HH.MM.SS")

    # ISO name format: blunux-BUILDID-language-date
    # ISO version: time (HH.MM.SS)
    # Final filename: blunux-BUILDID-language-date-HH.MM.SS-x86_64.iso
    iso_base_name = "blunux-$(build_id)-$(language)-$(date_str)"
    # Copy Blunux profile base template (pre-created config files)
    # This approach follows CachyOS best practices - static files in repo
    script_dir = dirname(dirname(@__FILE__))
    profile_base = joinpath(script_dir, "profile_base")
    if isdir(profile_base)
        println("    Applying Blunux profile template...")
        # Use shell cp -a to handle symlinks properly (Julia's cp fails on broken symlinks)
        # --remove-destination removes existing symlinks before copying (releng has resolv.conf as symlink)
        run(`sh -c "cp -a --remove-destination $profile_base/* $profile_dir/"`)
        println("    Applied Blunux profile template")
    else
        # Fallback: ensure directory structure exists manually
        airootfs_dir = joinpath(profile_dir, "airootfs")
        mkpath(airootfs_dir)
        mkpath(joinpath(airootfs_dir, "etc"))
        mkpath(joinpath(airootfs_dir, "etc", "systemd", "system"))
        println("    Created airootfs directory structure (no template found)")
    end

    # Update profile name and add file permissions
    profiledef_path = joinpath(profile_dir, "profiledef.sh")
    if isfile(profiledef_path)
        content = read(profiledef_path, String)
        content = replace(content, r"iso_name=\"[^\"]*\"" => "iso_name=\"$(iso_base_name)\"")
        # ISO version: replace entire line to handle $(date ...) command substitution
        content = replace(content, r"^iso_version=.*$"m => "iso_version=\"$(time_str)\"")
        # ISO label: Keep it very short, archiso may add timestamp
        # BLUNUX = 6 chars, leaves room for archiso additions
        content = replace(content, r"iso_label=\"[^\"]*\"" => "iso_label=\"BLUNUX\"")
        content = replace(content, r"iso_publisher=\"[^\"]*\"" => "iso_publisher=\"Blunux <https://blunux.com>\"")
        content = replace(content, r"iso_application=\"[^\"]*\"" => "iso_application=\"Blunux Live/Install ISO\"")

        # Append Blunux-specific file permissions using bash += syntax
        # archiso uses file_permissions to set ownership and permissions in squashfs
        content *= """

# Blunux file permissions
file_permissions+=(
  ["/usr/local/bin/blunux-install"]="0:0:755"
  ["/usr/local/bin/blunux-installer"]="0:0:755"
  ["/home/live"]="1000:1000:750"
  ["/etc/sudoers.d/live"]="0:0:440"
  ["/etc/blunux"]="0:0:755"
)
"""

        write(profiledef_path, content)
    end

    # Enable multilib repository for 32-bit packages (steam, wine, etc.)
    enable_multilib(profile_dir)

    println("    Profile initialized at: $profile_dir")
    println("    Build ID: $(build_id)")
    println("    ISO name: $(iso_base_name)-$(time_str)-x86_64.iso")
    return profile_dir
end

"""
    enable_multilib(profile_dir)

Enable multilib repository in pacman.conf for 32-bit packages like steam, wine.
"""
function enable_multilib(profile_dir)
    pacman_conf = joinpath(profile_dir, "pacman.conf")
    if !isfile(pacman_conf)
        @warn "pacman.conf not found in profile"
        return
    end

    content = read(pacman_conf, String)

    # Check if multilib is already enabled
    if occursin(r"^\[multilib\]"m, content)
        println("    multilib repository already enabled")
        return
    end

    # Add multilib repository
    multilib_config = """

[multilib]
Include = /etc/pacman.d/mirrorlist
"""
    content *= multilib_config
    write(pacman_conf, content)
    println("    Enabled multilib repository (for steam, wine, etc.)")
end

"""
    configure_mkinitcpio(profile_dir)

Configure mkinitcpio.conf with proper hooks for keyboard/mouse support.
This is critical for input devices to work in the live environment.
"""
function configure_mkinitcpio(profile_dir)
    airootfs_dir = joinpath(profile_dir, "airootfs")
    mkinitcpio_dir = joinpath(airootfs_dir, "etc")
    mkpath(mkinitcpio_dir)

    mkinitcpio_conf = joinpath(mkinitcpio_dir, "mkinitcpio.conf")

    # Create mkinitcpio.conf with proper hooks
    # Based on CachyOS and archiso releng configuration
    # CRITICAL: keyboard hook must come BEFORE block/filesystems for input to work
    open(mkinitcpio_conf, "w") do f
        print(f, raw"""
# mkinitcpio.conf for Blunux Live ISO
# Based on CachyOS Live ISO configuration
# This configuration ensures keyboard/mouse work properly

# MODULES
# Include USB HID drivers for broad hardware compatibility
# These ensure keyboard/mouse work even if autodetect doesn't find them
MODULES=(hid_generic usbhid xhci_hcd ohci_hcd ehci_hcd atkbd i8042)

# BINARIES
BINARIES=()

# FILES
FILES=()

# HOOKS
# Hook order based on CachyOS + archiso releng profile:
# - microcode: Load CPU microcode early (requires amd-ucode/intel-ucode packages)
# - keyboard: MUST come before block and filesystems for input to work
# - memdisk: Memory disk support for live environment
HOOKS=(base udev microcode modconf kms memdisk keyboard keymap consolefont block filesystems archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs)

# COMPRESSION
COMPRESSION="zstd"
""")
    end

    println("    Configured mkinitcpio with keyboard hook and USB modules")
end

"""
    configure_systemd_services(profile_dir)

Configure systemd services for the live environment.
Based on CachyOS Live ISO configuration.

This is CRITICAL for:
- pacman keyring initialization (archinstall needs this)
- NetworkManager to work properly
- Time synchronization
"""
function configure_systemd_services(profile_dir)
    airootfs_dir = joinpath(profile_dir, "airootfs")

    # Ensure airootfs and etc directories exist
    if !isdir(airootfs_dir)
        mkpath(airootfs_dir)
        println("    Created airootfs directory: $airootfs_dir")
    end

    etc_dir = joinpath(airootfs_dir, "etc")
    if !isdir(etc_dir)
        mkpath(etc_dir)
        println("    Created etc directory: $etc_dir")
    end

    systemd_dir = joinpath(etc_dir, "systemd", "system")
    mkpath(systemd_dir)

    # Note: We no longer create a custom sysusers.d config
    # Packages create their own users via their sysusers.d files
    # We add critical users (polkitd) explicitly to passwd/group later

    # =====================================================
    # 1. Create pacman-init.service (CRITICAL for archinstall)
    # =====================================================
    pacman_init_service = joinpath(systemd_dir, "pacman-init.service")
    open(pacman_init_service, "w") do f
        print(f, raw"""
# SPDX-License-Identifier: GPL-3.0-or-later
[Unit]
Description=Initializes Pacman keyring
Before=sshd.service
ConditionDirectoryNotEmpty=!/etc/pacman.d/gnupg

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/pacman-key --init
ExecStart=/usr/bin/pacman-key --populate

[Install]
WantedBy=multi-user.target
""")
    end

    # =====================================================
    # 2. Create etc-pacman.d-gnupg.mount (for pacman GPG keys)
    # =====================================================
    gnupg_mount = joinpath(systemd_dir, "etc-pacman.d-gnupg.mount")
    open(gnupg_mount, "w") do f
        print(f, raw"""
[Unit]
Description=Temporary /etc/pacman.d/gnupg directory

[Mount]
What=tmpfs
Where=/etc/pacman.d/gnupg
Type=tmpfs
Options=mode=0755
""")
    end

    # =====================================================
    # 3. Mask conflicting/problematic services from releng profile
    # =====================================================
    # systemd-networkd conflicts with NetworkManager - mask it
    # systemd-resolved conflicts with NetworkManager DNS handling - mask it
    # systemd-timesyncd fails on boot (no network yet) - mask for live ISO
    # systemd-sysusers: users created during build, polkitd added to passwd explicitly
    # systemd-vconsole-setup: fails in live ISO (no real console), keyboard set via X11/Wayland
    # rtkit-daemon: RealtimeKit fails without rtkit user, not critical for live ISO
    # pcscd: Smart card daemon not needed for live ISO
    services_to_mask = [
        "systemd-networkd.service",
        "systemd-networkd.socket",
        "systemd-networkd-wait-online.service",
        "systemd-resolved.service",   # NetworkManager handles DNS via /etc/resolv.conf
        "systemd-timesyncd.service",  # Fails without network, not critical for live ISO
        "systemd-sysusers.service",   # Users created during build + polkitd in passwd explicitly
        "systemd-vconsole-setup.service",  # Fails in live ISO, keyboard handled by X11/Wayland config
        "rtkit-daemon.service",       # RealtimeKit not needed for live ISO, fails without rtkit user
        "pcscd.socket",               # Smart card daemon not needed
        "pcscd.service",              # Smart card daemon not needed
    ]

    for service in services_to_mask
        mask_path = joinpath(systemd_dir, service)
        # Create symlink to /dev/null to mask the service
        # In airootfs overlay, we create a file that will be replaced by symlink
        rm(mask_path, force=true)
        symlink("/dev/null", mask_path)
    end

    # =====================================================
    # 3b. Remove any existing enablement symlinks in target.wants directories
    # =====================================================
    # The releng profile may have these services enabled via symlinks
    # We need to create empty .wants directories or remove specific symlinks
    sysinit_wants = joinpath(systemd_dir, "sysinit.target.wants")
    mkpath(sysinit_wants)

    # Remove any symlinks to services we want masked
    for service in services_to_mask
        link_in_sysinit = joinpath(sysinit_wants, service)
        rm(link_in_sysinit, force=true)
    end

    # Also handle sockets.target.wants
    sockets_wants = joinpath(systemd_dir, "sockets.target.wants")
    mkpath(sockets_wants)

    for service in services_to_mask
        link_in_sockets = joinpath(sockets_wants, service)
        rm(link_in_sockets, force=true)
    end

    # =====================================================
    # 4. Create multi-user.target.wants directory and symlinks
    # =====================================================
    multi_user_wants = joinpath(systemd_dir, "multi-user.target.wants")
    mkpath(multi_user_wants)

    # Services to enable - create actual symlinks
    services_to_enable = [
        "pacman-init.service" => "/etc/systemd/system/pacman-init.service",
        "NetworkManager.service" => "/usr/lib/systemd/system/NetworkManager.service",
        "sshd.service" => "/usr/lib/systemd/system/sshd.service",
        "ModemManager.service" => "/usr/lib/systemd/system/ModemManager.service",
    ]

    for (name, target) in services_to_enable
        link_path = joinpath(multi_user_wants, name)
        rm(link_path, force=true)
        symlink(target, link_path)
    end

    # =====================================================
    # 5. Create getty autologin for root on tty1
    # =====================================================
    getty_dir = joinpath(systemd_dir, "getty@tty1.service.d")
    mkpath(getty_dir)

    autologin_conf = joinpath(getty_dir, "autologin.conf")
    open(autologin_conf, "w") do f
        print(f, raw"""
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin root %I $TERM
""")
    end

    # =====================================================
    # 7. Create systemd preset for enabling/disabling services
    # =====================================================
    preset_dir = joinpath(airootfs_dir, "etc", "systemd", "system-preset")
    mkpath(preset_dir)

    preset_file = joinpath(preset_dir, "99-blunux.preset")
    open(preset_file, "w") do f
        print(f, raw"""
# Blunux Live ISO service preset
# Disable conflicting/unnecessary services for live ISO
disable systemd-networkd.service
disable systemd-networkd.socket
disable systemd-networkd-wait-online.service
disable systemd-resolved.service
disable systemd-timesyncd.service
disable systemd-sysusers.service
disable systemd-vconsole-setup.service
disable rtkit-daemon.service
disable pcscd.socket
disable pcscd.service
# Enable our services
enable pacman-init.service
enable NetworkManager.service
enable sshd.service
enable sddm.service
enable bluetooth.service
enable ModemManager.service
enable polkit.service
""")
    end

    # =====================================================
    # 8. Configure locale.conf with safe default
    # =====================================================
    etc_dir = joinpath(airootfs_dir, "etc")
    mkpath(etc_dir)

    locale_conf = joinpath(etc_dir, "locale.conf")
    open(locale_conf, "w") do f
        print(f, "LANG=C.UTF-8\n")
    end

    # =====================================================
    # 9. Create resolv.conf with default DNS servers
    # =====================================================
    # NetworkManager will manage this file (systemd-resolved is masked)
    # Note: releng profile may have resolv.conf as a symlink - remove it first
    resolv_conf = joinpath(etc_dir, "resolv.conf")
    rm(resolv_conf, force=true)
    open(resolv_conf, "w") do f
        print(f, "# DNS configuration - managed by NetworkManager\n")
        print(f, "# Default fallback DNS servers\n")
        print(f, "nameserver 8.8.8.8\n")
        print(f, "nameserver 8.8.4.4\n")
        print(f, "nameserver 1.1.1.1\n")
    end

    # =====================================================
    # 10. Configure polkit directories with proper permissions
    # =====================================================
    # polkit.service fails if these directories don't exist or have wrong permissions
    polkit_rules_dir = joinpath(airootfs_dir, "etc", "polkit-1", "rules.d")
    mkpath(polkit_rules_dir)

    # Create a basic polkit rule for live ISO (allow wheel group to do admin tasks)
    polkit_rule = joinpath(polkit_rules_dir, "49-blunux-live.rules")
    open(polkit_rule, "w") do f
        print(f, raw"""
/* Blunux Live ISO polkit rules */
/* Allow users in wheel group to perform admin tasks without password */
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
""")
    end

    # Create tmpfiles.d config for polkit state directory
    tmpfiles_dir = joinpath(airootfs_dir, "etc", "tmpfiles.d")
    mkpath(tmpfiles_dir)

    tmpfiles_polkit = joinpath(tmpfiles_dir, "polkit-blunux.conf")
    open(tmpfiles_polkit, "w") do f
        # Create /var/lib/polkit-1 owned by polkitd
        print(f, raw"""
# Polkit state directory for Blunux live ISO
d /var/lib/polkit-1 0700 polkitd polkitd -
""")
    end

    # =====================================================
    # 11. Add system users explicitly to passwd/group/shadow
    # =====================================================
    # These users are needed but sysusers is masked
    passwd_file = joinpath(etc_dir, "passwd")
    group_file = joinpath(etc_dir, "group")
    shadow_file = joinpath(etc_dir, "shadow")

    # Add polkitd user (UID 27 is standard for polkit)
    open(passwd_file, "a") do f
        println(f, "polkitd:x:27:27:PolicyKit daemon:/:/usr/bin/nologin")
    end

    open(group_file, "a") do f
        println(f, "polkitd:x:27:")
    end

    open(shadow_file, "a") do f
        println(f, "polkitd:!*:19000::::::")
    end

    # Add alpm user (UID 946 for pacman download user)
    # This is required for pacman's DownloadUser feature
    open(passwd_file, "a") do f
        println(f, "alpm:x:946:946:Arch Linux Package Management:/:/usr/bin/nologin")
    end

    open(group_file, "a") do f
        println(f, "alpm:x:946:")
    end

    open(shadow_file, "a") do f
        println(f, "alpm:!*:19000::::::")
    end

    # Create /var/lib/polkit-1 directory in airootfs
    polkit_var_dir = joinpath(airootfs_dir, "var", "lib", "polkit-1")
    mkpath(polkit_var_dir)

    println("    Configured systemd services (pacman-init, NetworkManager, etc.)")
end

"""
    configure_desktop_autologin(profile_dir, desktop)

Configure SDDM autologin for KDE Plasma 6 desktop in the live ISO.
Note: plasma-login-manager is CachyOS-specific; standard Arch uses SDDM.
Using Wayland session by default.
"""
function configure_desktop_autologin(profile_dir, desktop)
    airootfs_dir = joinpath(profile_dir, "airootfs")

    # Create live user configuration
    # Add live user to passwd
    passwd_dir = joinpath(airootfs_dir, "etc")
    mkpath(passwd_dir)

    # Create group file addition
    group_file = joinpath(passwd_dir, "group")
    open(group_file, "a") do f
        println(f, "live:x:1000:")
    end

    # Create passwd file addition
    passwd_file = joinpath(passwd_dir, "passwd")
    open(passwd_file, "a") do f
        println(f, "live:x:1000:1000:Live User:/home/live:/bin/bash")
    end

    # Create shadow file addition (empty password for live user)
    shadow_file = joinpath(passwd_dir, "shadow")
    open(shadow_file, "a") do f
        println(f, "live::19000:0:99999:7:::")
    end

    # Create live user home directory
    live_home = joinpath(airootfs_dir, "home", "live")
    mkpath(live_home)

    # Create .bashrc for live user
    bashrc = joinpath(live_home, ".bashrc")
    open(bashrc, "w") do f
        print(f, """
# Blunux Live User .bashrc
export PATH="\$HOME/.local/bin:\$PATH"
alias ll='ls -la'
alias update='sudo pacman -Syu'
""")
    end

    # =====================================================
    # Configure SDDM autologin (Wayland session by default)
    # =====================================================
    sddm_conf_dir = joinpath(airootfs_dir, "etc", "sddm.conf.d")
    mkpath(sddm_conf_dir)

    sddm_autologin = joinpath(sddm_conf_dir, "autologin.conf")
    open(sddm_autologin, "w") do f
        print(f, """
[Autologin]
User=live
Session=plasma
Relogin=false
""")
    end

    # Enable SDDM service
    systemd_dir = joinpath(airootfs_dir, "etc", "systemd", "system")
    mkpath(systemd_dir)

    # Create display-manager.service symlink to SDDM
    dm_service = joinpath(systemd_dir, "display-manager.service")
    rm(dm_service, force=true)
    symlink("/usr/lib/systemd/system/sddm.service", dm_service)

    # Create profile.d script directory
    setup_dir = joinpath(airootfs_dir, "etc", "profile.d")
    mkpath(setup_dir)

    # Add live user to necessary groups via a systemd service
    # This service runs at multi-user.target (after basic system is up)
    # to ensure all groups exist before adding the user to them
    live_groups_service = joinpath(systemd_dir, "blunux-live-groups.service")
    open(live_groups_service, "w") do f
        print(f, raw"""
[Unit]
Description=Add live user to system groups
After=systemd-user-sessions.service
Before=display-manager.service getty@tty1.service

[Service]
Type=oneshot
RemainAfterExit=yes
# Add live user to common groups for desktop functionality
# Using -a (append) and -G (groups) flags
# Ignore errors if groups don't exist (|| true)
ExecStart=/bin/sh -c '/usr/bin/usermod -aG wheel,video,audio,storage,optical,network,power,input,lp,scanner live 2>/dev/null || true'

[Install]
WantedBy=multi-user.target
""")
    end

    # Enable the service via multi-user.target.wants
    multi_user_wants_dir = joinpath(systemd_dir, "multi-user.target.wants")
    mkpath(multi_user_wants_dir)
    live_groups_link = joinpath(multi_user_wants_dir, "blunux-live-groups.service")
    rm(live_groups_link, force=true)
    symlink("/etc/systemd/system/blunux-live-groups.service", live_groups_link)

    # Create sudoers entry for live user
    sudoers_dir = joinpath(airootfs_dir, "etc", "sudoers.d")
    mkpath(sudoers_dir)

    sudoers_live = joinpath(sudoers_dir, "live")
    open(sudoers_live, "w") do f
        println(f, "live ALL=(ALL) NOPASSWD: ALL")
    end

    # Create systemd preset to enable SDDM
    preset_dir = joinpath(airootfs_dir, "etc", "systemd", "system-preset")
    mkpath(preset_dir)

    preset_file = joinpath(preset_dir, "90-blunux.preset")
    open(preset_file, "w") do f
        println(f, "enable sddm.service")
        println(f, "enable NetworkManager.service")
        println(f, "enable bluetooth.service")
    end

    # Create symlink for display-manager -> sddm
    dm_service_dir = joinpath(systemd_dir, "graphical.target.wants")
    mkpath(dm_service_dir)

    # Write a hook script to set up symlinks during image build
    hooks_dir = joinpath(airootfs_dir, "etc", "pacman.d", "hooks")
    mkpath(hooks_dir)

    println("    Configured SDDM autologin for live user")
end

"""
    configure_packages(profile_dir, packages::CollectedPackages)

Configure packages in the archiso profile.
"""
function configure_packages(profile_dir, packages::CollectedPackages)
    packages_file = joinpath(profile_dir, "packages.x86_64")

    # Read existing packages from releng profile
    existing_pkgs = String[]
    if isfile(packages_file)
        existing_pkgs = filter(!isempty, strip.(readlines(packages_file)))
        # Remove comments
        existing_pkgs = filter(p -> !startswith(p, "#"), existing_pkgs)
    end

    # =====================================================
    # Remove conflicting/unwanted packages from releng profile
    # =====================================================
    # These packages conflict with our preferred alternatives or are unwanted
    packages_to_remove = [
        "virtualbox-guest-utils-nox",  # Conflicts with virtualbox-guest-utils (we want X11 support)
        "kmix",                         # Unwanted KDE audio mixer (pipewire/plasma-pa is preferred)
    ]

    existing_pkgs = filter(p -> !(p in packages_to_remove), existing_pkgs)

    if !isempty(packages_to_remove)
        println("    Removed conflicting packages: $(join(packages_to_remove, ", "))")
    end

    # Combine with new packages
    all_pkgs = unique(vcat(existing_pkgs, packages.pacman))

    # Write packages file
    open(packages_file, "w") do f
        println(f, "# Blunux packages - auto-generated")
        println(f, "# Generated: $(Dates.now())")
        println(f, "")
        for pkg in sort(all_pkgs)
            println(f, pkg)
        end
    end

    println("    Written $(length(all_pkgs)) packages to packages.x86_64")

    # Handle AUR packages - create a script to install them in the live environment
    if !isempty(packages.aur)
        configure_aur_packages(profile_dir, packages.aur)
    end
end

"""
    configure_aur_packages(profile_dir, aur_packages)

Configure AUR packages to be installed during first boot.
"""
function configure_aur_packages(profile_dir, aur_packages)
    airootfs_dir = joinpath(profile_dir, "airootfs")
    scripts_dir = joinpath(airootfs_dir, "root", "blunux-setup")
    mkpath(scripts_dir)

    # Create AUR packages list
    aur_list_file = joinpath(scripts_dir, "aur-packages.txt")
    open(aur_list_file, "w") do f
        for pkg in aur_packages
            println(f, pkg)
        end
    end

    # Create AUR install script
    aur_script = joinpath(scripts_dir, "install-aur.sh")
    open(aur_script, "w") do f
        print(f, """
#!/bin/bash
# Blunux AUR Package Installer
# This script installs AUR packages using yay

set -e

AUR_PACKAGES_FILE="/root/blunux-setup/aur-packages.txt"

if [ ! -f "\$AUR_PACKAGES_FILE" ]; then
    echo "No AUR packages file found."
    exit 0
fi

# Sync pacman database first
echo "Synchronizing package database..."
pacman -Sy --noconfirm

# Check if running as root
if [ "\$(id -u)" -eq 0 ]; then
    echo "Creating temporary build user for AUR..."
    useradd -m -G wheel builduser 2>/dev/null || true
    echo "builduser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builduser

    # Install yay if not present
    if ! command -v yay &> /dev/null; then
        echo "Installing yay..."
        pacman -S --needed --noconfirm git base-devel
        su - builduser -c "
            cd /tmp
            git clone https://aur.archlinux.org/yay-bin.git
            cd yay-bin
            makepkg -si --noconfirm
        "
    fi

    # Install AUR packages
    while IFS= read -r package || [ -n "\$package" ]; do
        if [ -n "\$package" ]; then
            echo "Installing AUR package: \$package"
            su - builduser -c "yay -S --noconfirm \$package" || echo "Failed to install \$package"
        fi
    done < "\$AUR_PACKAGES_FILE"

    # Cleanup
    userdel -r builduser 2>/dev/null || true
    rm -f /etc/sudoers.d/builduser
else
    # Running as regular user
    while IFS= read -r package || [ -n "\$package" ]; do
        if [ -n "\$package" ]; then
            echo "Installing AUR package: \$package"
            yay -S --noconfirm "\$package" || echo "Failed to install \$package"
        fi
    done < "\$AUR_PACKAGES_FILE"
fi

echo "AUR packages installation complete."
""")
    end

    chmod(aur_script, 0o755)
    println("    Created AUR install script with $(length(aur_packages)) packages")
end

"""
    create_customize_script(profile_dir, config)

Create customization scripts for the live environment.
"""
function create_customize_script(profile_dir, config)
    airootfs_dir = joinpath(profile_dir, "airootfs")
    scripts_dir = joinpath(airootfs_dir, "root", "blunux-setup")
    mkpath(scripts_dir)

    # Create main setup script
    setup_script = joinpath(scripts_dir, "setup.sh")
    build_name = config["blunux"]["name"]

    open(setup_script, "w") do f
        print(f, """
#!/bin/bash
# Blunux Setup Script
# Build: $build_name

set -e

echo "======================================"
echo "  Blunux Setup - $build_name"
echo "======================================"

# Run locale setup
if [ -f /root/blunux-setup/setup-locale.sh ]; then
    bash /root/blunux-setup/setup-locale.sh
fi

# Run input method setup
if [ -f /root/blunux-setup/setup-input-method.sh ]; then
    bash /root/blunux-setup/setup-input-method.sh
fi

# Install AUR packages
if [ -f /root/blunux-setup/install-aur.sh ]; then
    bash /root/blunux-setup/install-aur.sh
fi

echo "Blunux setup complete!"
""")
    end

    chmod(setup_script, 0o755)

    # Add to systemd for first boot
    systemd_dir = joinpath(airootfs_dir, "etc", "systemd", "system")
    mkpath(systemd_dir)

    service_file = joinpath(systemd_dir, "blunux-setup.service")
    open(service_file, "w") do f
        print(f, """
[Unit]
Description=Blunux First Boot Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=/root/blunux-setup/setup.sh

[Service]
Type=oneshot
ExecStart=/bin/bash /root/blunux-setup/setup.sh
ExecStartPost=/bin/rm -rf /root/blunux-setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
""")
    end

    # Enable service
    wants_dir = joinpath(systemd_dir, "multi-user.target.wants")
    mkpath(wants_dir)

    # Create symlink command to be run during build
    symlink_script = joinpath(profile_dir, "airootfs", "root", ".automated_script.sh")
    mkpath(dirname(symlink_script))

    # Add to existing script or create new one
    script_content = ""
    if isfile(symlink_script)
        script_content = read(symlink_script, String)
    else
        script_content = "#!/bin/bash\n"
    end

    if !occursin("blunux-setup.service", script_content)
        script_content *= "\n# Enable Blunux setup service\nln -sf /etc/systemd/system/blunux-setup.service /etc/systemd/system/multi-user.target.wants/blunux-setup.service\n"
        open(symlink_script, "w") do f
            print(f, script_content)
        end
        chmod(symlink_script, 0o755)
    end

    println("    Created setup scripts and systemd service")
end

"""
    configure_install_icon(profile_dir)

Create a desktop icon for easy system installation.
Note: The actual blunux-install script is created by update_install_script_for_installer()
in installer_build.jl with comprehensive setup steps.
"""
function configure_install_icon(profile_dir)
    airootfs_dir = joinpath(profile_dir, "airootfs")

    # Create Desktop directory for live user
    desktop_dir = joinpath(airootfs_dir, "home", "live", "Desktop")
    mkpath(desktop_dir)

    # Create the scripts directory (script itself created by installer_build.jl)
    scripts_dir = joinpath(airootfs_dir, "usr", "local", "bin")
    mkpath(scripts_dir)

    # Create the desktop entry file
    desktop_file = joinpath(desktop_dir, "install-blunux.desktop")
    open(desktop_file, "w") do f
        print(f, """
[Desktop Entry]
Version=1.0
Type=Application
Name=Install Blunux
Name[ko]=Blunux 설치
Name[sv]=Installera Blunux
GenericName=System Installer
GenericName[ko]=시스템 설치 프로그램
Comment=Install Blunux to your computer
Comment[ko]=컴퓨터에 Blunux를 설치합니다
Comment[sv]=Installera Blunux pa din dator
Exec=konsole -e bash /usr/local/bin/blunux-install
Icon=system-software-install
Terminal=false
Categories=System;
Keywords=install;installer;system;setup;
""")
    end
    chmod(desktop_file, 0o755)

    # Also create in /usr/share/applications for menu access
    apps_dir = joinpath(airootfs_dir, "usr", "share", "applications")
    mkpath(apps_dir)
    cp(desktop_file, joinpath(apps_dir, "install-blunux.desktop"), force=true)

    println("    Created install icon on desktop")
end

"""
    configure_fastfetch(profile_dir, build_name="blunux")

Configure fastfetch with custom Blunux penguin logo and customize os-release.
"""
function configure_fastfetch(profile_dir, build_name::String="blunux")
    airootfs_dir = joinpath(profile_dir, "airootfs")

    # =====================================================
    # 1. Create custom /etc/os-release for Blunux branding
    # =====================================================
    # This makes fastfetch show "blunux-XXXXXX" instead of "Arch Linux"
    etc_dir = joinpath(airootfs_dir, "etc")
    mkpath(etc_dir)

    os_release_file = joinpath(etc_dir, "os-release")
    open(os_release_file, "w") do f
        print(f, """
NAME="$build_name"
PRETTY_NAME="$build_name"
ID=blunux
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://bugs.archlinux.org/"
LOGO=archlinux-logo
""")
    end

    # Also create symlink /usr/lib/os-release -> /etc/os-release (standard location)
    usr_lib_dir = joinpath(airootfs_dir, "usr", "lib")
    mkpath(usr_lib_dir)

    # Create fastfetch config directory for live user
    fastfetch_config_dir = joinpath(airootfs_dir, "home", "live", ".config", "fastfetch")
    mkpath(fastfetch_config_dir)

    # Create the custom Blunux ASCII logo file (Arch-style with ANSI colors)
    logo_file = joinpath(fastfetch_config_dir, "blunux-logo.txt")
    open(logo_file, "w") do f
        # Use actual escape characters for ANSI colors
        # \e[1;34m = bold blue, \e[1;37m = bold white, \e[0m = reset
        esc = "\e"
        blue = "$(esc)[1;34m"
        white = "$(esc)[1;37m"
        reset = "$(esc)[0m"
        print(f, """               $(blue).88888888$(white):.$(reset)
              $(blue)88888888$(reset).$(blue)88888$(reset).
            $(blue)888888888888888888$(reset)
            $(blue)88$(reset)' _\`$(blue)88$(reset)'_  \`$(blue)88888$(reset)
            $(blue)88 88 88 88  88888$(reset)
            $(blue)88$(reset)_$(blue)88$(reset)_$(white)::$(reset)_$(blue)88$(reset)_$(white):$(blue)88888$(reset)
            $(blue)88$(white):::,::,:::::$(blue)8888$(reset)
            $(blue)88$(reset)\`$(white)::::::::'$(reset)\`$(blue)8888$(reset)
           .$(blue)88$(reset)  \`$(white)::::'$(reset)    $(blue)8$(white):$(blue)88$(reset).
          $(blue)8888$(reset)            \`$(blue)8$(white):$(blue)888$(reset).
        .$(blue)8888$(reset)'             \`$(blue)888888$(reset).
       .$(blue)8888$(white):..  .::.  ...:$(reset)'$(blue)8888888$(white):.$(reset)
      .$(blue)8888$(reset).'     $(white):'$(reset)     \`'$(white)::$(reset)\`$(blue)88$(white):$(blue)88888$(reset)
     .$(blue)8888$(reset)         '          \`.$(blue)888$(white):$(blue)8888$(reset).
    $(blue)888$(white):$(blue)8$(reset)          .           $(blue)888$(white):$(blue)88888$(reset)
  $(blue)8888888$(reset).        $(white)::$(reset)           $(blue)88$(white):$(blue)888888$(reset)
  \`.$(white)::$(reset).$(blue)888$(reset).       $(white)::$(reset)          .$(blue)88888888$(reset)
 .$(white)::::::$(reset).$(blue)888$(reset).     $(white)::$(reset)          $(white):::$(reset)\`$(blue)8888$(reset)'.$(white):.$(reset)
 $(white)::::::::::$(reset).$(blue)888$(reset)    '          .$(white)::::::::::::$(reset)
 $(white)::::::::::::$(reset).$(blue)8$(reset)    '        .$(white):8:::::::::::::.$(reset)
.$(white):::::::::::::::.$(reset)         .$(white):888:::::::::::::$(reset)
 $(white):::::::::::::::88$(reset):.__..:$(white)88888:::::::::::'$(reset)
  \`'.$(white):::::::::::88888888888.88::::::::'$(reset)
        \`'$(white):::_:'$(reset) -- '' -'-' \`'$(white):_::::'$(reset)
""")
    end

    # Create fastfetch configuration
    config_file = joinpath(fastfetch_config_dir, "config.jsonc")
    open(config_file, "w") do f
        print(f, """
{
    "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "source": "~/.config/fastfetch/blunux-logo.txt",
        "type": "raw",
        "width": 42,
        "padding": {
            "top": 0,
            "left": 0,
            "right": 2
        }
    },
    "display": {
        "separator": " -> ",
        "color": {
            "keys": "blue",
            "title": "white"
        }
    },
    "modules": [
        "title",
        "separator",
        "os",
        "host",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "display",
        "de",
        "wm",
        "wmtheme",
        "theme",
        "icons",
        "font",
        "cursor",
        "terminal",
        "cpu",
        "gpu",
        "memory",
        "swap",
        "disk",
        "localip",
        "battery",
        "locale",
        "break",
        "colors"
    ]
}
""")
    end

    # Also create global config in /etc for all users
    etc_fastfetch_dir = joinpath(airootfs_dir, "etc", "fastfetch")
    mkpath(etc_fastfetch_dir)
    cp(logo_file, joinpath(etc_fastfetch_dir, "blunux-logo.txt"), force=true)
    cp(config_file, joinpath(etc_fastfetch_dir, "config.jsonc"), force=true)

    println("    Configured fastfetch with Blunux logo and os-release ($build_name)")
end

"""
    configure_boot_menu(profile_dir)

Configure GRUB and syslinux boot menu with only two options:
1. Blunux Live - Boot into live desktop environment
2. Blunux Install - Boot into installation mode (text mode)

This function completely replaces all bootloader configurations from archiso releng.
"""
function configure_boot_menu(profile_dir)
    # =====================================================
    # GRUB Configuration (BIOS and UEFI)
    # =====================================================
    grub_dir = joinpath(profile_dir, "grub")
    if isdir(grub_dir)
        # Completely rewrite grub.cfg
        grub_cfg = joinpath(grub_dir, "grub.cfg")
        open(grub_cfg, "w") do f
            print(f, raw"""
# Blunux GRUB Configuration
# Only two boot options: Live and Install

insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660
insmod ntfs
insmod exfat
insmod udf
insmod all_video
insmod font

set default="blunux-live"
set timeout=10
set gfxmode=auto
set gfxpayload=keep

insmod gfxterm
terminal_output gfxterm

if loadfont "${prefix}/fonts/unicode.pf2" ; then
    set gfxterm_font=unicode
fi

set color_normal=white/black
set color_highlight=cyan/black
set menu_color_normal=white/black
set menu_color_highlight=cyan/black

menuentry "Blunux Live" --class arch --class gnu-linux --class os --id 'blunux-live' {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=10G
    initrd /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
}

menuentry "Blunux Install (Text Mode)" --class arch --class gnu-linux --class os --id 'blunux-install' {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=10G systemd.unit=multi-user.target
    initrd /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
}

menuentry "Reboot" --class reboot --id 'reboot' {
    reboot
}

menuentry "Power Off" --class shutdown --id 'poweroff' {
    halt
}
""")
        end
        println("    Configured GRUB grub.cfg")

        # Create loopback.cfg for booting from ISO file
        loopback_cfg = joinpath(grub_dir, "loopback.cfg")
        open(loopback_cfg, "w") do f
            print(f, raw"""
# Blunux GRUB Loopback Configuration
# For booting ISO from another bootloader (e.g., Ventoy)

menuentry "Blunux Live" --class arch --class gnu-linux --class os {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% img_dev=$imgdevpath img_loop=$isofile cow_spacesize=10G
    initrd /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
}

menuentry "Blunux Install (Text Mode)" --class arch --class gnu-linux --class os {
    set gfxpayload=keep
    linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% img_dev=$imgdevpath img_loop=$isofile cow_spacesize=10G systemd.unit=multi-user.target
    initrd /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
}
""")
        end
        println("    Configured GRUB loopback.cfg")
    end

    # =====================================================
    # Syslinux Configuration (BIOS)
    # =====================================================
    syslinux_dir = joinpath(profile_dir, "syslinux")
    if isdir(syslinux_dir)
        # Remove all existing archiso syslinux config files
        for f in readdir(syslinux_dir)
            if startswith(f, "archiso_") && endswith(f, ".cfg")
                rm(joinpath(syslinux_dir, f), force=true)
            end
        end

        # Create single syslinux config
        syslinux_cfg = joinpath(syslinux_dir, "syslinux.cfg")
        open(syslinux_cfg, "w") do f
            print(f, raw"""
# Blunux Syslinux Configuration

DEFAULT blunux-live
PROMPT 1
TIMEOUT 100

UI vesamenu.c32

MENU TITLE Blunux Boot Menu
MENU RESOLUTION 1024 768
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR hotsel       1;7;37;40 #e0ffffff #20ffffff all
MENU COLOR hotkey       37;44   #90ffff00 #a0000000 std

LABEL blunux-live
    TEXT HELP
    Boot Blunux Live environment with full desktop
    ENDTEXT
    MENU LABEL Blunux Live
    LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
    INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
    APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=10G

LABEL blunux-install
    TEXT HELP
    Boot into text mode for system installation
    ENDTEXT
    MENU LABEL Blunux Install (Text Mode)
    LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
    INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
    APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=10G systemd.unit=multi-user.target

LABEL reboot
    MENU LABEL Reboot
    COM32 reboot.c32

LABEL poweroff
    MENU LABEL Power Off
    COM32 poweroff.c32
""")
        end
        println("    Configured syslinux boot menu")
    end

    # =====================================================
    # systemd-boot Configuration (UEFI)
    # =====================================================
    efiboot_dir = joinpath(profile_dir, "efiboot")
    loader_dir = joinpath(efiboot_dir, "loader")

    if isdir(efiboot_dir)
        # Create loader directory if not exists
        mkpath(loader_dir)
        entries_dir = joinpath(loader_dir, "entries")
        mkpath(entries_dir)

        # Remove all existing entries
        if isdir(entries_dir)
            for f in readdir(entries_dir)
                if endswith(f, ".conf")
                    rm(joinpath(entries_dir, f), force=true)
                end
            end
        end

        # Loader config
        loader_conf = joinpath(loader_dir, "loader.conf")
        open(loader_conf, "w") do f
            print(f, raw"""
default blunux-live.conf
timeout 10
console-mode auto
editor no
""")
        end

        # Live entry
        live_entry = joinpath(entries_dir, "blunux-live.conf")
        open(live_entry, "w") do f
            print(f, raw"""
title   Blunux Live
linux   /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
initrd  /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
options archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=10G
""")
        end

        # Install entry
        install_entry = joinpath(entries_dir, "blunux-install.conf")
        open(install_entry, "w") do f
            print(f, raw"""
title   Blunux Install (Text Mode)
linux   /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
initrd  /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
options archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% cow_spacesize=10G systemd.unit=multi-user.target
""")
        end
        println("    Configured systemd-boot entries (UEFI)")
    end

    # Create install mode welcome script
    configure_install_mode_welcome(profile_dir)
end

"""
    configure_install_mode_welcome(profile_dir)

Configure welcome message and auto-prompt for archinstall in text mode.
"""
function configure_install_mode_welcome(profile_dir)
    airootfs_dir = joinpath(profile_dir, "airootfs")

    # Create a script that shows welcome message in text mode
    profile_d_dir = joinpath(airootfs_dir, "etc", "profile.d")
    mkpath(profile_d_dir)

    welcome_script = joinpath(profile_d_dir, "blunux-install-welcome.sh")
    open(welcome_script, "w") do f
        print(f, raw"""
#!/bin/bash
# Blunux Install Mode Welcome Script

# Only run in multi-user.target (text mode)
if systemctl is-active graphical.target &>/dev/null; then
    return 0
fi

# Only run once per session
if [ -f /tmp/.blunux-welcome-shown ]; then
    return 0
fi
touch /tmp/.blunux-welcome-shown

clear
echo ""
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║                                                               ║"
echo "  ║   ██████╗ ██╗     ██╗   ██╗███╗   ██╗██╗   ██╗██╗  ██╗        ║"
echo "  ║   ██╔══██╗██║     ██║   ██║████╗  ██║██║   ██║╚██╗██╔╝        ║"
echo "  ║   ██████╔╝██║     ██║   ██║██╔██╗ ██║██║   ██║ ╚███╔╝         ║"
echo "  ║   ██╔══██╗██║     ██║   ██║██║╚██╗██║██║   ██║ ██╔██╗         ║"
echo "  ║   ██████╔╝███████╗╚██████╔╝██║ ╚████║╚██████╔╝██╔╝ ██╗        ║"
echo "  ║   ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝        ║"
echo "  ║                                                               ║"
echo "  ║                   Installation Mode                           ║"
echo "  ║                                                               ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Welcome to Blunux Installation Mode!"
echo ""
echo "  To install Blunux to your system, run:"
echo ""
echo "      blunux-install"
echo ""
echo "  (This will prepare the system and launch the installer)"
echo ""
echo "  Network: Use 'nmtui' to configure WiFi first if needed"
echo "  Disks:   Use 'lsblk' to list drives, 'cfdisk' to partition"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""
""")
    end
    chmod(welcome_script, 0o755)

    println("    Created install mode welcome script")
end

"""
    build_archiso(profile_dir, output_dir, build_name)

Build the ISO using mkarchiso.
Returns the path to the generated ISO file.

The ISO filename follows the format: blunux-XXXXXX-language-yyyy.mm.dd-x86_64.iso
Where XXXXXX is the build ID (2-digit checksum + 4-digit time in hex).
"""
function build_archiso(profile_dir, output_dir, build_name)
    mkpath(output_dir)

    work_dir = joinpath(dirname(profile_dir), "archiso-work")

    # Clean previous work directory
    if isdir(work_dir)
        println("    Cleaning previous build artifacts...")
        rm(work_dir, recursive=true)
    end

    println("    Running mkarchiso (this may take a while)...")
    println("    Profile: $profile_dir")
    println("    Output: $output_dir")

    # Build ISO
    cmd = `mkarchiso -v -w $work_dir -o $output_dir $profile_dir`

    try
        run(cmd)
    catch e
        error("mkarchiso failed: $e")
    end

    # Find generated ISO
    iso_files = filter(f -> endswith(f, ".iso"), readdir(output_dir))
    if isempty(iso_files)
        error("No ISO file generated in $output_dir")
    end

    iso_path = joinpath(output_dir, iso_files[end])  # Get the latest one
    iso_filename = basename(iso_path)
    println("    ISO generated: $iso_path")

    # Print ISO info
    iso_size = filesize(iso_path) / (1024 * 1024 * 1024)
    println("    ISO size: $(round(iso_size, digits=2)) GB")

    # Try to extract and display build info
    try
        info = verify_iso_filename(iso_filename)
        println("    ─────────────────────────────────")
        println("    Build ID:   $(info.build_id)")
        time_str = lpad(string(info.parsed_id.hour), 2, '0') * ":" *
                   lpad(string(info.parsed_id.minute), 2, '0')
        println("    Build Time: $(time_str)")
        println("    Checksum:   $(info.parsed_id.checksum) ($(info.valid ? "valid" : "INVALID"))")
    catch
        # Filename doesn't match new format, skip
    end

    return iso_path
end
