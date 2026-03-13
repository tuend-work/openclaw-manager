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

# 1. Tạo thư mục nếu chưa có
if [ ! -d "$MANAGER_DIR" ]; then
    echo -e "${YELLOW}[1/4] Tạo thư mục quản lý tại $MANAGER_DIR...${NC}"
    mkdir -p "$MANAGER_DIR"
else
    echo -e "${YELLOW}[1/4] Thư mục $MANAGER_DIR đã tồn tại. Sẽ cập nhật tệp...${NC}"
fi

# 2. Cấp quyền thực thi cho các file .sh
echo -e "${YELLOW}[2/4] Thiết lập quyền thực thi cho các script...${NC}"
chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null

# 3. Tạo Alias 'ocm' để truy cập nhanh
echo -e "${YELLOW}[3/4] Cấu hình phím tắt 'ocm' và tự động chạy khi login...${NC}"

# Thêm alias vào .bashrc nếu chưa có
if ! grep -q "alias ocm=" ~/.bashrc; then
    echo "alias ocm='bash $MANAGER_DIR/menu.sh'" >> ~/.bashrc
    echo -e "${GREEN}    - Đã thêm alias 'ocm'${NC}"
fi

# Thêm lệnh chạy wellcome.sh vào .bashrc nếu chưa có
if ! grep -q "wellcome.sh" ~/.bashrc; then
    echo "if [ -f \"$MANAGER_DIR/wellcome.sh\" ]; then bash \"$MANAGER_DIR/wellcome.sh\"; fi" >> ~/.bashrc
    echo -e "${GREEN}    - Đã thêm lệnh tự động chạy menu khi login${NC}"
fi

# 4. Kiểm tra các phụ thuộc cơ bản (tuỳ chọn)
echo -e "${YELLOW}[4/4] Kiểm tra các gói phụ thuộc cơ bản (curl, git)...${NC}"
apt update -y > /dev/null 2>&1
apt install -y curl git certbot nginx > /dev/null 2>&1

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}      CÀI ĐẶT HOÀN TẤT! HÃY CHẠY LỆNH SAU:      ${NC}"
echo -e "${YELLOW}            source ~/.bashrc                    ${NC}"
echo -e "${YELLOW}            ocm                                 ${NC}"
echo -e "${BLUE}================================================${NC}"
