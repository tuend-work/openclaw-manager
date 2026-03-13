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

# 1. Tự động nhận diện thư mục hiện tại
MANAGER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo -e "${YELLOW}[1/4] Thư mục quản lý: $MANAGER_DIR...${NC}"

# 2. Cấp quyền thực thi cho các file .sh
echo -e "${YELLOW}[2/4] Thiết lập quyền thực thi cho các script...${NC}"
chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null

# 3. Cấu hình phím tắt 'ocm' và tự động chạy khi login
echo -e "${YELLOW}[3/4] Cấu hình phím tắt 'ocm' và SSH Welcome...${NC}"

# Xóa alias cũ nếu có và thêm alias mới
sed -i '/alias ocm=/d' ~/.bashrc
echo "alias ocm='bash $MANAGER_DIR/menu.sh'" >> ~/.bashrc
echo -e "${GREEN}    - Đã cập nhật alias 'ocm'${NC}"

# Xóa lệnh cũ nếu có và thêm lệnh welcome mới
sed -i '/wellcome.sh/d' ~/.bashrc
echo "if [ -f \"$MANAGER_DIR/wellcome.sh\" ]; then bash \"$MANAGER_DIR/wellcome.sh\"; fi" >> ~/.bashrc
echo -e "${GREEN}    - Đã cập nhật lệnh tự động chạy menu${NC}"


# 4. Kiểm tra các phụ thuộc cơ bản (tuỳ chọn)
echo -e "${YELLOW}[4/4] Kiểm tra các gói phụ thuộc cơ bản (curl, git)...${NC}"
apt update -y > /dev/null 2>&1
apt install -y curl git certbot nginx > /dev/null 2>&1

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}      CÀI ĐẶT HOÀN TẤT! HÃY CHẠY LỆNH SAU:      ${NC}"
echo -e "${YELLOW}            source ~/.bashrc                    ${NC}"
echo -e "${YELLOW}            ocm                                 ${NC}"
echo -e "${BLUE}================================================${NC}"
