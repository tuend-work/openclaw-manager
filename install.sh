#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - BOOTSTRAP & MANUAL INSTALLER
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

MANAGER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
OCM_ENV_FILE="$MANAGER_DIR/.env"

clear
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}       BẮT ĐẦU CÀI ĐẶT OPENCLAW MANAGER         ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Lỗi: Vui lòng chạy với quyền root.${NC}"
    exit 1
fi

# 1. Cấp quyền và Shortcut
echo -e "${YELLOW}[1/4] Khởi tạo quyền thực thi và shortcut...${NC}"
chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null
chmod +x "$MANAGER_DIR"/scripts/*.sh 2>/dev/null
chmod +x "$MANAGER_DIR"/cronjob/*.sh 2>/dev/null
ln -sf "$MANAGER_DIR/menu.sh" /usr/local/bin/ocm
chmod +x /usr/local/bin/ocm

# 2. Đăng ký SSH Hook (boot.sh)
echo -e "${YELLOW}[2/4] Đăng ký SSH Login Hook...${NC}"
sed -i '/boot.sh/d' ~/.bashrc
echo "if [ -f \"$MANAGER_DIR/boot.sh\" ]; then bash \"$MANAGER_DIR/boot.sh\"; fi" >> ~/.bashrc

# 3. Đăng ký Cronjobs (Dành cho Template OS)
echo -e "${YELLOW}[3/4] Đăng ký Cronjob khởi động...${NC}"
(crontab -l 2>/dev/null | grep -v "openclaw" | grep -v "OCM"; \
    echo "* * * * * /usr/bin/openclaw devices approve --latest > /dev/null 2>&1"; \
    echo "@reboot bash $MANAGER_DIR/cronjob/first-boot-setup.sh"; \
    echo "@reboot bash $MANAGER_DIR/cronjob/check-reboot-hostname.sh" \
) | crontab -

# 4. Kiểm tra trạng thái cài đặt
FIRST_BOOT_DONE="false"
[ -f "$OCM_ENV_FILE" ] && source "$OCM_ENV_FILE"

echo -e "\n${BLUE}================================================${NC}"
if [ "$FIRST_BOOT_DONE" == "true" ]; then
    echo -e "${GREEN}✅ Hệ thống OpenClaw đã được cài đặt từ trước.${NC}"
    echo -e "${YELLOW}⚡ Đang khởi động menu...${NC}"
    sleep 2
    bash "$MANAGER_DIR/boot.sh"
else
    echo -e "${CYAN}Hệ thống đã sẵn sàng cho bản OS Template (Tự động cài khi khởi động).${NC}"
    echo -e "${YELLOW}Bạn có muốn thực hiện cài đặt toàn bộ ngay bây giờ không?${NC}"
    read -p "Cài đặt ngay? (y/n): " choice
    if [[ "$choice" == [yY] || "$choice" == [yY][eE][sS] ]]; then
        echo -e "${GREEN}🚀 Đang thực hiện cài đặt toàn bộ thủ công...${NC}"
        bash "$MANAGER_DIR/cronjob/first-boot-setup.sh"
    else
        echo -e "${GREEN}✅ Đã thiết lập chế độ Auto-Install khi Startup (Template Mode).${NC}"
        echo -e "${YELLOW}Lần tới khi bạn khởi động lại VPS, OpenClaw sẽ tự động được cài đặt.${NC}"
    fi
fi
echo -e "${BLUE}================================================${NC}"
