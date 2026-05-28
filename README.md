# Linux Security Scan Script

> 一鍵自動化資安掃描腳本，整合 Rkhunter、Lynis、Maldet 三大資安工具

**版本**: 1.0.0
**更新日期**: 2026-05-28
**作者**: moemoe200163
**倉庫**: https://github.com/moemoe200163/linux-security-scan

---

## 目錄

1. [專案概述](#專案概述)
2. [功能特色](#功能特色)
3. [系統需求](#系統需求)
4. [安裝方式](#安裝方式)
5. [使用方式](#使用方式)
6. [命令列選項](#命令列選項)
7. [檢測維度](#檢測維度)
8. [輸出報告](#輸出報告)
9. [架構設計](#架構設計)
10. [跨平台支援](#跨平台支援)
11. [安全性考量](#安全性考量)
12. [常見問題](#常見問題)
13. [更新日誌](#更新日誌)

---

## 專案概述

### 背景

在管理多台 Linux 伺服器時，安全掃描是例行資安作業的重要環節。
傳統方式需要管理員手動執行多個工具、收集結果、整合報告，耗費大量時間且容易遺漏。

### 解決方案

本腳本將三大Github資安工具整合為一鍵執行：
- **Rkhunter** - Rootkit 檢測
- **Lynis** - 系統安全審計
- **Maldet** - 惡意程式掃描

並加入 SSH 爆破分析、運行期行為審計、持久化通道檢測等進階功能。

### 目標用戶

- 系統管理員
- DevOps 工程師
- 資安人員
- 運維人員

---

## 功能特色

### 核心功能

| 功能 | 說明 |
|------|------|
| 一鍵掃描 | 單一命令完成所有安全檢測 |
| 自動化安裝 | 自動偵測發行版並安裝所需工具 |
| SSH 暴力破解分析 | 統計失敗/成功次數、攻擊者 IP 排行榜 |
| 運行期行為審計 | 檢測 Fileless 木馬、記憶體後門 |
| 持久化通道檢測 | systemd、cron、.bashrc 劫持 |
| 橫向移動風險 | SSH 私鑰、authorized_keys 稽核 |
| 容器隔離審計 | Docker 特權/危險掛載 |
| 結構化報告 | 自動生成 `/var/log/security-scan/` 報告 |

### 檢測維度（20+）

```
傳統工具：Rkhunter / Lynis / Maldet
系統日誌：last / lastb / lastlog / SSH logs
運行期行為：deleted binary / 高 CPU 偽裝 / 持久化
網路：非標準埠口 / DNS 礦池查詢 / 混雜模式
特權後門：sudoers / authorized_keys / SUID/SGID
環境劫持：.bashrc / profile.d
橫向移動：id_rsa / *.pem / known_hosts
動態連結庫：ld.so.preload / LD_PRELOAD
認證模組：PAM 設定與模組完整性
容器隔離：Docker privileged / 危險掛載
日誌完整性：行數比對 / syslog 重啟
```

---

## 系統需求

### 支援發行版

| 發行版 | 版本 | 套件管理 |
|--------|------|----------|
| Ubuntu | 18.04+ | apt-get |
| Debian | 10+ | apt-get |
| RHEL/CentOS | 7/8/9 | yum |
| Rocky/Alma | 8/9 | yum |
| Fedora | 34+ | dnf |
| Arch Linux | Rolling | pacman |
| Manjaro | Rolling | pacman |

### 權限需求

- **必須**：root 權限（用於完整系統掃描）
- **必要條件**：`sudo` 或直接 root 登入

### 磁碟空間

- 報告目錄：`/var/log/security-scan/`（每份報告約 50-200 KB）
- 工具安裝：約 50-100 MB

---

## 安裝方式

### 方式一：從 GitHub Clone

```bash
# 取得最新版本
git clone https://github.com/moemoe200163/linux-security-scan.git

# 進入目錄
cd linux-security-scan

# 賦予執行權限
chmod +x security-scan.sh
```

### 方式二：直接下載

```bash
# 使用 curl
curl -O https://raw.githubusercontent.com/moemoe200163/linux-security-scan/main/security-scan.sh
chmod +x security-scan.sh

# 或使用 wget
wget https://raw.githubusercontent.com/moemoe200163/linux-security-scan/main/security-scan.sh
chmod +x security-scan.sh
```

---

## 使用方式

### 基本用法

```bash
# 標準掃描（會安裝工具）
sudo ./security-scan.sh

# 使用 git 源碼安裝最新版本
sudo ./security-scan.sh --git

# 跳過安裝（工具已存在）
sudo ./security-scan.sh --no-install

# 僅安裝工具，不執行掃描
sudo ./security-scan.sh --install-only
```

### 完整範例

```bash
# 首次使用
sudo ./security-scan.sh --git

# 查看最新報告
cat /var/log/security-scan/security-scan-*.log | tail -200

# 定時執行（加入 crontab）
sudo crontab -e
# 加入以下行：每天凌晨 3 點執行
# 0 3 * * * /root/linux-security-scan/security-scan.sh --no-install
```

---

## 命令列選項

| 選項 | 說明 |
|------|------|
| 無選項 | 安裝工具並執行完整掃描 |
| `--git` | 從 git 源碼編譯安裝最新版本工具 |
| `--install-only` | 僅安裝工具，不執行掃描 |
| `--no-install` | 跳過安裝，直接執行掃描（工具已存在） |
| `-h, --help` | 顯示幫助訊息 |

### 範例

```bash
# 基本掃描
sudo ./security-scan.sh

# Git 源碼安裝 + 掃描
sudo ./security-scan.sh --git

# Git 安裝 + 僅安裝
sudo ./security-scan.sh --git --install-only

# 跳過安裝執行掃描
sudo ./security-scan.sh --no-install

# 顯示幫助
sudo ./security-scan.sh -h
```

---

## 檢測維度

### 一、傳統資安工具

| 工具 | 檢測目標 | 執行指令 |
|------|----------|----------|
| **Rkhunter** | Rootkit、隱藏程序、LKM | `rkhunter --check --sk --rwo` |
| **Lynis** | 系統安全弱點、錯誤配置 | `lynis audit system --no-colors` |
| **Maldet** | 惡意程式、shell script、後門 | `maldet -a /` |

### 二、系統日誌與入侵偵測

| 檢測項目 | 技術手段 |
|----------|----------|
| 最近登入記錄 | `last -20` |
| 登入失敗記錄 | `lastb -20` |
| 使用者最後登入 | `lastlog` |
| SSH 暴力破解統計 | `journalctl` / `/var/log/auth.log` / `/var/log/secure` |
| 系統錯誤與警告 | `/var/log/messages` |

### 三、SSH 暴力破解分析

| 統計項目 | 說明 |
|----------|------|
| 失敗登入次數 | SSH 認證失敗總次數 |
| 成功登入次數 | SSH 認證成功總次數 |
| 攻擊者 IP 排行榜 | TOP 10 按攻擊次數排序 |
| 所有被掃描 IP | 嘗試登入過的所有 IP |
| 首次/最近攻擊時間 | 攻擊時間軸分析 |
| 成功登入 IP 與時間 | 已被入侵的可疑來源 |

### 四、運行期行為審計（Post-Exploitation）

| 維度 | 檢測內容 | 技術手段 |
|------|----------|----------|
| **執行期進程** | 無檔案進程（deleted binary） | `ls -al /proc/*/exe \| grep deleted` |
| **偽裝程序** | 高 CPU 偽裝進程 | `ps aux \| awk '{if($3>80.0) print}'` |
| **持久化** | systemd 服務變動（7天內） | `find /etc/systemd/system/ -mtime -7` |
| **排程** | 異常 cron 排程 | `crontab -l` + `/etc/cron.d/*` |
| **網路** | 非標準埠口外聯 | `ss -antp \| grep ESTABLISHED` |
| **DNS 監控** | 礦池域名查詢 | `grep -iE "xmr\|mining\|pool" /var/log/messages` |

### 五、特權與認證後門

| 檢測項目 | 技術手段 |
|----------|----------|
| SSH Authorized Keys | 檢查所有使用者的 `~/.ssh/authorized_keys` |
| sudoers 異常權限 | `grep -v "^#" /etc/sudoers \| grep NOPASSWD` |
| SUID 權限檔案 | `find / -perm -4000 -type f` |
| SGID 權限檔案 | `find / -perm -2000 -type f` |

### 六、橫向移動風險

| 檢測項目 | 技術手段 |
|----------|----------|
| SSH 私鑰 | `find / -name "id_rsa"` |
| 憑證檔案 | `find / -name "*.pem"` |
| 已知主機 | `find / -name "known_hosts"` |

### 七、環境配置劫持

| 檢測項目 | 技術手段 |
|----------|----------|
| .bashrc 惡意指令 | `grep -E "wget\|curl\|nohup\|eval" ~/.bashrc` |
| profile.d 可疑腳本 | `find /etc/profile.d/ -type f \| xargs grep` |

### 八、動態連結庫與 PAM 後門

| 檢測項目 | 技術手段 |
|----------|----------|
| LD_PRELOAD 劫持 | `cat /etc/ld.so.preload` + `echo $LD_PRELOAD` |
| PAM 模組變動 | `find /etc/pam.d/ -mtime -7` |
| PAM 模組完整性 | `ls -la /lib*/security/pam_*.so` |

### 九、核心模組與容器隔離

| 檢測項目 | 技術手段 |
|----------|----------|
| LKM 核心模組 | `lsmod` 與 `/sys/module` 比對 |
| Docker 特權容器 | `docker inspect --format='{{.HostConfig.Privileged}}'` |
| 危險掛載 | `docker inspect \| grep "/var/run/docker.sock"` |

### 十、網路與日誌防禦

| 檢測項目 | 技術手段 |
|----------|----------|
| 網卡混雜模式 | `ip link show \| grep PROMISC` |
| 日誌完整性 | `wc -l /var/log/auth.log` |
| syslog 重啟事件 | `journalctl -u rsyslog --since "7 days ago"` |

### 十一、資源異常監控

| 檢測項目 | 技術手段 |
|----------|----------|
| 高 CPU 程序 | `ps aux --sort=-%cpu \| head` |
| 高記憶體程序 | `ps aux --sort=-%mem \| head` |
| 可疑高 CPU 偽裝 | `ps aux \| awk '{if($3>80.0) print}' \| grep -v kworker` |

---

## 輸出報告

### 報告位置

```
/var/log/security-scan/security-scan-YYYYMMDD-HHMMSS.log
```

### 報告結構

```
========================================
  Linux Security Scan Report
========================================
掃描時間: 2026-05-28 10:00:00
主機名稱: server01.example.com
發行版: Ubuntu 22.04
報告檔案: /var/log/security-scan/security-scan-*.log

========================================
  工具安裝狀態
========================================
Rkhunter: 已安裝
Lynis: 已安裝
Maldet: 已安裝

========================================
  Rkhunter 結果摘要
========================================
--- 警告項目 ---
...

========================================
  Lynis 結果摘要
========================================
--- 警告 (Warnings) ---
...

========================================
  Maldet 結果摘要
========================================
--- 掃描結果 ---
...

========================================
  SSH 暴力破解統計分析
========================================
--- SSH 失敗登入次數 ---
總失敗次數: 156
...

========================================
  運行期行為審計 (Post-Exploitation)
========================================
--- 1. 執行期進程與記憶體異常 ---
...

========================================
  高階持久化與隱蔽路徑稽核
========================================
...

========================================
  風險等級摘要
========================================
Rkhunter 警告: 3
Lynis 警告: 2
Maldet 命中: 0
========================================
  掃描完成
========================================
```

### 快速查看報告

```bash
# 查看最新報告
cat $(ls -t /var/log/security-scan/security-scan-*.log | head -1)

# 或直接使用腳本输出了
sudo ./security-scan.sh --no-install
# 腳本執行完畢會自動 cat 報告內容
```

---

## 架構設計

### 函式結構

| 函式名 | 職責 |
|--------|------|
| `check_root()` | 驗證 root 權限 |
| `detect_os()` | 辨識發行版與套件管理 |
| `check_tools()` | 檢查工具是否已安裝 |
| `install_tools()` | 安裝資安工具（apt/yum/dnf/pacman） |
| `install_from_git()` | 從 git 源碼編譯安裝最新版本 |
| `run_rkhunter()` | 執行 Rkhunter 掃描 |
| `run_lynis()` | 執行 Lynis 審計 |
| `run_maldet()` | 執行 Maldet 掃描 |
| `generate_report()` | 彙整所有結果生成報告 |
| `cleanup()` | 清理程序 |

### 流程圖

```
┌─────────────────────────────────────┐
│  檢查 root 權限                      │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  偵測作業系統發行版                   │
│  (Debian/RHEL/Fedora/Arch)          │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  檢查工具是否已安裝                   │
│  (Rkhunter/Lynis/Maldet)            │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  安裝工具                            │
│  (套件管理器 或 Git 源碼)             │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  執行 Rkhunter Rootkit 檢測          │
│  → /var/log/rkhunter.log            │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  執行 Lynis 系統安全審計              │
│  → /var/log/lynis.log              │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  執行 Maldet 惡意程式掃描            │
│  → /var/log/maldet.log             │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  生成結構化報告                       │
│  → /var/log/security-scan/*.log    │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  顯示報告內容 (cat)                   │
└─────────────────────────────────────┘
```

### 全域變數

```bash
REPORT_DIR="/var/log/security-scan"  # 報告輸出目錄
TIMESTAMP=$(date +"%Y%m%d-%H%MM%S")  # 時間戳記
REPORT_FILE="${REPORT_DIR}/security-scan-${TIMESTAMP}.log"  # 報告檔案
HOSTNAME=$(hostname)                 # 主機名稱
LOG_DIR="/var/log"                    # 日誌目錄
```

---

## 跨平台支援

### 支援矩陣

| 發行版 | 套件管理 | SSH 日誌 | 測試狀態 |
|--------|----------|----------|----------|
| Ubuntu 22.04 | apt-get | journalctl | ✓ 已測試 |
| Debian 11 | apt-get | /var/log/auth.log | ✓ 已測試 |
| RHEL 8/9 | yum | /var/log/secure | 預設支援 |
| CentOS 7 | yum | /var/log/secure | 預設支援 |
| Fedora 38+ | dnf | journalctl | 預設支援 |
| Arch Linux | pacman | journalctl | 預設支援 |
| Rocky/Alma 9 | yum | /var/log/secure | 預設支援 |

### SSH 日誌自動偵測

腳本會依序嘗試以下日誌來源：

1. `journalctl --no-pager` (systemd)
2. `/var/log/auth.log` (Debian/Ubuntu)
3. `/var/log/secure` (RHEL/CentOS)
4. `last -f /var/log/btmp` (fallback)

---

## 安全性考量

### 必要權限

本腳本需要 root 權限才能：
- 安裝系統工具
- 執行完整系統掃描
- 讀取所有日誌檔案
- 檢查系統設定

### 資料處理

- 所有報告保存在 `/var/log/security-scan/`
- 日誌檔案包含主機名稱、IP、操作記錄
- 建議：定期清理或離線保存

### 誤報可能

以下情況可能觸發警告（正常）：

| 警告 | 說明 |
|------|------|
| Rkhunter SSH 設定不一致 | SSH 允許 root 登入但 rkhunter 設定不允許 |
| SUID 檔案過多 | 某些發行版預設有較多 SUID 檔案 |
| 高 CPU 程序 | 正常伺服器負載可能產生 |

---

## 常見問題

### Q: 執行需要 root 嗎？

**是**，所有安全掃描都需要 root 權限：
```bash
sudo ./security-scan.sh
```

### Q: 工具安裝失敗怎麼辦？

使用 `--no-install` 跳過安裝：
```bash
sudo ./security-scan.sh --no-install
```

或手動安裝後再執行。

### Q: 可以定時執行嗎？

可以，加入 crontab：
```bash
sudo crontab -e
# 每天凌晨 3 點執行
0 3 * * * /path/to/security-scan.sh --no-install
```

### Q: 報告佔用太多空間？

手動清理：
```bash
# 刪除 30 天前的報告
find /var/log/security-scan/ -mtime +30 -delete
```

### Q: Ubuntu 的 Lynis 安裝失敗？

使用 `--git` 從源碼安裝最新版本：
```bash
sudo ./security-scan.sh --git
```

### Q: SSH 暴力破解統計沒有資料？

檢查 SSH 日誌設定：
```bash
# 開啟 SSH 詳細日誌
sed -i 's/#LogLevel INFO/LogLevel VERBOSE/' /etc/ssh/sshd_config
systemctl restart sshd
```

---

## 開發指南

### 環境設定

```bash
# Clone 專案
git clone https://github.com/moemoe200163/linux-security-scan.git
cd linux-security-scan

# 修改內容
vim security-scan.sh

# 測試（在 VM 或 Docker）
sudo ./security-scan.sh --no-install

# 提交
git add .
git commit -m "描述"
git push
```

### Docker 測試環境

```bash
# Ubuntu 測試
docker run -it --rm ubuntu:latest bash
apt-get update && apt-get install -y sudo git
git clone https://github.com/moemoe200163/linux-security-scan.git
cd linux-security-scan
chmod +x security-scan.sh
sudo ./security-scan.sh --git

# CentOS 測試
docker run -it --rm centos:8 bash
yum install -y sudo git
git clone https://github.com/moemoe200163/linux-security-scan.git
cd linux-security-scan
chmod +x security-scan.sh
sudo ./security-scan.sh
```

---

## 版本歷史

### v1.0.0 (2026-05-28)

- 初始版本
- 整合 Rkhunter、Lynis、Maldet
- SSH 暴力破解統計分析
- 運行期行為審計
- 跨平台支援（Ubuntu/RHEL/Fedora/Arch）
- Git 源碼安裝支援
- 自動報告生成

---

## 貢獻指南

歡迎提交 Issue 和 Pull Request！

1. Fork 此專案
2. 建立 Feature Branch (`git checkout -b feature/AmazingFeature`)
3. 提交変更 (`git commit -m 'Add some AmazingFeature'`)
4. Push 到 Branch (`git push origin feature/AmazingFeature`)
5. 建立 Pull Request

---

## 授權

本專案採用 MIT 授權。

---

## 聯絡方式

- **GitHub**: https://github.com/moemoe200163/linux-security-scan
- **問題回報**: https://github.com/moemoe200163/linux-security-scan/issues

---

*最後更新：2026-05-28*