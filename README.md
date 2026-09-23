cat << 'EOF' > README.md
# Nemo ClamAV Quick Scan & Quarantine Integration

A lightweight, robust, and network-friendly virus scanning action for the **Nemo File Manager** (Linux Mint & Cinnamon desktop environments) powered by **ClamAV**.

---

## 🚀 Features / Özellikler

- **Context Menu Integration:** Right-click any file or directory in Nemo to scan.
- **Multi-language Support (i18n):** Automatically detects desktop language (English & Turkish supported out of the box).
- **Dynamic Live Progress:** Single-line dynamic counter `[ %34 ] [ 412/1200 ] ...file.ext : OK` without cluttering the terminal.
- **Batch Processing (50 files/batch):** Runs ClamAV on batches of 50 files to bypass CLI startup overhead.
- **Network-Friendly (SMB/NFS/NAS):** Skips heavy archives (`.zip`, `.iso`, `.dmg`, etc.) by default to prevent hanging on remote mounts.
- **Safe Quarantine:** Detected threats are moved to `~/Quarantine` (or `~/Karantina`) with permissions stripped (`chmod 000`) instead of irreversible deletion.

---

## 📦 One-Line Installation / Tek Komutla Kurulum

Run this in your terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/erginlee72/nemo-clamav-scanner/main/install.sh | bash
