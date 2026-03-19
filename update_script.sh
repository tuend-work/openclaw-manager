#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - MANUAL UPDATE SCRIPT
# Gọi thủ công từ menu OCM > Tools > Cập nhật Script OCM
# Nhiệm vụ: cập nhật OCM từ GitHub với đầy đủ thông báo
# =========================================================

# Color definitions
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
BLUE='\033[0;94m'
CYAN='\033[0;96m'
WHITE='\033[0;97m'
BOLD='\033[1m'
NC='\033[0m'

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}CẬP NHẬT OPENCLAW MANAGER (OCM)${NC}    ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

# Kiểm tra git repo
if [ ! -d "$MANAGER_DIR/.git" ]; then
    echo -e "${RED}❌ Lỗi: Thư mục không phải Git repository. Không thể tự động update.${NC}"
    read -p "Nhấn Enter để quay lại..."
    exit 1
fi

cd "$MANAGER_DIR"

echo -e "${YELLOW}🔄 Đang kết nối GitHub để kiểm tra cập nhật...${NC}"
git fetch --all 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Không thể kết nối GitHub. Kiểm tra lại mạng.${NC}"
    read -p "Nhấn Enter để quay lại..."
    exit 1
fi

LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null)
REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null)
LOCAL_VER=$(git log -1 --format="%h %s" 2>/dev/null)
REMOTE_VER=$(git log -1 origin/main --format="%h %s" 2>/dev/null)

echo -e " ${WHITE}●${NC} Phiên bản hiện tại : ${YELLOW}$LOCAL_VER${NC}"
echo -e " ${WHITE}●${NC} Phiên bản mới nhất : ${GREEN}$REMOTE_VER${NC}"
echo -e "${CYAN}────────────────────────────────────────────────${NC}"

if [ "$LOCAL_HASH" == "$REMOTE_HASH" ]; then
    echo -e "${GREEN}✅ OpenClaw Manager đã là phiên bản mới nhất!${NC}"
    read -p "Nhấn Enter để quay lại..."
    exit 0
fi

echo -e "${YELLOW}📦 Phát hiện bản cập nhật mới. Tiến hành cập nhật...${NC}"

# Hiển thị changelog
echo -e "\n${CYAN}📋 Thay đổi trong phiên bản mới:${NC}"
git log HEAD..origin/main --oneline --no-walk=unsorted 2>/dev/null | head -10 | while read line; do
    echo -e "  ${WHITE}→${NC} $line"
done
echo ""

git reset --hard origin/main > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Cập nhật thành công!${NC}"

    # Cấp quyền thực thi
    chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null
    chmod +x "$MANAGER_DIR"/scripts/*.sh 2>/dev/null
    chmod +x "$MANAGER_DIR"/cronjob/*.sh 2>/dev/null
    echo -e "${GREEN}✅ Đã cấp quyền thực thi cho các scripts.${NC}"
else
    echo -e "${RED}❌ Có lỗi xảy ra trong quá trình cập nhật.${NC}"
fi

read -p "Nhấn Enter để quay lại..."
