#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MANAGER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo -e "${YELLOW}>>> CẬP NHẬT OPENCLAW MANAGER SCRIPT <<<${NC}"

# Check if it's a git repository
if [ ! -d "$MANAGER_DIR/.git" ]; then
    echo -e "${RED}Lỗi: Thư mục không phải là một Git repository. Không thể tự động update.${NC}"
    read -p "Nhấn Enter để quay lại..."
    exit 1
fi

echo -e "${BLUE}Đang kiểm tra cập nhật từ GitHub...${NC}"

cd "$MANAGER_DIR"
git fetch --all
git reset --hard origin/main # Giả sử branch chính là main, có thể đổi thành master nếu cần

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Cập nhật thành công!${NC}"
    chmod +x "$MANAGER_DIR"/*.sh
    bash /root/openclaw-manager/install.sh
    echo -e "${YELLOW}Hệ thống sẽ khởi động lại Menu để áp dụng thay đổi...${NC}"
    sleep 2
    bash "$MANAGER_DIR/menu.sh"
    exit 0
else
    echo -e "${RED}Có lỗi xảy ra trong quá trình cập nhật.${NC}"
fi

read -p "Nhấn Enter để quay lại menu..."
