#!/bin/bash
#
# Linux Security Scan Script
#整合 maldet、Lynis、Rkhunter 三大資安工具
#支援 Debian/Ubuntu、RHEL/CentOS、Arch Linux
#

set -eo pipefail

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全域變數
REPORT_DIR="/var/log/security-scan"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_FILE="${REPORT_DIR}/security-scan-${TIMESTAMP}.log"
HOSTNAME=$(hostname)
LOG_DIR="/var/log"

# 命令列選項
NO_INSTALL=false
INSTALL_ONLY=false
USE_GIT=false

# 安裝源
LYNIS_GIT="https://github.com/CISOfy/lynis.git"
RKHUNTER_GIT="https://github.com/installationpoints/rkhunter.git"
MALDET_URL="https://www.rfxn.com/downloads/maldetect-current.tar.gz"

###########################################
# 訊息輸出函式
###########################################
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

###########################################
# Step 1: 環境偵測函式
###########################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此腳本需要 root 權限執行"
        error "請使用: sudo $0"
        exit 1
    fi
    info "root 權限驗證通過"
}

detect_os() {
    info "偵測作業系統發行版..."

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_NAME="${NAME:-Unknown Linux}"
        OS_VERSION="${VERSION_ID:-}"
    else
        OS_ID="unknown"
        OS_NAME="Unknown Linux"
    fi

    case "${OS_ID}" in
        debian|ubuntu|linuxmint)
            PKG_MANAGER="apt-get"
            info "偵測到: ${OS_NAME} (使用 ${PKG_MANAGER})"
            ;;
        rhel|centos|rocky|alma)
            PKG_MANAGER="yum"
            info "偵測到: ${OS_NAME} (使用 ${PKG_MANAGER})"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            info "偵測到: ${OS_NAME} (使用 ${PKG_MANAGER})"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            info "偵測到: ${OS_NAME} (使用 ${PKG_MANAGER})"
            ;;
        *)
            error "不支援的發行版: ${OS_ID}"
            exit 1
            ;;
    esac
}

check_tools() {
    info "檢查已安裝的工具..."

    local missing_tools=()

    # 檢查 rkhunter
    if command -v rkhunter &>/dev/null; then
        success "Rkhunter 已安裝: $(rkhunter --version 2>/dev/null | head -1)"
    else
        missing_tools+=("rkhunter")
        info "Rkhunter 未安裝"
    fi

    # 檢查 lynis
    if command -v lynis &>/dev/null; then
        success "Lynis 已安裝: $(lynis --version 2>/dev/null | head -1)"
    else
        missing_tools+=("lynis")
        info "Lynis 未安裝"
    fi

    # 檢查 maldet
    if command -v maldet &>/dev/null; then
        success "Maldet 已安裝: $(maldet -V 2>/dev/null | head -1)"
    else
        missing_tools+=("maldet")
        info "Maldet 未安裝"
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        warn "缺少工具: ${missing_tools[*]}"
        return 1
    fi

    return 0
}

###########################################
# Step 2: 工具安裝函式
###########################################
install_tools() {
    if [[ "${NO_INSTALL}" == true ]]; then
        info "跳過安裝（--no-install 模式）"
        return 0
    fi

    info "開始安裝資安工具..."

    # 安裝 git（如果使用 git 模式）
    if [[ "${USE_GIT}" == true ]]; then
        case "${PKG_MANAGER}" in
            apt-get)
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -qq
                apt-get install -y -qq git
                ;;
            yum)
                yum install -y git
                ;;
            dnf)
                dnf install -y git
                ;;
            pacman)
                pacman -Sy --noconfirm git
                ;;
        esac
    fi

    case "${PKG_MANAGER}" in
        apt-get)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            if [[ "${USE_GIT}" == true ]]; then
                info "使用 git 源碼安裝..."
                install_from_git
            else
                apt-get install -y -qq rkhunter lynis linux-malware-detect
            fi
            ;;
        yum)
            yum install -y rkhunter lynis
            if [[ "${USE_GIT}" == true ]]; then
                install_from_git
            fi
            ;;
        dnf)
            dnf install -y rkhunter lynis
            if [[ "${USE_GIT}" == true ]]; then
                install_from_git
            fi
            ;;
        pacman)
            pacman -Sy --noconfirm rkhunter lynis
            if [[ "${USE_GIT}" == true ]]; then
                install_from_git
            fi
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        success "工具安裝完成"
    else
        error "工具安裝失敗"
        exit 1
    fi
}

###########################################
# Git 源碼安裝函式
###########################################
install_from_git() {
    info "從 git 源碼安裝最新版本..."

    local work_dir="/tmp/security-scan-build"
    mkdir -p "${work_dir}"
    cd "${work_dir}"

    # 安裝 Lynis (直接 clone 並建立全域連結)
    if ! command -v lynis &>/dev/null; then
        info "安裝 Lynis..."
        git clone "${LYNIS_GIT}" lynis-src
        ln -sf "${work_dir}/lynis-src/lynis" /usr/local/bin/lynis
        chmod +x /usr/local/bin/lynis
    fi

    # 安裝 Rkhunter
    if ! command -v rkhunter &>/dev/null; then
        info "安裝 Rkhunter..."
        git clone "${RKHUNTER_GIT}" rkhunter-src
        cd rkhunter-src
        ./installer.sh --install | tee -a "${LOG_DIR}/install.log" || true
        cd "${work_dir}"
    fi

    # 安裝 Maldet
    if ! command -v maldet &>/dev/null; then
        info "安裝 Maldet..."
        wget -q "${MALDET_URL}" -O maldet-current.tar.gz
        tar -xzf maldet-current.tar.gz
        cd maldet-*
        ./install.sh | tee -a "${LOG_DIR}/install.log" || true
    fi

    # 保留 Lynis，不刪除 work_dir（因為 Lynis 是 symlink）
    # 只刪除其他已安裝的臨時檔案
    rm -rf "${work_dir}/rkhunter-src" "${work_dir}/maldet-"*

    cd /root
    success "Git 源碼安裝完成"
}

###########################################
# Step 3: 掃描執行函式
###########################################
run_rkhunter() {
    info "執行 Rkhunter Rootkit 檢測..."
    echo ""

    local rkhunter_log="${LOG_DIR}/rkhunter.log"

    # 更新 rkhunter 資料庫
    info "更新 Rkhunter 資料庫..."
    rkhunter --update 2>/dev/null || warn "更新失敗，繼續掃描..."

    # 執行檢測
    info "開始 Rootkit 檢測（這可能需要幾分鐘）..."
    rkhunter --check --sk --rwo 2>&1 | tee "${rkhunter_log}" || true

    success "Rkhunter 檢測完成"

    # 擷取警告
    local warnings=$(grep -c "Warning" "${rkhunter_log}" 2>/dev/null || echo "0")
    info "Rkhunter 發現 ${warnings} 個警告"

    echo ""
}

run_lynis() {
    info "執行 Lynis 系統安全審計..."
    echo ""

    local lynis_log="${LOG_DIR}/lynis.log"

    # 執行審計
    info "開始 Lynis 審計..."
    lynis audit system --no-colors 2>&1 | tee "${lynis_log}" || true

    success "Lynis 審計完成"

    # 擷取警告和建議
    local warnings=$(grep -c "Warning" "${lynis_log}" 2>/dev/null || echo "0")
    local suggestions=$(grep -c "Suggestion" "${lynis_log}" 2>/dev/null || echo "0")
    info "Lynis 發現 ${warnings} 個警告，${suggestions} 個建議"

    echo ""
}

run_maldet() {
    info "執行 Maldet 惡意程式掃描..."
    echo ""

    # 檢查 maldet 是否可用
    if ! command -v maldet &>/dev/null; then
        warn "Maldet 未安裝，跳過掃描"
        return 0
    fi

    local maldet_log="${LOG_DIR}/maldet.log"

    # 更新 malware 資料庫
    info "更新 Maldet 資料庫..."
    maldet -u 2>/dev/null || warn "更新失敗，繼續掃描..."

    # 執行全盤掃描
    info "開始 Maldet 全盤掃描（這可能需要較長時間）..."
    maldet -a / 2>&1 | tee "${maldet_log}" || true

    success "Maldet 掃描完成"

    echo ""
}

###########################################
# Step 4: 報告生成
###########################################
generate_report() {
    info "生成掃描報告..."
    echo ""

    # 確保報告目錄存在
    mkdir -p "${REPORT_DIR}"

    {
        echo "========================================"
        echo "  Linux Security Scan Report"
        echo "========================================"
        echo ""
        echo "掃描時間: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "主機名稱: ${HOSTNAME}"
        echo "發行版: ${OS_NAME} ${OS_VERSION}"
        echo "報告檔案: ${REPORT_FILE}"
        echo ""
        echo "========================================"
        echo "  工具安裝狀態"
        echo "========================================"
        echo "Rkhunter: $(command -v rkhunter &>/dev/null && echo "已安裝" || echo "未安裝")"
        echo "Lynis: $(command -v lynis &>/dev/null && echo "已安裝" || echo "未安裝")"
        echo "Maldet: $(command -v maldet &>/dev/null && echo "已安裝" || echo "未安裝")"
        echo ""

        echo "========================================"
        echo "  Rkhunter 結果摘要"
        echo "========================================"
        if [[ -f "${LOG_DIR}/rkhunter.log" ]]; then
            echo "完整日誌: ${LOG_DIR}/rkhunter.log"
            echo ""
            echo "--- 警告項目 ---"
            grep "Warning" "${LOG_DIR}/rkhunter.log" 2>/dev/null || echo "無警告"
            echo ""
            echo "--- 警示項目 ---"
            grep "Alert" "${LOG_DIR}/rkhunter.log" 2>/dev/null || echo "無警示"
        else
            echo "無日誌檔案"
        fi
        echo ""

        echo "========================================"
        echo "  Lynis 結果摘要"
        echo "========================================"
        if [[ -f "${LOG_DIR}/lynis.log" ]]; then
            echo "完整日誌: ${LOG_DIR}/lynis.log"
            echo ""
            echo "--- 警告 (Warnings) ---"
            grep "Warning" "${LOG_DIR}/lynis.log" 2>/dev/null || echo "無警告"
            echo ""
            echo "--- 建議 (Suggestions) ---"
            grep "Suggestion" "${LOG_DIR}/lynis.log" 2>/dev/null || echo "無建議"
        else
            echo "無日誌檔案"
        fi
        echo ""

        echo "========================================"
        echo "  Maldet 結果摘要"
        echo "========================================"
        if [[ -f "${LOG_DIR}/maldet.log" ]]; then
            echo "完整日誌: ${LOG_DIR}/maldet.log"
            echo ""
            echo "--- 掃描結果 ---"
            tail -50 "${LOG_DIR}/maldet.log" 2>/dev/null || echo "無法讀取日誌"
        else
            echo "無日誌檔案"
        fi
        echo ""

        echo "========================================"
        echo "  系統日誌與入侵偵測"
        echo "========================================"
        echo ""
        echo "--- 最近登入記錄 (last) ---"
        last -20 2>/dev/null || echo "無法讀取"
        echo ""
        echo "--- 登入失敗記錄 (lastb) ---"
        lastb -20 2>/dev/null || echo "無法讀取或需要 root 權限"
        echo ""
        echo "--- 最近登入記錄 (lastlog) ---"
        lastlog | tail -20 2>/dev/null || echo "無法讀取"
        echo ""
        echo "--- SSH 暴力破解統計分析 (journalctl) ---"
        echo ""

        # 從 journalctl 讀取 SSH 記錄（不用 -u sshd因為日誌在general journal）
        SSH_JOURNAL=$(journalctl --no-pager 2>/dev/null | grep -iE "sshd.*Failed|sshd.*Accepted")

        # 失敗登入統計
        echo "--- SSH 失敗登入次數 ---"
        failed_count=$(echo "$SSH_JOURNAL" | grep -i "Failed" | wc -l)
        echo "總失敗次數: ${failed_count}"
        echo ""

        # 成功登入統計
        echo "--- SSH 成功登入次數 ---"
        accepted_count=$(echo "$SSH_JOURNAL" | grep -i "Accepted" | wc -l)
        echo "總成功次數: ${accepted_count}"
        echo ""

        # 攻擊者 IP 排行榜
        echo "--- 攻擊者 IP 排行榜 (TOP 10) ---"
        echo "$SSH_JOURNAL" | grep -i "Failed" | awk '{print $NF}' | sed 's/:$//' | sort | uniq -c | sort -rn | head -10 || echo "無資料"
        echo ""

        # 所有被爆破的 IP 清單
        echo "--- 所有被掃描/爆破的 IP 清單 ---"
        echo "$SSH_JOURNAL" | grep -i "Failed" | awk '{print $NF}' | sed 's/:$//' | sort -u | head -30 || echo "無資料"
        echo ""

        # 首次攻擊時間
        echo "--- 首次被攻擊時間 ---"
        first_attack=$(echo "$SSH_JOURNAL" | grep -i "Failed" | head -1 | awk '{print $1, $2, $3}')
        echo "首次: ${first_attack:-無記錄}"
        echo ""

        # 最近攻擊時間
        echo "--- 最近被攻擊時間 ---"
        last_attack=$(echo "$SSH_JOURNAL" | grep -i "Failed" | tail -1 | awk '{print $1, $2, $3}')
        echo "最近: ${last_attack:-無記錄}"
        echo ""

        # 成功登入的 IP 與時間
        echo "========================================"
        echo "  成功登入記錄 (可能被入侵) "
        echo "========================================"
        echo ""
        echo "--- 成功登入 IP 與時間 ---"
        echo "$SSH_JOURNAL" | grep -i "Accepted" | awk '{print $1, $2, $3, $9, $11}' | head -30 || echo "無成功登入"
        echo ""

        # 警告：最近成功登入
        recent_accept=$(echo "$SSH_JOURNAL" | grep -i "Accepted" | tail -5)
        if [[ -n "$recent_accept" ]]; then
            echo "--- 最近的 5 次成功登入 ---"
            echo "$recent_accept"
            echo ""
        fi
        echo ""
        echo "--- 系統錯誤與警告 ---"
        if [[ -f /var/log/messages ]]; then
            grep -iE "error|warning|failed|attack" /var/log/messages 2>/dev/null | tail -20 || echo "無記錄"
        else
            echo "無法讀取系統日誌"
        fi
        echo ""
        echo "--- 可疑指令歷史 (bash_history 分析) ---"
        if [[ -f ~/.bash_history ]]; then
            grep -iE "wget|curl|nc|netcat|bash|telnet|ftp|chmod|chown|eval|base64" ~/.bash_history 2>/dev/null | tail -20 || echo "無可疑指令"
        fi
        echo ""

        echo "========================================"
        echo "  運行期行為審計 (Post-Exploitation)"
        echo "========================================"
        echo ""

        echo "--- 1. 執行期進程與記憶體異常 (Fileless 檢測) ---"
        echo "無對應檔案的進程 (deleted binary):"
        ls -al /proc/*/exe 2>/dev/null | grep deleted | head -20 || echo "無發現"
        echo ""
        echo "高 CPU 偽裝進程 (kswapd0/syslogd/systemd-udev):"
        ps aux | grep -E "kswapd0|syslogd|systemd-udev" | grep -v grep | awk '{if($3>80.0) print $0}' 2>/dev/null || echo "無異常"
        echo ""

        echo "--- 2. 持久化潛伏通道 (Persistence) ---"
        echo "近期 7 天 systemd 服務變動:"
        find /etc/systemd/system/ -type f -name "*.service" -mtime -7 2>/dev/null | head -20 || echo "無發現"
        echo ""
        echo "異常排程 (非系統預設):"
        for f in /etc/cron.d/* /etc/cron.daily/* /var/spool/cron/crontabs/*; do
            [[ -f "$f" ]] && basename "$f" | grep -vE "^README|popularity-contest" && echo "發現: $f"
        done 2>/dev/null | head -20 || echo "無發現"
        echo ""
        echo "系統 crontab 排程:"
        crontab -l 2>/dev/null | grep -v "^#" | head -20 || echo "無 crontab"
        echo ""
        echo "root crontab:"
        crontab -l -u root 2>/dev/null | grep -v "^#" | head -20 || echo "無"

        echo "--- 3. 外聯網路連線 (Network Outbound C2) ---"
        echo "非標準埠口外聯連線 (非 80/443, Stratum: 3333/4444/14444):"
        ss -antp 2>/dev/null | grep ESTABLISHED | grep -vE ":80|:443" | head -20 || echo "無發現"
        echo ""
        echo "可疑 DNS 查詢 (礦池域名):"
        if [[ -f /var/log/messages ]]; then
            grep -iE "xmr|monero|mining|pool" /var/log/messages 2>/dev/null | tail -10 || echo "無礦池相關 DNS"
        else
            echo "無法讀取系統日誌"
        fi
        echo ""

        echo "--- 4. 特權與認證後門 (Privilege Backdoor) ---"
        echo "SSH Authorized Keys (非系統預設):"
        for user in $(cut -d: -f1 /etc/passwd); do
            keys="/home/$user/.ssh/authorized_keys"
            [[ -f "$keys" ]] && ls -la "$keys" 2>/dev/null && echo "--- $keys ---"
        done | head -30 || echo "無發現"
        echo ""
        echo "sudoers 異常權限 (NOPASSWD:ALL):"
        grep -v "^#" /etc/sudoers 2>/dev/null | grep -iE "NOPASSWD|ALL=" | head -20 || echo "無發現"
        grep -rE "NOPASSWD|ALL=" /etc/sudoers.d/ 2>/dev/null | grep -v "^#" | head -20 || echo "無發現"
        echo ""

        echo "--- 5. 臨時目錄與 Landing Zone 清查 ---"
        echo "/tmp 執行檔 (.sh/.py/.pl/+x):"
        find /tmp -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" -o -name "*.txt" -o -name "*.jpg" \) -executable 2>/dev/null | head -20 || echo "無發現"
        echo ""
        echo "/var/tmp 執行檔:"
        find /var/tmp -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \) -executable 2>/dev/null | head -20 || echo "無發現"
        echo ""

        echo "========================================"
        echo "  高階持久化與隱蔽路徑稽核"
        echo "========================================"
        echo ""

        echo "--- 1. 環境腳本劫持 (.bashrc / .profile / profile.d) ---"
        echo "檢查 /etc/profile.d/ 中的可疑指令:"
        find /etc/profile.d/ -type f 2>/dev/null | while read f; do
            grep -lE "wget|curl|sh|fetch|nohup|bash.*&" "$f" 2>/dev/null && echo "發現可疑: $f"
        done | head -20 || echo "無發現"
        echo ""
        echo "檢查 root .bashrc 中的可疑指令:"
        [[ -f /root/.bashrc ]] && grep -E "wget|curl|nohup|bash.*&|eval" /root/.bashrc 2>/dev/null | head -10 || echo "無發現"
        echo ""
        echo "檢查其他使用者 .bashrc:"
        for home in /home/*; do
            [[ -f "$home/.bashrc" ]] && grep -E "wget|curl|nohup|bash.*&|eval" "$home/.bashrc" 2>/dev/null | head -5 && echo "--- $home/.bashrc ---"
        done | head -20 || echo "無發現"
        echo ""

        echo "--- 2. SSH 私鑰清查 (橫向移動風險) ---"
        echo "查找 id_rsa 私鑰:"
        find / -name "id_rsa" 2>/dev/null | head -20 || echo "無發現"
        echo ""
        echo "查找 .pem 憑證檔:"
        find / -name "*.pem" 2>/dev/null | head -20 || echo "無發現"
        echo ""
        echo "查找 known_hosts (可能用於横向往移動):"
        find / -name "known_hosts" 2>/dev/null | head -10 || echo "無發現"
        echo ""

        echo "--- 3. SUID/SGID 權限二進位 (提權漏洞) ---"
        echo "SUID 檔案:"
        find / -perm -4000 -type f 2>/dev/null | head -30 || echo "無發現"
        echo ""
        echo "SGID 檔案:"
        find / -perm -2000 -type f 2>/dev/null | head -30 || echo "無發現"
        echo ""

        echo "--- 4. 時間戳防偽審計 (Timestomping 檢測) ---"
        echo "systemd 服務時間戳比對 (Modify vs Change):"
        for f in /etc/systemd/system/*.service; do
            [[ -f "$f" ]] || continue
            mtime=$(stat -c "%Y" "$f" 2>/dev/null)
            ctime=$(stat -c "%Z" "$f" 2>/dev/null)
            diff=$((mtime - ctime))
            # 如果 Modify 時間比 Change 時間還要早（負值差異過大），可能是 Timestomping
            if [[ $diff -lt -86400 ]]; then
                echo "警告: $f 時間戳異常 (可能被篡改)"
            fi
        done | head -20 || echo "無異常"
        echo ""

        echo "--- 5. 資源異常監控 (高 CPU/記憶體程序) ---"
        echo "高 CPU 程序 (Top 15):"
        ps aux --sort=-%cpu | head -16 | grep -v "PID" || echo "無發現"
        echo ""
        echo "高記憶體程序 (Top 15):"
        ps aux --sort=-%mem | head -16 | grep -v "PID" || echo "無發現"
        echo ""
        echo "可疑高 CPU 偽裝程序 (非正常進程):"
        ps aux | awk '{if($3>80.0) print $0}' | grep -vE "^\s*PID|kworker|kernel" | head -10 || echo "無發現"
        echo ""
        echo "非正常網路程序 (非標準埠口):"
        ss -antp 2>/dev/null | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10 || echo "無發現"
        echo ""

        echo "========================================"
        echo "  動態連結庫劫持與 PAM 後門審計"
        echo "========================================"
        echo ""

        echo "--- LD_PRELOAD 劫持檢查 ---"
        echo "系統全域預載入設定:"
        [[ -f /etc/ld.so.preload ]] && cat /etc/ld.so.preload || echo "無此檔案（正常）"
        echo ""
        echo "環境變數 LD_PRELOAD:"
        echo "$LD_PRELOAD" | grep -v "^$" || echo "無設定（正常）"
        echo ""

        echo "--- PAM 模組後門稽核 ---"
        echo "近期 PAM 設定變動 (7天內):"
        find /etc/pam.d/ -type f -mtime -7 2>/dev/null | head -20 || echo "無發現"
        echo ""
        echo "PAM 模組完整性 (比對系統預設):"
        for module in /lib*/security/pam_unix.so /lib*/security/pam_pwquality.so; do
            [[ -f "$module" ]] && ls -la "$module" 2>/dev/null || echo "模組缺失: $module"
        done | head -10 || echo "無異常"
        echo ""

        echo "========================================"
        echo "  核心模組與容器隔離審計"
        echo "========================================"
        echo ""

        echo "--- 載入的核心模組 (LKM) ---"
        lsmod 2>/dev/null | head -30 || echo "無法讀取"
        echo ""

        echo "--- /proc/modules 與 /sys/module 一致性 ---"
        diff <(lsmod 2>/dev/null | awk 'NR>1 {print $1}' | sort) \
             <(find /sys/module -maxdepth 1 -type d -printf "%f\n" 2>/dev/null | sort) 2>/dev/null | head -20 || echo "一致性檢查通過"
        echo ""

        echo "--- Docker 容器特權稽核 ---"
        if command -v docker &>/dev/null; then
            echo "特權容器:"
            docker ps --format '{{.Names}}' 2>/dev/null | while read c; do
                privileged=$(docker inspect --format='{{.HostConfig.Privileged}}' "$c" 2>/dev/null)
                [[ "$privileged" == "true" ]] && echo "  [警告] $c - 為特權容器"
            done | head -20 || echo "無特權容器"
            echo ""
            echo "危險掛載容器:"
            docker ps --format '{{.Names}}' 2>/dev/null | while read c; do
                mounts=$(docker inspect --format='{{range .Mounts}}{{.Source}}:{{.Destination}} }}' "$c" 2>/dev/null)
                echo "$mounts" | grep -E ":/|/var/run/docker.sock" | head -5 && echo "  [警告] $c" || true
            done | head -20 || echo "無危險掛載"
        else
            echo "Docker 未安裝或無權限"
        fi
        echo ""

        echo "========================================"
        echo "  網路監聽與日誌完整性審計"
        echo "========================================"
        echo ""

        echo "--- 網卡混雜模式 (Promiscuous Mode) ---"
        ip link show 2>/dev/null | grep -E "PROMISC|UP" | head -20 || echo "無異常"
        echo ""

        echo "--- 日誌檔案完整性檢查 ---"
        echo "auth.log 行數 vs 最近修改時間:"
        [[ -f /var/log/auth.log ]] && wc -l /var/log/auth.log && ls -l /var/log/auth.log || echo "無此檔案"
        echo ""
        echo "messages 行數 vs 最近修改時間:"
        [[ -f /var/log/messages ]] && wc -l /var/log/messages && ls -l /var/log/messages || echo "無此檔案"
        echo ""

        echo "--- 系統 syslog/journald 重啟事件 ---"
        if command -v journalctl &>/dev/null; then
            journalctl -u rsyslog --since "7 days ago" 2>/dev/null | tail -10 || echo "無 rsyslog 記錄"
        else
            echo "journalctl 不可用"
        fi
        echo ""

        echo "========================================"
        echo "  掃描完成"
        echo "========================================"
        echo "報告時間: $(date '+%Y-%m-%d %H:%M:%S')"

    } > "${REPORT_FILE}"

    success "報告已生成: ${REPORT_FILE}"
    echo ""

    # 終極摘要
    echo "========================================"
    echo "  風險等級摘要"
    echo "========================================"

    local rkhunter_warnings=0
    local lynis_warnings=0
    local maldet_hits=0

    [[ -f "${LOG_DIR}/rkhunter.log" ]] && rkhunter_warnings=$(grep -c "Warning\|Alert" "${LOG_DIR}/rkhunter.log" 2>/dev/null || echo "0")
    [[ -f "${LOG_DIR}/lynis.log" ]] && lynis_warnings=$(grep -c "Warning" "${LOG_DIR}/lynis.log" 2>/dev/null || echo "0")
    [[ -f "${LOG_DIR}/maldet.log" ]] && maldet_hits=$(grep -c "hits" "${LOG_DIR}/maldet.log" 2>/dev/null || echo "0")

    echo "Rkhunter 警告: ${rkhunter_warnings}"
    echo "Lynis 警告: ${lynis_warnings}"
    echo "Maldet 命中: ${maldet_hits}"
    echo ""

    local total_issues=$((rkhunter_warnings + lynis_warnings + maldet_hits))

    if [[ ${total_issues} -eq 0 ]]; then
        success "✓ 未發現明顯風險"
    elif [[ ${total_issues} -lt 10 ]]; then
        warn "⚠ 發現 ${total_issues} 個項目，請查看報告"
    else
        error "✗ 發現 ${total_issues} 個潛在問題，請立即檢視報告"
    fi

    echo ""
    echo "完整報告: ${REPORT_FILE}"
    echo "========================================"
}

###########################################
# Step 5: 清理函式
###########################################
cleanup() {
    info "清理程序完成"
}

###########################################
# 主程式
###########################################
main() {
    # 解析命令列參數
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-install)
                NO_INSTALL=true
                shift
                ;;
            --install-only)
                INSTALL_ONLY=true
                shift
                ;;
            -h|--help)
                echo "用法: $0 [選項]"
                echo ""
                echo "選項:"
                echo "  --no-install     跳過工具安裝（假設工具已存在）"
                echo "  --install-only   僅安裝工具，不執行掃描"
                echo "  --git            從 git 源碼編譯安裝（最新版本）"
                echo "  -h, --help       顯示此幫助訊息"
                exit 0
                ;;
            --git)
                USE_GIT=true
                shift
                ;;
            *)
                error "未知的選項: $1"
                echo "使用 -h 或 --help 查看幫助"
                exit 1
                ;;
        esac
    done

    echo ""
    echo "========================================"
    echo "  Linux 資安一鍵掃描腳本"
    echo "========================================"
    echo ""

    # Step 1: 環境偵測
    check_root
    detect_os

    # 檢查工具狀態
    if check_tools; then
        info "所有工具已就緒"
    else
        info "部分工具缺失，將嘗試安裝"
    fi

    # Step 2: 安裝工具
    install_tools

    # 如果只是安裝模式，完成後退出
    if [[ "${INSTALL_ONLY}" == true ]]; then
        success "工具安裝完成"
        exit 0
    fi

    # Step 3: 執行掃描
    echo ""
    info "開始資安掃描..."
    echo ""

    run_rkhunter
    run_lynis
    run_maldet

    # Step 4: 生成報告
    generate_report

    # Step 5: 清理
    cleanup

    echo ""
    success "掃描完成！"

    echo ""
    echo "========================================"
    echo "  查看報告命令"
    echo "========================================"
    echo ""
    echo "完整報告: cat ${REPORT_FILE}"
    echo ""
    echo "========================================"
    echo "  報告內容"
    echo "========================================"
    cat "${REPORT_FILE}"
}

# 執行主程式
main "$@"