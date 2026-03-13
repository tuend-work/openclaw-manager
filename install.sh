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
echo -e "${YELLOW}[1/6] Phát hiện hệ điều hành và mở cổng (Firewall)...${NC}"

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
echo -e "${YELLOW}[2/6] Thư mục quản lý: $MANAGER_DIR...${NC}"

# 3. Cấp quyền thực thi cho các file .sh
echo -e "${YELLOW}[3/6] Thiết lập quyền thực thi cho các script...${NC}"
chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null

# 4. Cấu hình phím tắt 'ocm' và tự động chạy khi login
echo -e "${YELLOW}[4/6] Cấu hình phím tắt 'ocm' và SSH Welcome...${NC}"

# Xóa alias cũ nếu có và thêm alias mới
sed -i '/alias ocm=/d' ~/.bashrc
echo "alias ocm='bash $MANAGER_DIR/menu.sh'" >> ~/.bashrc
echo -e "${GREEN}    - Đã cập nhật alias 'ocm'${NC}"

# Xóa lệnh cũ nếu có và thêm lệnh tự động chạy menu khi login
sed -i '/wellcome.sh/d' ~/.bashrc
sed -i '/menu.sh/d' ~/.bashrc
echo "if [ -f \"$MANAGER_DIR/menu.sh\" ]; then bash \"$MANAGER_DIR/menu.sh\"; fi" >> ~/.bashrc
echo -e "${GREEN}    - Đã thiết lập tự động chạy menu khi login${NC}"

# 5. Kiểm tra các gói phụ thuộc hệ thống theo OS
echo -e "${YELLOW}[5/6] Cài đặt gói phụ thuộc cho hệ điều hành $OS...${NC}"

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt update -y > /dev/null 2>&1
    apt install -y curl git nginx certbot python3-certbot-nginx sudo > /dev/null 2>&1
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    yum install -y epel-release > /dev/null 2>&1
    yum install -y curl git nginx certbot python3-certbot-nginx sudo > /dev/null 2>&1
else
    echo -e "${RED}Lỗi: Hệ điều hành $OS chưa được hỗ trợ tự động cài gói. Hãy cài curl, git, nginx thủ công.${NC}"
fi

# 6. Kiểm tra và cài đặt OpenClaw
echo -e "${YELLOW}[6/6] Kiểm tra OpenClaw Core...${NC}"


# Kiểm tra Node.js (Yêu cầu Node 22+)
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}    - Đang cài đặt Node.js (v24)...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - > /dev/null 2>&1
    sudo apt-get install -y nodejs > /dev/null 2>&1
else
    NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VER" -lt 22 ]; then
        echo -e "${RED}    - Cảnh báo: Phiên bản Node.js hiện tại ($NODE_VER) quá thấp. Yêu cầu v22+.${NC}"
        # Có thể thêm logic upgrade node ở đây
    fi
fi

# Kiểm tra lệnh openclaw
if ! command -v openclaw &> /dev/null; then
    echo -e "${YELLOW}    - Không tìm thấy OpenClaw. Đang tiến hành cài đặt tự động...${NC}"
    curl -fsSL https://openclaw.ai/install.sh | bash
    
    if command -v openclaw &> /dev/null; then
        echo -e "${GREEN}    - Cài đặt OpenClaw thành công!${NC}"
        echo -e "${YELLOW}    - Đang khởi tạo OpenClaw daemon...${NC}"
        openclaw onboard --install-daemon --no-interactive > /dev/null 2>&1
    else
        echo -e "${RED}    - Cài đặt OpenClaw thất bại. Vui lòng kiểm tra lại thủ công.${NC}"
    fi
else
    echo -e "${GREEN}    - OpenClaw đã được cài đặt.${NC}"
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}      CÀI ĐẶT HOÀN TẤT! HÃY CHẠY LỆNH SAU:      ${NC}"
echo -e "${YELLOW}            source ~/.bashrc                    ${NC}"
echo -e "${YELLOW}            ocm                                 ${NC}"
echo -e "${BLUE}================================================${NC}"
