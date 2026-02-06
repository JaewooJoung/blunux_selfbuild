# Blunux Självbyggare - Skapa din egen Linux

> En komplett guide som även nybörjare kan följa

---

## Vad är detta?

**Blunux** är ett verktyg för att skapa din egen Linux-distribution baserad på Arch Linux.

Genom att följa denna guide kan du:
- Skapa en ISO-fil med svenska som standardspråk
- Lägga den på en USB och installera på vilken dator som helst
- Inkludera de program du vill ha från början

---

## Innehåll

1. [Förberedelser](#1-förberedelser)
2. [Installera nödvändiga program](#2-installera-nödvändiga-program)
3. [Ladda ner Blunux](#3-ladda-ner-blunux)
4. [Skapa ISO](#4-skapa-iso)
5. [Bränna till USB](#5-bränna-till-usb)
6. [Installera på datorn](#6-installera-på-datorn)
7. [Om något går fel](#7-om-något-går-fel)

---

## 1. Förberedelser

### Vad du behöver

| Komponent | Beskrivning |
|-----------|-------------|
| **Dator** | Med Arch Linux, Manjaro eller EndeavourOS |
| **Internet** | Behövs för att ladda ner paket |
| **Lagring** | Minst 20GB ledigt utrymme |
| **USB** | Minst 8GB för installations-USB |

### Jag har inte Linux!

Om du inte har ett Arch Linux-baserat system:
1. Installera [Manjaro](https://manjaro.org/download/) i VirtualBox eller VMware först
2. Eller starta [EndeavourOS](https://endeavouros.com/) från USB på en annan dator

---

## 2. Installera nödvändiga program

### 2-1. Öppna terminalen

Tryck `Ctrl + Alt + T` på tangentbordet för att öppna terminalen.

Ett svart fönster där du kan skriva kommandon ska dyka upp!

### 2-2. Uppdatera systemet

Kopiera kommandona nedan **en rad i taget**, klistra in i terminalen och tryck `Enter`.

```bash
sudo pacman -Syu
```

**Förklaring:**
- `sudo` = kör som administratör
- `pacman` = Arch Linux pakethanterare
- `-Syu` = uppdatera hela systemet

**Om den frågar efter lösenord:** Skriv ditt inloggningslösenord (det syns inte när du skriver - det är normalt)

**Om den frågar [Y/n]:** Tryck `Y` och sedan `Enter`

### 2-3. Installera verktyg

```bash
sudo pacman -S archiso base-devel git cmake --needed
```

**Förklaring:**
- `archiso` = verktyg för att skapa ISO-filer
- `base-devel` = grundläggande byggverktyg
- `git` = verktyg för att ladda ner kod
- `cmake` = byggverktyg för C++

### 2-4. Installera Julia

Julia är programmeringsspråket som kör byggverktyget.

```bash
curl -fsSL https://install.julialang.org | sh
```

**Efter körning:**
1. Tryck bara `Enter` för alla frågor (använd standardvärden)
2. När installationen är klar, **stäng och öppna terminalen igen**

### 2-5. Verifiera installation

I en ny terminal:

```bash
julia --version
```

Om du ser `julia version 1.x.x` är allt rätt!

---

## 3. Ladda ner Blunux

### 3-1. Ladda ner projektet

```bash
git clone https://github.com/nidoit/blunux_selfbuild.git
```

**Förklaring:** Laddar ner Blunux källkod från GitHub.

### 3-2. Gå till mappen

```bash
cd blunux_selfbuild
```

**Förklaring:** `cd` = change directory (byt mapp)

### 3-3. Verifiera

```bash
ls
```

Du ska se filer som:
```
build.jl  config_sv.toml  installer/  src/  README.md ...
```

---

## 4. Skapa ISO

### 4-1. Skapa svensk konfiguration

Först, skapa en svensk konfigurationsfil:

```bash
nano config_sv.toml
```

Klistra in följande innehåll:

```toml
# Blunux svensk konfiguration
[blunux]
version = "1.0"
name = "blunux-swedish"

[locale]
language = "sv_SE"
timezone = "Europe/Stockholm"
keyboard = ["se"]

[input_method]
enabled = false

[kernel]
type = "linux"

[packages.desktop]
kde = true

[packages.browser]
firefox = true

[packages.office]
libreoffice = true

[packages.development]
vscode = true
git = true

[packages.multimedia]
vlc = true

[packages.utility]
bluetooth = true
```

Spara: `Ctrl+O` → `Enter` → `Ctrl+X`

### 4-2. Bygg ISO

```bash
sudo julia build.jl config_sv.toml
```

**Detta händer:**

```
╔══════════════════════════════════════════════════════════╗
║           Blunux Self-Build Tool v1.0.0                  ║
║        Build your custom Arch-based Linux ISO            ║
╚══════════════════════════════════════════════════════════╝

[*] Blunux build starting: blunux-swedish
    Working directory: /home/user/blunux_selfbuild/work
    Output directory: /home/user/blunux_selfbuild/out

[0/13] Building C++ installer...
[1/13] Initializing archiso profile...
...
[13/13] Building ISO...
```

**Tidsåtgång:** 20 minuter till 1 timme beroende på internethastighet

**När det är klart:**
```
============================================================
[SUCCESS] ISO built successfully!
    Output: /home/user/blunux_selfbuild/out/blunux-swedish-2026.01.30-x86_64.iso
============================================================
```

### 4-3. Verifiera ISO-fil

```bash
ls -lh out/
```

Om du ser `blunux-swedish-xxxx.xx.xx-x86_64.iso` har det fungerat!

---

## 5. Bränna till USB

### Förberedelser

- **USB-minne** (minst 8GB)
- **Varning:** All data på USB:n kommer att raderas!

### 5-1. Hitta USB-enhetens namn

Sätt i USB:n i datorn och kör:

```bash
lsblk
```

**Exempelutdata:**
```
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 500.0G  0 disk           <- Hårddisk
├─sda1   8:1    0   512M  0 part /boot
└─sda2   8:2    0 499.5G  0 part /
sdb      8:16   1  14.9G  0 disk           <- USB (detta är viktigt!)
└─sdb1   8:17   1  14.9G  0 part /run/media/user/USB
```

**Hur du hittar USB:n:**
- `RM`-kolumnen visar `1` (Removable = flyttbar)
- Storleken matchar USB-minnets kapacitet
- I exemplet ovan är `sdb` USB:n

### 5-2. Skriv ISO till USB

**Viktigt:** Byt ut `/dev/sdb` mot **din USB-enhets namn**!

```bash
sudo dd if=out/blunux-swedish-*.iso of=/dev/sdb bs=4M status=progress oflag=sync
```

**Förklaring:**
- `dd` = diskkopiering
- `if=` = indata-fil (ISO)
- `of=` = utdata-enhet (USB)
- `status=progress` = visa framsteg

**Väntetid:** Några minuter

### 5-3. Säker borttagning

```bash
sync
sudo eject /dev/sdb
```

Nu kan du ta ut USB:n.

---

## 6. Installera på datorn

### 6-1. Starta från USB

1. **Stäng av datorn**
2. **Sätt i USB:n**
3. **Starta datorn** och tryck på startmeny-tangenten:

| Tillverkare | Startmeny-tangent |
|-------------|-------------------|
| ASUS | `F2` eller `Esc` |
| Dell | `F12` |
| HP | `F9` eller `Esc` |
| Lenovo | `F12` eller `Fn+F12` |
| MSI | `F11` |
| Acer | `F12` |
| Gigabyte | `F12` |

4. Välj **USB** i startmenyn (letar efter "UEFI:" eller "USB:")

### 6-2. Starta Blunux Live

När menyn visas:
- Välj **Blunux Live** → Startar skrivbordsmiljön

Vänta lite, sedan visas KDE-skrivbordet.

### 6-3. Kör installationsprogrammet

Öppna **terminalen** på skrivbordet (eller `Ctrl+Alt+T`):

```bash
blunux-install
```

**Automatiska steg:**
1. Tidssynkronisering
2. Pacman-nyckelring initiering
3. Spegellista kontroll
4. Paketdatabas synkronisering

**Sedan startar installationsprogrammet:**
- Välj disk
- Ange användarnamn/lösenord
- Installationen körs

### 6-4. Efter installation

```
╔══════════════════════════════════════════════════════════╗
║     Blunux installation completed!                       ║
╚══════════════════════════════════════════════════════════╝

  To reboot: reboot
```

1. Ta ut USB:n
2. Skriv `reboot` och tryck `Enter`
3. Din nya Blunux startar!

---

## 7. Om något går fel

### "sudo: command not found"

Du kör inte på ett Arch Linux-system.
Använd Arch Linux, Manjaro eller EndeavourOS.

### "julia: command not found"

Julia är inte installerat eller terminalen inte omstartad.

```bash
# Installera igen
curl -fsSL https://install.julialang.org | sh

# Stäng och öppna terminalen igen
```

### "Permission denied"

Du glömde `sudo`:

```bash
# Fel
julia build.jl config_sv.toml

# Rätt
sudo julia build.jl config_sv.toml
```

### USB startar inte

1. **Inaktivera Secure Boot:** I BIOS, sätt Secure Boot till Disabled
2. **USB startordning:** Sätt USB som första startalternativ i BIOS
3. **Annan USB-port:** Prova en USB 2.0-port (ofta svart)

### Inget internet under installation

```bash
# Anslut till WiFi
nmtui
```

Använd piltangenterna för "Activate a connection" → Välj WiFi → Ange lösenord

---

## Anpassa konfigurationen

Redigera `config_sv.toml` för att lägga till/ta bort program:

```bash
nano config_sv.toml
```

**Exempel - Lägg till program:**
```toml
[packages.browser]
firefox = true
chromium = true    # Lägg till Chromium!
brave = true       # Lägg till Brave!

[packages.gaming]
steam = true       # Lägg till Steam!
lutris = true      # Lägg till Lutris!

[packages.multimedia]
vlc = true
obs = true         # Lägg till OBS Studio!
spotify = true     # Lägg till Spotify!
```

Spara: `Ctrl+O` → `Enter` → `Ctrl+X`

Bygg sedan igen:
```bash
sudo julia build.jl config_sv.toml
```

---

## Tillgängliga paket

### Webbläsare (`packages.browser`)
| Nyckel | Program |
|--------|---------|
| `firefox` | Firefox |
| `chromium` | Chromium |
| `chrome` | Google Chrome |
| `brave` | Brave |

### Kontor (`packages.office`)
| Nyckel | Program |
|--------|---------|
| `libreoffice` | LibreOffice |
| `onlyoffice` | OnlyOffice |

### Utveckling (`packages.development`)
| Nyckel | Program |
|--------|---------|
| `vscode` | Visual Studio Code |
| `git` | Git |
| `nodejs` | Node.js |
| `rust` | Rust |
| `docker` | Docker |

### Multimedia (`packages.multimedia`)
| Nyckel | Program |
|--------|---------|
| `vlc` | VLC |
| `obs` | OBS Studio |
| `gimp` | GIMP |
| `spotify` | Spotify |

### Spel (`packages.gaming`)
| Nyckel | Program |
|--------|---------|
| `steam` | Steam |
| `lutris` | Lutris |
| `wine` | Wine |

### Verktyg (`packages.utility`)
| Nyckel | Program |
|--------|---------|
| `bluetooth` | Bluetooth-stöd |
| `printing` | Skrivarstöd |
| `flatpak` | Flatpak |

---

## ⚠️ Säkerhetsvarning - Läs detta!

**Standardlösenorden i config.toml är endast för testning!**

```toml
[install]
root_password = "root"    # ← Standardvärde
user_password = "user"    # ← Standardvärde
```

### Ändra lösenord efter installation:

```bash
# Ändra användarlösenord
passwd

# Ändra root-lösenord
sudo passwd root
```

### Eller ändra i config.toml innan du bygger:

```toml
[install]
root_password = "mittsakralösenord"
user_password = "mittsakralösenord"
```

> 💡 **Tips:** Använd alltid starka lösenord när du installerar på en riktig dator!

---

## Behöver du hjälp?

- **GitHub Issues:** https://github.com/nidoit/blunux_selfbuild/issues
- Skapa ett ärende med din fråga eller bugg!

---

**Lycka till med Blunux!**
