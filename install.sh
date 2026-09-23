cat << 'EOF' > install.sh
#!/usr/bin/env bash
# ==============================================================================
# Nemo ClamAV Integration - Universal Installer (with i18n support)
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "This installation requires root privileges to install packages."
    echo "Switching to sudo..."
    exec sudo bash "$0" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "=========================================================="
echo " Target User: $REAL_USER ($USER_HOME)"
echo "=========================================================="

echo "[1/4] Installing ClamAV packages..."
apt update -qq
apt install -y clamav clamav-daemon curl

echo "Verifying virus signature updater (freshclam)..."
systemctl stop clamav-freshclam 2>/dev/null || true
freshclam || echo "Notice: Database download will continue in background."
systemctl start clamav-freshclam 2>/dev/null || true

echo "[2/4] Deploying scanning engine (/usr/local/bin/clamscan-nemo.sh)..."
cat << 'EOF_ENGINE' > /usr/local/bin/clamscan-nemo.sh
#!/usr/bin/env bash

TARGET="$*"

SYS_LANG="${LANG:-en}"

if [[ "$SYS_LANG" == tr* ]]; then
    MSG_TARGET="Taranacak Hedef:"
    MSG_QUARANTINE="Karantina Dizini:"
    MSG_ERR_ACCESS="HATA: Hedefe erişilemedi veya yol bulunamadı!"
    MSG_COUNTING="Dosyalar taranmak üzere sayılıyor (Arşivler hariç)..."
    MSG_FOUND_FILES="Toplam %d dosya."
    MSG_STARTING="Toplu tarama (50'şerli paketler) başlıyor..."
    MSG_NO_FILES="Taranacak uygun dosya bulunamadı."
    MSG_THREAT="[TEHDİT BULUNDU]"
    MSG_ISOLATED="-> Dosya yalıtıldı ve Karantina klasörüne taşındı:"
    MSG_ERR_ISOLATE="-> HATA: Dosya karantinaya taşınamadı (İzin yetersiz)!"
    MSG_FINISHED="Tarama tamamlandı."
    MSG_THREAT_SUMMARY="UYARI: Toplam %d tehdit tespit edildi ve Karantina dizinine izole edildi!"
    MSG_CLEAN="TEMİZ: Hedefte hiçbir zararlı yazılıma rastlanmadı."
    MSG_PRESS_ENTER="Kapatmak için Enter'a basın..."
    QUARANTINE_DIR_NAME="Karantina"
else
    MSG_TARGET="Target to scan:"
    MSG_QUARANTINE="Quarantine directory:"
    MSG_ERR_ACCESS="ERROR: Target not found or inaccessible!"
    MSG_COUNTING="Counting files to scan (excluding archives)..."
    MSG_FOUND_FILES="Total %d files found."
    MSG_STARTING="Batch scanning (batches of 50) starting..."
    MSG_NO_FILES="No suitable files found to scan."
    MSG_THREAT="[THREAT DETECTED]"
    MSG_ISOLATED="-> File isolated and moved to Quarantine:"
    MSG_ERR_ISOLATE="-> ERROR: Could not move file to Quarantine (Permission denied)!"
    MSG_FINISHED="Scan completed."
    MSG_THREAT_SUMMARY="WARNING: Total %d threat(s) detected and isolated to Quarantine!"
    MSG_CLEAN="CLEAN: No threats detected in target."
    MSG_PRESS_ENTER="Press Enter to close..."
    QUARANTINE_DIR_NAME="Quarantine"
fi

RUNNING_USER="${SUDO_USER:-$USER}"
USER_DIR=$(getent passwd "$RUNNING_USER" | cut -d: -f6)
QUARANTINE_DIR="$USER_DIR/$QUARANTINE_DIR_NAME"

echo "=========================================="
echo "$MSG_TARGET $TARGET"
echo "$MSG_QUARANTINE $QUARANTINE_DIR"
echo "=========================================="
echo ""

if [ ! -e "$TARGET" ]; then
    echo "$MSG_ERR_ACCESS"
    read -p "$MSG_PRESS_ENTER"
    exit 1
fi

ARCHIVE_FILTER='! -iname *.zip ! -iname *.rar ! -iname *.7z ! -iname *.tar ! -iname *.gz ! -iname *.bz2 ! -iname *.xz ! -iname *.iso ! -iname *.dmg ! -iname *.pkg ! -iname *.cab'

echo -n "$MSG_COUNTING "
TOTAL=$(find "$TARGET" -type f $ARCHIVE_FILTER 2>/dev/null | wc -l)
printf "$MSG_FOUND_FILES\n" "$TOTAL"
echo "$MSG_STARTING"
echo "------------------------------------------"

if [ "$TOTAL" -eq 0 ]; then
    echo "$MSG_NO_FILES"
    read -p "$MSG_PRESS_ENTER"
    exit 0
fi

BATCH_SIZE=50
COUNT=0
BATCH=()
INFECTED_COUNT=0

scan_batch() {
    local files=("${!1}")
    local num_files=${#files[@]}
    [ "$num_files" -eq 0 ] && return

    local LAST_FILE="${files[-1]}"
    local BNAME="${LAST_FILE##*/}"
    local SHORT_NAME
    if [ ${#BNAME} -gt 30 ]; then
        SHORT_NAME="...${BNAME: -27}"
    else
        SHORT_NAME="$BNAME"
    fi

    local PCT=$(( COUNT * 100 / TOTAL ))
    printf "\r[%3d%%] [%d/%d] %-30s " "$PCT" "$COUNT" "$TOTAL" "$SHORT_NAME"

    local RES
    RES=$(clamscan --no-summary --scan-archive=no "${files[@]}" 2>&1)

    if echo "$RES" | grep -q "FOUND"; then
        echo "$RES" | grep "FOUND" | while IFS= read -r match; do
            local BAD_FILE="${match%: *}"
            local VIRUS_NAME="${match##*: }"

            ((INFECTED_COUNT++))
            printf "\n\033[1;31m%s\033[0m %s\n" "$MSG_THREAT" "$VIRUS_NAME"
            echo "   File: $BAD_FILE"

            mkdir -p "$QUARANTINE_DIR"
            if mv "$BAD_FILE" "$QUARANTINE_DIR/" 2>/dev/null; then
                local BASE_BAD="${BAD_FILE##*/}"
                chmod 000 "$QUARANTINE_DIR/$BASE_BAD" 2>/dev/null
                echo -e "   \033[1;33m$MSG_ISOLATED $QUARANTINE_DIR/$BASE_BAD\033[0m"
            else
                echo -e "   \033[1;31m$MSG_ERR_ISOLATE\033[0m"
            fi
        done
    fi
}

while IFS= read -r FILE; do
    BATCH+=("$FILE")
    ((COUNT++))

    if [ ${#BATCH[@]} -ge $BATCH_SIZE ]; then
        scan_batch BATCH[@]
        BATCH=()
    fi
done < <(find "$TARGET" -type f $ARCHIVE_FILTER 2>/dev/null)

if [ ${#BATCH[@]} -gt 0 ]; then
    scan_batch BATCH[@]
fi

printf "\r[100%%] [%d/%d] %-30s\n" "$TOTAL" "$TOTAL" "$MSG_FINISHED"
echo -e "\n=========================================="
if [ "$INFECTED_COUNT" -gt 0 ]; then
    printf "\033[1;31m$MSG_THREAT_SUMMARY\033[0m\n" "$INFECTED_COUNT"
    echo "$MSG_QUARANTINE $QUARANTINE_DIR"
else
    echo -e "\033[1;32m$MSG_CLEAN\033[0m"
fi
echo "=========================================="
read -p "$MSG_PRESS_ENTER"
EOF_ENGINE

chmod +x /usr/local/bin/clamscan-nemo.sh

echo "[3/4] Configuring localized Nemo Action..."
NEMO_DIR="$USER_HOME/.local/share/nemo/actions"
mkdir -p "$NEMO_DIR"

cat << 'EOF_ACTION' > "$NEMO_DIR/clamscan.nemo_action"
[Nemo Action]
Name=Scan for Viruses (ClamAV)
Name[tr]=Virüs Taraması Yap (ClamAV)
Comment=Scan selected folder or file with ClamAV
Comment[tr]=Seçilen klasörü veya dosyayı ClamAV ile tara
Exec=x-terminal-emulator -e /usr/local/bin/clamscan-nemo.sh %F
Icon-Name=security-high
Selection=any
Extensions=any;
Quote=single
EOF_ACTION

chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.local/share/nemo"

echo "[4/4] Reloading Nemo..."
su - "$REAL_USER" -c "nemo -q" 2>/dev/null || true

echo "=========================================================="
echo " Installation completed successfully!"
echo "=========================================================="
EOF
