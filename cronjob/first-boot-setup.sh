#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - FIRST BOOT SETUP (FULL INSTALLER)
# Chạy DUY NHẤT 1 LẦN khi VPS khởi động sau khi cài đặt bootstrap
# Nhiệm vụ: cài đặt toàn bộ OCM + OpenClaw + .env + Nginx + SSL
# Log: /var/log/ocm_first_boot.log
# =========================================================

MANAGER_DIR="/root/openclaw-manager"
OCM_ENV_FILE="$MANAGER_DIR/.env"
LOG_FILE="/var/log/ocm_first_boot.log"

# --- Kiểm tra xem đã chạy rồi chưa ---
FIRST_BOOT_DONE="false"
if [ -f "$OCM_ENV_FILE" ]; then
    source "$OCM_ENV_FILE"
fi
if [ "$FIRST_BOOT_DONE" == "true" ]; then
    exit 0
fi

# Ghi log toàn bộ output
exec > >(tee -a "$LOG_FILE") 2>&1

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[0;97m'
NC='\033[0m'

# Đợi network khởi động xong trước khi bắt đầu
sleep 20

clear
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}     OPENCLAW MANAGER - FIRST BOOT SETUP       ${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${CYAN}  Log: $LOG_FILE${NC}"
echo ""

# 1. Phát hiện hệ điều hành và Cấu hình tường lửa
echo -e "${YELLOW}[1/7] Phát hiện hệ điều hành và mở cổng (Firewall)...${NC}"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS=$(uname -s)
fi

open_ports() {
    if command -v ufw &> /dev/null; then
        echo -e "    - Sử dụng UFW để mở cổng 22, 80, 443..."
        ufw allow 22/tcp > /dev/null 2>&1
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
        ufw --force enable > /dev/null 2>&1
    elif command -v firewall-cmd &> /dev/null; then
        echo -e "    - Sử dụng Firewalld để mở cổng 22, 80, 443..."
        firewall-cmd --permanent --add-port=22/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=80/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=443/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
    else
        echo -e "    - Sử dụng iptables để mở cổng 22, 80, 443..."
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    fi
}
open_ports

# 2. Cấp quyền thực thi cho các script
echo -e "${YELLOW}[2/7] Thiết lập quyền thực thi cho các script...${NC}"
chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null
chmod +x "$MANAGER_DIR"/scripts/*.sh 2>/dev/null
chmod +x "$MANAGER_DIR"/cronjob/*.sh 2>/dev/null

# 3. Cài đặt gói phụ thuộc theo OS
echo -e "${YELLOW}[3/7] Cài đặt gói phụ thuộc cho hệ điều hành $OS...${NC}"

PACKAGES="curl git nginx certbot python3-certbot-nginx sudo jq"

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    echo -e "${CYAN}    - Đang cập nhật kho ứng dụng (apt update)...${NC}"
    apt update -y > /dev/null 2>&1
    for pkg in $PACKAGES; do
        echo -e "${CYAN}    - Đang cài đặt: ${WHITE}$pkg${NC}"
        apt install -y $pkg > /dev/null 2>&1
    done
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    yum install -y epel-release > /dev/null 2>&1
    for pkg in $PACKAGES; do
        echo -e "${CYAN}    - Đang cài đặt: ${WHITE}$pkg${NC}"
        yum install -y $pkg > /dev/null 2>&1
    done
else
    echo -e "${RED}Cảnh báo: HĐH $OS chưa được hỗ trợ tự động. Hãy cài curl, git, nginx thủ công.${NC}"
fi

# 4. Kiểm tra hệ thống & cài đặt OpenClaw Core
echo -e "${YELLOW}[4/7] Kiểm tra hệ thống & OpenClaw Core...${NC}"

# Kiểm tra bộ nhớ Swap
echo -e "${YELLOW}    - Kiểm tra bộ nhớ Swap...${NC}"
SWAP_SIZE=$(free -m | grep -i swap | awk '{print $2}')
if [ -z "$SWAP_SIZE" ] || [ "$SWAP_SIZE" -eq 0 ]; then
    echo -e "${CYAN}    - Không tìm thấy Swap. Đang tạo 2GB Swap...${NC}"
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 > /dev/null 2>&1
    chmod 600 /swapfile
    mkswap /swapfile > /dev/null 2>&1
    swapon /swapfile > /dev/null 2>&1
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    echo -e "${GREEN}    - Đã tạo thành công 2GB Swap.${NC}"
else
    echo -e "${GREEN}    - Bộ nhớ Swap đã có sẵn (${SWAP_SIZE}MB).${NC}"
fi

# Tối ưu hóa RAM cho Node.js
echo -e "${YELLOW}    - Thiết lập giới hạn bộ nhớ cho Node.js...${NC}"
sed -i '/NODE_OPTIONS=.*max-old-space-size/d' ~/.bashrc
echo "export NODE_OPTIONS=\"--max-old-space-size=\$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))\"" >> ~/.bashrc
export NODE_OPTIONS="--max-old-space-size=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))"

# Kiểm tra Node.js (Yêu cầu Node 22+)
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}    - Đang cài đặt Node.js (v24)...${NC}"
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - > /dev/null 2>&1
        sudo apt-get install -y nodejs > /dev/null 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash - > /dev/null 2>&1
        sudo yum install -y nodejs > /dev/null 2>&1
    fi
else
    NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VER" -lt 22 ]; then
        echo -e "${RED}    - Cảnh báo: Node.js v$NODE_VER quá thấp. Yêu cầu v22+.${NC}"
    else
        echo -e "${GREEN}    - Node.js v$NODE_VER đã sẵn sàng.${NC}"
    fi
fi

# Hàm cài đặt Gateway Service
install_gateway_service() {
    mkdir -p ~/.config/systemd/user/
    cat << 'EOF' > ~/.config/systemd/user/openclaw-gateway.service
[Unit]
Description=OpenClaw Gateway (v2026.3.12)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/node /usr/lib/node_modules/openclaw/dist/index.js gateway --port 18789
Restart=always
RestartSec=5
TimeoutStopSec=30
TimeoutStartSec=30
SuccessExitStatus=0 143
KillMode=control-group
Environment=HOME=/root
Environment=TMPDIR=/tmp
Environment=PATH=/root/.local/bin:/root/.npm-global/bin:/root/bin:/root/.volta/bin:/root/.asdf/shims:/root/.bun/bin:/root/.nvm/current/bin:/root/.fnm/current/bin:/root/.local/share/pnpm:/usr/local/bin:/usr/bin:/bin
Environment=OPENCLAW_GATEWAY_PORT=18789
Environment=OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service
Environment="OPENCLAW_WINDOWS_TASK_NAME=OpenClaw Gateway"
Environment=OPENCLAW_SERVICE_MARKER=openclaw
Environment=OPENCLAW_SERVICE_KIND=gateway
Environment=OPENCLAW_SERVICE_VERSION=2026.3.12

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload > /dev/null 2>&1
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
    loginctl enable-linger root > /dev/null 2>&1
    systemctl --user enable openclaw-gateway.service > /dev/null 2>&1
    systemctl --user restart openclaw-gateway.service > /dev/null 2>&1
}

# Kiểm tra và cài OpenClaw
if ! command -v openclaw &> /dev/null; then
    echo -e "${YELLOW}    - Không tìm thấy OpenClaw. Đang tiến hành cài đặt tự động...${NC}"
    curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard

    if command -v openclaw &> /dev/null; then
        echo -e "${GREEN}    - Cài đặt OpenClaw thành công!${NC}"
        sudo loginctl enable-linger root > /dev/null 2>&1

        # Tạo thư mục và copy file cấu hình
        mkdir -p "$HOME/.openclaw"
        cp "$MANAGER_DIR/openclaw-templates/openclaw.env.example" "$HOME/.openclaw/.env"
        cp "$MANAGER_DIR/openclaw-templates/openclaw.json" "$HOME/.openclaw/"

        # Cập nhật DOMAIN_NAME và token tự động
        sed -i "s/DOMAIN_NAME=ai.example.com/DOMAIN_NAME=$(hostname)/g" "$HOME/.openclaw/.env"
        sed -i "s/your_secure_random_token_here/$(openssl rand -hex 32)/g" "$HOME/.openclaw/.env"
        echo -e "${GREEN}    - Đã tạo ~/.openclaw/.env với DOMAIN_NAME=$(hostname)${NC}"

        # Cài đặt Gateway Service
        echo -e "${YELLOW}    - Đang thiết lập OpenClaw Gateway Service...${NC}"
        install_gateway_service

        # Khởi tạo cơ bản
        openclaw onboard --no-interactive > /dev/null 2>&1
    else
        echo -e "${RED}    - Cài đặt OpenClaw thất bại. Kiểm tra lại thủ công.${NC}"
    fi
else
    echo -e "${GREEN}    - OpenClaw đã được cài đặt sẵn.${NC}"

    # Đảm bảo .env tồn tại với đúng hostname
    if [ ! -f "$HOME/.openclaw/.env" ]; then
        mkdir -p "$HOME/.openclaw"
        cp "$MANAGER_DIR/openclaw-templates/openclaw.env.example" "$HOME/.openclaw/.env"
        sed -i "s/DOMAIN_NAME=ai.example.com/DOMAIN_NAME=$(hostname)/g" "$HOME/.openclaw/.env"
        sed -i "s/your_secure_random_token_here/$(openssl rand -hex 32)/g" "$HOME/.openclaw/.env"
        echo -e "${GREEN}    - Đã tạo ~/.openclaw/.env với DOMAIN_NAME=$(hostname)${NC}"
    elif grep -q "ai.example.com" "$HOME/.openclaw/.env"; then
        sed -i "s/ai.example.com/$(hostname)/g" "$HOME/.openclaw/.env"
        echo -e "${GREEN}    - Đã cập nhật DOMAIN_NAME=$(hostname) trong .env${NC}"
    fi

    install_gateway_service
fi

# Kích hoạt Bash Completion
openclaw completion --write-state > /dev/null 2>&1
openclaw completion --shell bash --install > /dev/null 2>&1
source ~/.bashrc > /dev/null 2>&1 || true

# 5. Cấu hình Domain & SSL (Nginx Proxy)
echo -e "${YELLOW}[5/7] Cấu hình Domain & SSL (Nginx Proxy)...${NC}"
CURRENT_HOSTNAME=$(hostname)

DEFAULT_HOSTNAMES=("localhost" "ubuntu" "debian" "raspberrypi" "")
IS_DEFAULT=false
for h in "${DEFAULT_HOSTNAMES[@]}"; do
    [ "$CURRENT_HOSTNAME" == "$h" ] && IS_DEFAULT=true && break
done

if $IS_DEFAULT; then
    echo -e "${YELLOW}    - Hostname '$CURRENT_HOSTNAME' là giá trị mặc định. Bỏ qua Nginx & SSL.${NC}"
    echo -e "${YELLOW}    - Cài domain sau qua menu OCM > Quản lý Domain & SSL.${NC}"
elif [[ ! $CURRENT_HOSTNAME =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${YELLOW}    - Hostname '$CURRENT_HOSTNAME' không phải domain hợp lệ. Bỏ qua.${NC}"
else
    echo -e "${CYAN}    - Phát hiện hostname: ${WHITE}$CURRENT_HOSTNAME${NC}"
    echo -e "${CYAN}    - Đang cấu hình Nginx Proxy & SSL...${NC}"
    bash "$MANAGER_DIR/manage_domain.sh" "$CURRENT_HOSTNAME" 18789
    echo -e "${GREEN}    - Hoàn tất cấu hình Nginx & SSL cho $CURRENT_HOSTNAME!${NC}"
fi

# Lưu hostname cho cronjob check-reboot-hostname
echo "$CURRENT_HOSTNAME" > "$MANAGER_DIR/cronjob/.last_hostname"

# 6. Tối ưu symlink và shortcut
echo -e "${YELLOW}[6/7] Thiết lập shortcut 'ocm'...${NC}"
ln -sf "$MANAGER_DIR/menu.sh" /usr/local/bin/ocm
chmod +x /usr/local/bin/ocm
echo -e "${GREEN}    - Lệnh 'ocm' đã sẵn sàng.${NC}"

# 7. Đánh dấu hoàn tất — không chạy lại lần sau
echo -e "${YELLOW}[7/7] Hoàn tất & đánh dấu trạng thái...${NC}"
sed -i '/^FIRST_BOOT_DONE=/d' "$OCM_ENV_FILE" 2>/dev/null
echo "FIRST_BOOT_DONE=true" >> "$OCM_ENV_FILE"

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}     FIRST BOOT SETUP HOÀN TẤT!               ${NC}"
echo -e "${BLUE}================================================${NC}"
if [[ $CURRENT_HOSTNAME =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${GREEN}  🌐 Dashboard: https://$CURRENT_HOSTNAME${NC}"
fi
echo -e "${YELLOW}  💡 Gõ 'ocm' để mở menu quản lý OpenClaw.${NC}"
echo -e "${BLUE}================================================${NC}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== FIRST BOOT SETUP HOÀN TẤT ====="
echo "FIRST BOOT SETUP HOÀN TẤT" >> "$LOG_FILE"
