use serde::Deserialize;
use std::fs;
use std::path::Path;

/// Swap configuration mode from [disk] section
#[derive(Debug, Clone, PartialEq)]
pub enum SwapMode {
    None,    // No swap
    Small,   // RAM * 0.5
    Suspend, // RAM * 1.0 (for hibernation)
    File,    // Swap file with reasonable default size
}

impl SwapMode {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "none" => SwapMode::None,
            "small" => SwapMode::Small,
            "suspend" => SwapMode::Suspend,
            "file" => SwapMode::File,
            _ => SwapMode::Suspend, // default
        }
    }

    pub fn label(&self) -> &str {
        match self {
            SwapMode::None => "none",
            SwapMode::Small => "small (RAM/2)",
            SwapMode::Suspend => "suspend (RAM size)",
            SwapMode::File => "file",
        }
    }
}

#[derive(Debug, Clone)]
pub struct BlunuxConfig {
    pub version: String,
    pub name: String,
}

impl Default for BlunuxConfig {
    fn default() -> Self {
        Self {
            version: "1.0".to_string(),
            name: "blunux".to_string(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct LocaleConfig {
    pub languages: Vec<String>,
    pub timezone: String,
    pub keyboards: Vec<String>,
}

impl Default for LocaleConfig {
    fn default() -> Self {
        Self {
            languages: vec!["ko_KR".to_string()],
            timezone: "Asia/Seoul".to_string(),
            keyboards: vec!["us".to_string()],
        }
    }
}

#[derive(Debug, Clone)]
pub struct InputMethodConfig {
    pub enabled: bool,
    pub engine: String,
}

impl Default for InputMethodConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            engine: "kime".to_string(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct KernelConfig {
    pub type_: String,
}

impl Default for KernelConfig {
    fn default() -> Self {
        Self {
            type_: "linux".to_string(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct DiskConfig {
    pub swap: SwapMode,
}

impl Default for DiskConfig {
    fn default() -> Self {
        Self {
            swap: SwapMode::Suspend,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct PackagesConfig {
    // Desktop
    pub kde: bool,
    // Browsers
    pub firefox: bool,
    pub whale: bool,
    pub chrome: bool,
    pub mullvad: bool,
    // Office
    pub libreoffice: bool,
    pub hoffice: bool,
    pub texlive: bool,
    // Development
    pub vscode: bool,
    pub sublime: bool,
    pub git: bool,
    pub rust: bool,
    pub julia: bool,
    pub nodejs: bool,
    pub github_cli: bool,
    // Multimedia
    pub vlc: bool,
    pub obs: bool,
    pub freetv: bool,
    pub ytdlp: bool,
    pub freetube: bool,
    // Gaming
    pub steam: bool,
    pub unciv: bool,
    pub snes9x: bool,
    // Virtualization
    pub virtualbox: bool,
    pub docker: bool,
    // Communication
    pub teams: bool,
    pub whatsapp: bool,
    pub onenote: bool,
    // Utility
    pub bluetooth: bool,
    pub conky: bool,
    pub vnc: bool,
    pub samba: bool,
}

#[derive(Debug, Clone)]
pub struct InstallConfig {
    pub target_disk: String,
    pub hostname: String,
    pub username: String,
    pub root_password: String,
    pub user_password: String,
    pub use_encryption: bool,
    pub encryption_password: String,
    pub bootloader: String,
    pub autologin: bool,
}

impl Default for InstallConfig {
    fn default() -> Self {
        Self {
            target_disk: String::new(),
            hostname: "blunux".to_string(),
            username: "user".to_string(),
            root_password: String::new(),
            user_password: String::new(),
            use_encryption: false,
            encryption_password: String::new(),
            bootloader: "grub".to_string(),
            autologin: true,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Config {
    pub blunux: BlunuxConfig,
    pub locale: LocaleConfig,
    pub input_method: InputMethodConfig,
    pub kernel: KernelConfig,
    pub disk: DiskConfig,
    pub packages: PackagesConfig,
    pub install: InstallConfig,
    /// True when config was successfully loaded from a TOML file.
    /// When true, all fields are trusted and interactive prompts are skipped.
    pub loaded_from_file: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            blunux: BlunuxConfig::default(),
            locale: LocaleConfig::default(),
            input_method: InputMethodConfig::default(),
            kernel: KernelConfig::default(),
            disk: DiskConfig::default(),
            packages: PackagesConfig::default(),
            install: InstallConfig::default(),
            loaded_from_file: false,
        }
    }
}

// TOML deserialization structures
#[derive(Deserialize, Default)]
struct TomlRoot {
    blunux: Option<TomlBlunux>,
    locale: Option<TomlLocale>,
    input_method: Option<TomlInputMethod>,
    kernel: Option<TomlKernel>,
    disk: Option<TomlDisk>,
    install: Option<TomlInstall>,
    packages: Option<TomlPackages>,
}

#[derive(Deserialize, Default)]
struct TomlBlunux {
    version: Option<String>,
    name: Option<String>,
}

#[derive(Deserialize, Default)]
struct TomlLocale {
    language: Option<TomlStringOrArray>,
    timezone: Option<String>,
    keyboard: Option<Vec<String>>,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum TomlStringOrArray {
    Single(String),
    Array(Vec<String>),
}

#[derive(Deserialize, Default)]
struct TomlInputMethod {
    enabled: Option<bool>,
    engine: Option<String>,
}

#[derive(Deserialize, Default)]
struct TomlKernel {
    #[serde(rename = "type")]
    type_: Option<String>,
}

#[derive(Deserialize, Default)]
struct TomlDisk {
    swap: Option<String>,
}

#[derive(Deserialize, Default)]
struct TomlInstall {
    hostname: Option<String>,
    username: Option<String>,
    root_password: Option<String>,
    user_password: Option<String>,
    bootloader: Option<String>,
    encryption: Option<bool>,
    autologin: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlPackages {
    desktop: Option<TomlDesktop>,
    browser: Option<TomlBrowser>,
    office: Option<TomlOffice>,
    development: Option<TomlDevelopment>,
    multimedia: Option<TomlMultimedia>,
    gaming: Option<TomlGaming>,
    virtualization: Option<TomlVirtualization>,
    communication: Option<TomlCommunication>,
    utility: Option<TomlUtility>,
}

#[derive(Deserialize, Default)]
struct TomlDesktop {
    kde: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlBrowser {
    firefox: Option<bool>,
    whale: Option<bool>,
    chrome: Option<bool>,
    mullvad: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlOffice {
    libreoffice: Option<bool>,
    hoffice: Option<bool>,
    texlive: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlDevelopment {
    vscode: Option<bool>,
    sublime: Option<bool>,
    git: Option<bool>,
    rust: Option<bool>,
    julia: Option<bool>,
    nodejs: Option<bool>,
    github_cli: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlMultimedia {
    vlc: Option<bool>,
    obs: Option<bool>,
    freetv: Option<bool>,
    ytdlp: Option<bool>,
    freetube: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlGaming {
    steam: Option<bool>,
    unciv: Option<bool>,
    snes9x: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlVirtualization {
    virtualbox: Option<bool>,
    docker: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlCommunication {
    teams: Option<bool>,
    whatsapp: Option<bool>,
    onenote: Option<bool>,
}

#[derive(Deserialize, Default)]
struct TomlUtility {
    bluetooth: Option<bool>,
    conky: Option<bool>,
    vnc: Option<bool>,
    samba: Option<bool>,
}

impl Config {
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self, String> {
        let content = fs::read_to_string(path.as_ref())
            .map_err(|e| format!("Failed to read config file: {}", e))?;

        let toml_root: TomlRoot = toml::from_str(&content)
            .map_err(|e| format!("Error parsing config file: {}", e))?;

        let mut cfg = Config::default();

        // [blunux] section
        if let Some(b) = toml_root.blunux {
            if let Some(v) = b.version {
                cfg.blunux.version = v;
            }
            if let Some(v) = b.name {
                cfg.blunux.name = v;
            }
        }

        // [locale] section
        if let Some(l) = toml_root.locale {
            if let Some(lang) = l.language {
                cfg.locale.languages = match lang {
                    TomlStringOrArray::Single(s) => vec![s],
                    TomlStringOrArray::Array(a) => a,
                };
            }
            if let Some(v) = l.timezone {
                cfg.locale.timezone = v;
            }
            if let Some(v) = l.keyboard {
                cfg.locale.keyboards = v;
            }
        }

        // [input_method] section
        if let Some(im) = toml_root.input_method {
            if let Some(v) = im.enabled {
                cfg.input_method.enabled = v;
            }
            if let Some(v) = im.engine {
                cfg.input_method.engine = v;
            }
        }

        // [kernel] section
        if let Some(k) = toml_root.kernel {
            if let Some(v) = k.type_ {
                cfg.kernel.type_ = v;
            }
        }

        // [disk] section - NEW: properly parse swap configuration
        if let Some(d) = toml_root.disk {
            if let Some(v) = d.swap {
                cfg.disk.swap = SwapMode::from_str(&v);
            }
        }

        // [install] section
        if let Some(i) = toml_root.install {
            if let Some(v) = i.hostname {
                cfg.install.hostname = v;
            }
            if let Some(v) = i.username {
                cfg.install.username = v;
            }
            if let Some(v) = i.root_password {
                cfg.install.root_password = v;
            }
            if let Some(v) = i.user_password {
                cfg.install.user_password = v;
            }
            if let Some(v) = i.bootloader {
                cfg.install.bootloader = v;
            }
            if let Some(v) = i.encryption {
                cfg.install.use_encryption = v;
            }
            if let Some(v) = i.autologin {
                cfg.install.autologin = v;
            }
        }

        // [packages] sections
        if let Some(p) = toml_root.packages {
            if let Some(d) = p.desktop {
                if let Some(v) = d.kde {
                    cfg.packages.kde = v;
                }
            }
            if let Some(b) = p.browser {
                if let Some(v) = b.firefox {
                    cfg.packages.firefox = v;
                }
                if let Some(v) = b.whale {
                    cfg.packages.whale = v;
                }
                if let Some(v) = b.chrome {
                    cfg.packages.chrome = v;
                }
                if let Some(v) = b.mullvad {
                    cfg.packages.mullvad = v;
                }
            }
            if let Some(o) = p.office {
                if let Some(v) = o.libreoffice {
                    cfg.packages.libreoffice = v;
                }
                if let Some(v) = o.hoffice {
                    cfg.packages.hoffice = v;
                }
                if let Some(v) = o.texlive {
                    cfg.packages.texlive = v;
                }
            }
            if let Some(d) = p.development {
                if let Some(v) = d.vscode {
                    cfg.packages.vscode = v;
                }
                if let Some(v) = d.sublime {
                    cfg.packages.sublime = v;
                }
                if let Some(v) = d.git {
                    cfg.packages.git = v;
                }
                if let Some(v) = d.rust {
                    cfg.packages.rust = v;
                }
                if let Some(v) = d.julia {
                    cfg.packages.julia = v;
                }
                if let Some(v) = d.nodejs {
                    cfg.packages.nodejs = v;
                }
                if let Some(v) = d.github_cli {
                    cfg.packages.github_cli = v;
                }
            }
            if let Some(m) = p.multimedia {
                if let Some(v) = m.vlc {
                    cfg.packages.vlc = v;
                }
                if let Some(v) = m.obs {
                    cfg.packages.obs = v;
                }
                if let Some(v) = m.freetv {
                    cfg.packages.freetv = v;
                }
                if let Some(v) = m.ytdlp {
                    cfg.packages.ytdlp = v;
                }
                if let Some(v) = m.freetube {
                    cfg.packages.freetube = v;
                }
            }
            if let Some(g) = p.gaming {
                if let Some(v) = g.steam {
                    cfg.packages.steam = v;
                }
                if let Some(v) = g.unciv {
                    cfg.packages.unciv = v;
                }
                if let Some(v) = g.snes9x {
                    cfg.packages.snes9x = v;
                }
            }
            if let Some(v) = p.virtualization {
                if let Some(val) = v.virtualbox {
                    cfg.packages.virtualbox = val;
                }
                if let Some(val) = v.docker {
                    cfg.packages.docker = val;
                }
            }
            if let Some(c) = p.communication {
                if let Some(v) = c.teams {
                    cfg.packages.teams = v;
                }
                if let Some(v) = c.whatsapp {
                    cfg.packages.whatsapp = v;
                }
                if let Some(v) = c.onenote {
                    cfg.packages.onenote = v;
                }
            }
            if let Some(u) = p.utility {
                if let Some(v) = u.bluetooth {
                    cfg.packages.bluetooth = v;
                }
                if let Some(v) = u.conky {
                    cfg.packages.conky = v;
                }
                if let Some(v) = u.vnc {
                    cfg.packages.vnc = v;
                }
                if let Some(v) = u.samba {
                    cfg.packages.samba = v;
                }
            }
        }

        cfg.loaded_from_file = true;
        Ok(cfg)
    }

    /// Get list of script-installable packages based on config
    pub fn get_script_package_list(&self) -> Vec<String> {
        let mut scripts = Vec::new();

        // Browsers
        if self.packages.firefox {
            scripts.push("firefox".to_string());
        }
        if self.packages.whale {
            scripts.push("whale".to_string());
        }
        if self.packages.chrome {
            scripts.push("chrome".to_string());
        }
        if self.packages.mullvad {
            scripts.push("mullvad".to_string());
        }

        // Office
        if self.packages.libreoffice {
            scripts.push("libreoffice".to_string());
        }
        if self.packages.hoffice {
            scripts.push("hoffice".to_string());
        }
        if self.packages.texlive {
            scripts.push("texlive".to_string());
        }

        // Development
        if self.packages.vscode {
            scripts.push("vscode".to_string());
        }
        if self.packages.sublime {
            scripts.push("sublime".to_string());
        }
        if self.packages.rust {
            scripts.push("rust".to_string());
        }
        if self.packages.julia {
            scripts.push("julia".to_string());
        }
        if self.packages.nodejs {
            scripts.push("nodejs".to_string());
        }
        if self.packages.github_cli {
            scripts.push("github_cli".to_string());
        }

        // Multimedia
        if self.packages.obs {
            scripts.push("obs".to_string());
        }
        if self.packages.vlc {
            scripts.push("vlc".to_string());
        }
        if self.packages.freetv {
            scripts.push("freetv".to_string());
        }
        if self.packages.ytdlp {
            scripts.push("ytdlp".to_string());
        }
        if self.packages.freetube {
            scripts.push("freetube".to_string());
        }

        // Gaming
        if self.packages.steam {
            scripts.push("steam".to_string());
        }
        if self.packages.unciv {
            scripts.push("unciv".to_string());
        }
        if self.packages.snes9x {
            scripts.push("snes9x".to_string());
        }

        // Virtualization
        if self.packages.virtualbox {
            scripts.push("virtualbox".to_string());
        }
        if self.packages.docker {
            scripts.push("docker".to_string());
        }

        // Communication
        if self.packages.teams {
            scripts.push("teams".to_string());
        }
        if self.packages.whatsapp {
            scripts.push("whatsapp".to_string());
        }
        if self.packages.onenote {
            scripts.push("onenote".to_string());
        }

        // Utility
        if self.packages.conky {
            scripts.push("conky".to_string());
        }
        if self.packages.vnc {
            scripts.push("vnc".to_string());
        }
        if self.packages.samba {
            scripts.push("samba".to_string());
        }
        if self.packages.bluetooth {
            scripts.push("bluetooth".to_string());
        }

        scripts
    }
}
