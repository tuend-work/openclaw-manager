#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}>>> QUẢN LÝ DOMAIN & SSL <<<${NC}"
echo -n "Nhập domain mới (vd: ai.example.com): "
read domain

if [[ -z "$domain" ]]; then
    echo -e "${RED}Lỗi: Domain không được để trống!${NC}"
    sleep 2
    exit 1
fi

# Basic domain validation regex
if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}Lỗi: Định dạng domain không hợp lệ!${NC}"
    sleep 2
    exit 1
fi

echo -e "${GREEN}Đang thực hiện cấu hình cho: $domain...${NC}"
# Logic for hostname, SSL, and Proxy will go here
echo "1. Đổi hostname..."
echo "2. Cài đặt SSL (Certbot)..."
echo "3. Cấu hình Proxy đến OpenClaw Port..."

echo -e "${GREEN}Hoàn tất! (Đây là bản nháp)${NC}"
read -p "Nhấn Enter để quay lại menu..."
