#!/bin/bash

# OpenClaw Manager Installer
# Target Directory: /root/openclaw-manager

MANAGER_DIR="/root/openclaw-manager"
REPO_URL="https://github.com/your-repo/openclaw-manager.git" # Thay thế bằng URL thực tế nếu có

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}       BẮT ĐẦU CÀI ĐẶT OPENCLAW MANAGER         ${NC}"
echo -e "${BLUE}================================================${NC}"

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

# 2. Tự động nhận diện thư mục hiện tại
MANAGER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo -e "${YELLOW}[2/7] Thư mục quản lý: $MANAGER_DIR...${NC}"

# 3. Cấp quyền thực thi cho các file .sh
echo -e "${YELLOW}[3/7] Thiết lập quyền thực thi cho các script...${NC}"
chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null
chmod +x "$MANAGER_DIR"/cronjob/*.sh 2>/dev/null

# 4. Cấu hình phím tắt 'ocm' (Vĩnh viễn) và SSH Welcome
echo -e "${YELLOW}[4/7] Cấu hình 'ocm' ${NC}"

# Tạo symlink trong /usr/local/bin để lệnh ocm có thể chạy ở mọi nơi, mọi lúc
ln -sf "$MANAGER_DIR/menu.sh" /usr/local/bin/ocm
chmod +x /usr/local/bin/ocm

# Vẫn giữ alias trong .bashrc để dự phòng
sed -i '/alias ocm=/d' ~/.bashrc

# Xóa lệnh cũ nếu có và thêm lệnh tự động chạy menu khi login
sed -i '/wellcome.sh/d' ~/.bashrc
sed -i '/menu.sh/d' ~/.bashrc
echo "if [ -f \"$MANAGER_DIR/menu.sh\" ]; then bash \"$MANAGER_DIR/menu.sh\"; fi" >> ~/.bashrc

# 5. Kiểm tra các gói phụ thuộc hệ thống theo OS
echo -e "${YELLOW}[5/7] Cài đặt gói phụ thuộc cho hệ điều hành $OS...${NC}"

PACKAGES="curl git nginx certbot python3-certbot-nginx sudo"

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    echo -e "${CYAN}    - Đang cập nhật kho ứng dụng (apt update)...${NC}"
    apt update -y > /dev/null 2>&1
    for pkg in $PACKAGES; do
        echo -e "${CYAN}    - Đang cài đặt: ${WHITE}$pkg${NC}"
        apt install -y $pkg > /dev/null 2>&1
    done
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    echo -e "${CYAN}    - Đang cài đặt: ${WHITE}epel-release${NC}"
    yum install -y epel-release > /dev/null 2>&1
    for pkg in $PACKAGES; do
        echo -e "${CYAN}    - Đang cài đặt: ${WHITE}$pkg${NC}"
        yum install -y $pkg > /dev/null 2>&1
    done
else
    echo -e "${RED}Lỗi: Hệ điều hành $OS chưa được hỗ trợ tự động cài gói. Hãy cài curl, git, nginx thủ công.${NC}"
fi

# 6. Kiểm tra Cơ sở hạ tầng và cài đặt OpenClaw
echo -e "${YELLOW}[6/7] Kiểm tra hệ thống & OpenClaw Core...${NC}"

# Kiểm tra bộ nhớ Swap
echo -e "${YELLOW}    - Kiểm tra bộ nhớ Swap...${NC}"
SWAP_SIZE=$(free -m | grep -i swap | awk '{print $2}')
if [ -z "$SWAP_SIZE" ] || [ "$SWAP_SIZE" -eq 0 ]; then
    echo -e "${CYAN}    - Không tìm thấy Swap. Đang tạo 2GB Swap để tăng tính ổn định...${NC}"
    # Dùng fallocate nhanh hơn, dự phòng bằng dd nếu file system không support
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 > /dev/null 2>&1
    chmod 600 /swapfile
    mkswap /swapfile > /dev/null 2>&1
    swapon /swapfile > /dev/null 2>&1
    # Thêm vào fstab để tự mount khi khởi động lại (tránh trùng lặp)
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    echo -e "${GREEN}    - Đã tạo thành công 2GB Swap.${NC}"
else
    echo -e "${GREEN}    - Bộ nhớ Swap đã có sẵn (${SWAP_SIZE}MB).${NC}"
fi

# Tối ưu hóa RAM cho Node.js (Chống tràn RAM)
echo -e "${YELLOW}    - Thiết lập giới hạn bộ nhớ cho Node.js...${NC}"
sed -i '/NODE_OPTIONS=.*max-old-space-size/d' ~/.bashrc
echo "export NODE_OPTIONS=\"--max-old-space-size=\$((\$(grep MemTotal /proc/meminfo | awk '{print \$2}') / 1024 ))\"" >> ~/.bashrc
export NODE_OPTIONS="--max-old-space-size=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))"
echo -e "${GREEN}    - Đã cấu hình NODE_OPTIONS thành công.${NC}"

# Kiểm tra Node.js (Yêu cầu Node 22+)
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}    - Đang cài đặt Node.js (v24)...${NC}"
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - > /dev/null 2>&1
        sudo apt-get install -y nodejs > /dev/null 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash - > /dev/null 2>&1
        sudo yum install -y nodejs > /dev/null 2>&1
    else
        echo -e "${RED}    - Hệ điều hành chưa được hỗ trợ tự động cài Node.js. Vui lòng cài thủ công.${NC}"
    fi
else
    NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VER" -lt 22 ]; then
        echo -e "${RED}    - Cảnh báo: Phiên bản Node.js hiện tại ($NODE_VER) quá thấp. Yêu cầu v22+.${NC}"
        # Có thể thêm logic upgrade node ở đây
    fi
fi

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
    # Reload systemd và khởi động service
    systemctl --user daemon-reload > /dev/null 2>&1
    systemctl --user enable openclaw-gateway.service > /dev/null 2>&1
    systemctl --user restart openclaw-gateway.service > /dev/null 2>&1
}

# Kiểm tra lệnh openclaw
if ! command -v openclaw &> /dev/null; then
    echo -e "${YELLOW}    - Không tìm thấy OpenClaw. Đang tiến hành cài đặt tự động...${NC}"
    curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard
    
    if command -v openclaw &> /dev/null; then
        echo -e "${GREEN}    - Cài đặt OpenClaw thành công!${NC}"
        # Đảm bảo các user services (như OpenClaw daemon) tiếp tục chạy sau khi SSH logout
        echo -e "${YELLOW}    - Thiết lập quyền chạy ngầm (linger) cho root...${NC}"
        sudo loginctl enable-linger root > /dev/null 2>&1
        echo -e "${YELLOW}    - Đang thiết lập OpenClaw Gateway Service...${NC}"

        # Đảm bảo thư mục tồn tại
        mkdir -p "$HOME/.openclaw"

        # Copy file mẫu cấu hình
        cp "$MANAGER_DIR/openclaw-templates/openclaw.env.example" "$HOME/.openclaw/.env"
        cp "$MANAGER_DIR/openclaw-templates/openclaw.json" "$HOME/.openclaw/"

        # Cập nhật hostname và token mật khẩu tự động
        sed -i "s/ai.example.com/$(hostname)/g" "$HOME/.openclaw/.env"
        sed -i "s/your_secure_random_token_here/$(openssl rand -hex 32)/g" "$HOME/.openclaw/.env"
        # Cài đặt Gateway Service thủ công
        install_gateway_service

        # Chạy khởi tạo cơ bản
        openclaw onboard --no-interactive > /dev/null 2>&1
        
    else
        echo -e "${RED}    - Cài đặt OpenClaw thất bại. Vui lòng kiểm tra lại thủ công.${NC}"
    fi
else
    echo -e "${GREEN}    - OpenClaw đã được cài đặt.${NC}"
    echo -e "${YELLOW}    - Đang thiết lập OpenClaw Gateway Service...${NC}"
    # Đảm bảo service được cài và chạy
    install_gateway_service
fi

# Kích hoạt tính năng Auto-Completion (Bash) cho OpenClaw
echo -e "${YELLOW}    - Bật tính năng gợi ý lệnh (Bash Completion) cho OpenClaw...${NC}"
openclaw completion --write-state > /dev/null 2>&1
openclaw completion --shell bash --install > /dev/null 2>&1
# Sourcing profile cho phiên làm việc hiện tại luôn
source ~/.bashrc > /dev/null 2>&1 || true

# 7. Thiết lập Cronjob
echo -e "${YELLOW}[7/7] Thiết lập Cronjob ${NC}"

CRON_CMD="/usr/bin/openclaw devices approve --latest"
CRON_REBOOT_SCRIPT="$MANAGER_DIR/cronjob/check-reboot-hostname.sh"

# Khởi tạo file last_hostname lần đầu
hostname > "$MANAGER_DIR/cronjob/.last_hostname"

# Kiểm tra và thêm cronjob nếu chưa có (tránh trùng lặp)
(crontab -l 2>/dev/null | grep -v "openclaw devices approve" | grep -v "check-reboot-hostname.sh"; echo "* * * * * $CRON_CMD > /dev/null 2>&1"; echo "@reboot bash $CRON_REBOOT_SCRIPT") | crontab -
echo -e "${GREEN}    - Đã thêm Cronjob tự động duyệt thiết bị mỗi phút.${NC}"
echo -e "${GREEN}    - Đã thêm Cronjob kiểm tra cấu hình Domain khi tự khởi động lại.${NC}"

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}             CÀI ĐẶT HOÀN TẤT!                 ${NC}"
echo -e "${BLUE}================================================${NC}"
