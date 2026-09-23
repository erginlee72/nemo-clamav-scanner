cat << 'EOF' > uninstall.sh
#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Root privileges required for uninstallation."
    exec sudo bash "$0" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SYS_LANG="${LANG:-en}"

echo "Uninstalling Nemo ClamAV Integration..."

ACTION_FILE="$USER_HOME/.local/share/nemo/actions/clamscan.nemo_action"
[ -f "$ACTION_FILE" ] && rm -f "$ACTION_FILE" && echo "[-] Nemo Action removed."

SCANNER_BIN="/usr/local/bin/clamscan-nemo.sh"
[ -f "$SCANNER_BIN" ] && rm -f "$SCANNER_BIN" && echo "[-] Scanner script removed."

su - "$REAL_USER" -c "nemo -q" 2>/dev/null || true
echo "[*] Nemo reloaded."

echo ""
if [[ "$SYS_LANG" == tr* ]]; then
    read -p "ClamAV paketlerini de sistemden kaldırmak ister misiniz? (e/H): " CHOICE
    case "$CHOICE" in
        [eE][vV][eE][tT]|[eE])
            apt purge -y clamav clamav-daemon clamav-freshclam
            apt autoremove -y
            echo "[-] ClamAV paketleri kaldırıldı."
            ;;
        *)
            echo "[i] ClamAV motoru korundu."
            ;;
    esac
else
    read -p "Do you also want to remove ClamAV packages? (y/N): " CHOICE
    case "$CHOICE" in
        [yY][eE][sS]|[yY])
            apt purge -y clamav clamav-daemon clamav-freshclam
            apt autoremove -y
            echo "[-] ClamAV purged."
            ;;
        *)
            echo "[i] ClamAV kept."
            ;;
    esac
fi
echo "Uninstallation completed!"
EOF
