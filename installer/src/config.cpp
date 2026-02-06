#include "config.hpp"
#include <toml.hpp>
#include <fstream>
#include <iostream>

namespace blunux {

Config Config::load(const std::string& path) {
    Config cfg;

    try {
        auto data = toml::parse_file(path);

        // [blunux] section
        if (auto blunux = data["blunux"].as_table()) {
            if (auto v = (*blunux)["version"].value<std::string>())
                cfg.blunux.version = *v;
            if (auto v = (*blunux)["name"].value<std::string>())
                cfg.blunux.name = *v;
        }

        // [locale] section
        if (auto locale = data["locale"].as_table()) {
            // Handle language as either string or array
            if (auto arr = (*locale)["language"].as_array()) {
                cfg.locale.languages.clear();
                for (const auto& item : *arr) {
                    if (auto v = item.value<std::string>())
                        cfg.locale.languages.push_back(*v);
                }
            } else if (auto v = (*locale)["language"].value<std::string>()) {
                cfg.locale.languages.clear();
                cfg.locale.languages.push_back(*v);
            }
            if (auto v = (*locale)["timezone"].value<std::string>())
                cfg.locale.timezone = *v;
            if (auto arr = (*locale)["keyboard"].as_array()) {
                cfg.locale.keyboards.clear();
                for (const auto& item : *arr) {
                    if (auto v = item.value<std::string>())
                        cfg.locale.keyboards.push_back(*v);
                }
            }
        }

        // [input_method] section
        if (auto im = data["input_method"].as_table()) {
            if (auto v = (*im)["enabled"].value<bool>())
                cfg.input_method.enabled = *v;
            if (auto v = (*im)["engine"].value<std::string>())
                cfg.input_method.engine = *v;
        }

        // [kernel] section
        if (auto kernel = data["kernel"].as_table()) {
            if (auto v = (*kernel)["type"].value<std::string>())
                cfg.kernel.type = *v;
        }

        // [packages.desktop] section
        if (auto desktop = data["packages"]["desktop"].as_table()) {
            if (auto v = (*desktop)["kde"].value<bool>())
                cfg.packages.kde = *v;
        }

        // [packages.browser] section
        if (auto browser = data["packages"]["browser"].as_table()) {
            if (auto v = (*browser)["firefox"].value<bool>())
                cfg.packages.firefox = *v;
            if (auto v = (*browser)["whale"].value<bool>())
                cfg.packages.whale = *v;
            if (auto v = (*browser)["chrome"].value<bool>())
                cfg.packages.chrome = *v;
            if (auto v = (*browser)["mullvad"].value<bool>())
                cfg.packages.mullvad = *v;
        }

        // [packages.office] section
        if (auto office = data["packages"]["office"].as_table()) {
            if (auto v = (*office)["libreoffice"].value<bool>())
                cfg.packages.libreoffice = *v;
            if (auto v = (*office)["hoffice"].value<bool>())
                cfg.packages.hoffice = *v;
            if (auto v = (*office)["texlive"].value<bool>())
                cfg.packages.texlive = *v;
        }

        // [packages.development] section
        if (auto dev = data["packages"]["development"].as_table()) {
            if (auto v = (*dev)["vscode"].value<bool>())
                cfg.packages.vscode = *v;
            if (auto v = (*dev)["sublime"].value<bool>())
                cfg.packages.sublime = *v;
            if (auto v = (*dev)["git"].value<bool>())
                cfg.packages.git = *v;
            if (auto v = (*dev)["rust"].value<bool>())
                cfg.packages.rust = *v;
            if (auto v = (*dev)["julia"].value<bool>())
                cfg.packages.julia = *v;
            if (auto v = (*dev)["nodejs"].value<bool>())
                cfg.packages.nodejs = *v;
            if (auto v = (*dev)["github_cli"].value<bool>())
                cfg.packages.github_cli = *v;
        }

        // [packages.multimedia] section
        if (auto media = data["packages"]["multimedia"].as_table()) {
            if (auto v = (*media)["vlc"].value<bool>())
                cfg.packages.vlc = *v;
            if (auto v = (*media)["obs"].value<bool>())
                cfg.packages.obs = *v;
            if (auto v = (*media)["freetv"].value<bool>())
                cfg.packages.freetv = *v;
            if (auto v = (*media)["ytdlp"].value<bool>())
                cfg.packages.ytdlp = *v;
            if (auto v = (*media)["freetube"].value<bool>())
                cfg.packages.freetube = *v;
        }

        // [packages.gaming] section
        if (auto gaming = data["packages"]["gaming"].as_table()) {
            if (auto v = (*gaming)["steam"].value<bool>())
                cfg.packages.steam = *v;
            if (auto v = (*gaming)["unciv"].value<bool>())
                cfg.packages.unciv = *v;
            if (auto v = (*gaming)["snes9x"].value<bool>())
                cfg.packages.snes9x = *v;
        }

        // [packages.virtualization] section
        if (auto virt = data["packages"]["virtualization"].as_table()) {
            if (auto v = (*virt)["virtualbox"].value<bool>())
                cfg.packages.virtualbox = *v;
            if (auto v = (*virt)["docker"].value<bool>())
                cfg.packages.docker = *v;
        }

        // [packages.communication] section
        if (auto comm = data["packages"]["communication"].as_table()) {
            if (auto v = (*comm)["teams"].value<bool>())
                cfg.packages.teams = *v;
            if (auto v = (*comm)["whatsapp"].value<bool>())
                cfg.packages.whatsapp = *v;
            if (auto v = (*comm)["onenote"].value<bool>())
                cfg.packages.onenote = *v;
        }

        // [packages.utility] section
        if (auto util = data["packages"]["utility"].as_table()) {
            if (auto v = (*util)["bluetooth"].value<bool>())
                cfg.packages.bluetooth = *v;
            if (auto v = (*util)["conky"].value<bool>())
                cfg.packages.conky = *v;
            if (auto v = (*util)["vnc"].value<bool>())
                cfg.packages.vnc = *v;
            if (auto v = (*util)["samba"].value<bool>())
                cfg.packages.samba = *v;
        }

        // [install] section (optional, for pre-configured installations)
        if (auto install = data["install"].as_table()) {
            if (auto v = (*install)["hostname"].value<std::string>())
                cfg.install.hostname = *v;
            if (auto v = (*install)["username"].value<std::string>())
                cfg.install.username = *v;
            if (auto v = (*install)["root_password"].value<std::string>())
                cfg.install.root_password = *v;
            if (auto v = (*install)["user_password"].value<std::string>())
                cfg.install.user_password = *v;
            if (auto v = (*install)["bootloader"].value<std::string>())
                cfg.install.bootloader = *v;
            if (auto v = (*install)["encryption"].value<bool>())
                cfg.install.use_encryption = *v;
            if (auto v = (*install)["autologin"].value<bool>())
                cfg.install.autologin = *v;
        }

    } catch (const toml::parse_error& err) {
        std::cerr << "Error parsing config file: " << err << std::endl;
        throw;
    }

    return cfg;
}

std::vector<std::string> Config::get_package_list() const {
    // Optional packages are now installed via individual scripts after first boot
    // See get_script_package_list() and ~/install-packages.sh
    return {};
}

std::vector<std::string> Config::get_aur_package_list() const {
    // AUR packages are now installed via individual scripts after first boot
    // See get_script_package_list() and ~/install-packages.sh
    return {};
}

std::vector<std::string> Config::get_script_package_list() const {
    std::vector<std::string> scripts;

    // Browsers
    if (this->packages.firefox) scripts.push_back("firefox");
    if (this->packages.whale) scripts.push_back("whale");
    if (this->packages.chrome) scripts.push_back("chrome");
    if (this->packages.mullvad) scripts.push_back("mullvad");

    // Office
    if (this->packages.libreoffice) scripts.push_back("libreoffice");
    if (this->packages.hoffice) scripts.push_back("hoffice");
    if (this->packages.texlive) scripts.push_back("texlive");

    // Development
    if (this->packages.vscode) scripts.push_back("vscode");
    if (this->packages.sublime) scripts.push_back("sublime");
    if (this->packages.rust) scripts.push_back("rust");
    if (this->packages.julia) scripts.push_back("julia");
    if (this->packages.nodejs) scripts.push_back("nodejs");
    if (this->packages.github_cli) scripts.push_back("github_cli");

    // Multimedia
    if (this->packages.obs) scripts.push_back("obs");
    if (this->packages.vlc) scripts.push_back("vlc");
    if (this->packages.freetv) scripts.push_back("freetv");
    if (this->packages.ytdlp) scripts.push_back("ytdlp");
    if (this->packages.freetube) scripts.push_back("freetube");

    // Gaming
    if (this->packages.steam) scripts.push_back("steam");
    if (this->packages.unciv) scripts.push_back("unciv");
    if (this->packages.snes9x) scripts.push_back("snes9x");

    // Virtualization
    if (this->packages.virtualbox) scripts.push_back("virtualbox");
    if (this->packages.docker) scripts.push_back("docker");

    // Communication
    if (this->packages.teams) scripts.push_back("teams");
    if (this->packages.whatsapp) scripts.push_back("whatsapp");
    if (this->packages.onenote) scripts.push_back("onenote");

    // Utility
    if (this->packages.conky) scripts.push_back("conky");
    if (this->packages.vnc) scripts.push_back("vnc");
    if (this->packages.samba) scripts.push_back("samba");
    if (this->packages.bluetooth) scripts.push_back("bluetooth");

    return scripts;
}

}  // namespace blunux
