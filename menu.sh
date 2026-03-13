#!/bin/bash

# Path to the manager directory (automatically detect real script directory, handles symlinks)
REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"


# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Lỗi: Vui lòng chạy lệnh này với quyền root (Sử dụng: sudo ocm hoặc đăng nhập root)${NC}"
    exit 1
fi

show_menu() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}       WELCOME TO OPEN-CLAW MANAGER (OCM)       ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "Trạng thái hệ thống: ${GREEN}Đang hoạt động${NC}"
    echo -e "OCM Version: ${YELLOW}v1.0.0${NC}"
    echo -e "OpenClaw Version: ${YELLOW}$(openclaw --version | awk '{print $2}')${NC}"
    echo -e "OpenClaw Dashboard: ${YELLOW}http://$(hostname -I | awk '{print $1}')/dashboard${NC}";
    echo -e "Địa chỉ IP: ${BLUE}$(hostname -I | awk '{print $1}')${NC}"
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "1. Quản lý Domain & SSL"
    echo -e "2. Quản lý AI Agents"
    echo -e "3. Quản lý Kênh Chat"
    echo -e "4. Quản lý Phiên bản"
    echo -e "5. Nhật ký Hệ thống"
    echo -e "6. Điều khiển Dịch vụ"
    echo -e "7. Cập nhật Script OCM"
    echo -e "0. Thoát"
    echo -e "${BLUE}================================================${NC}"
    echo -n "Chọn chức năng [0-7]: "
}

while true; do
    show_menu
    read choice
    case $choice in
        1) bash "$MANAGER_DIR/manage_domain.sh" ;;
        2) bash "$MANAGER_DIR/manage_ai.sh" ;;
        3) bash "$MANAGER_DIR/manage_channels.sh" ;;
        4) bash "$MANAGER_DIR/manage_versions.sh" ;;
        5) bash "$MANAGER_DIR/manage_logs.sh" ;;
        6) bash "$MANAGER_DIR/manage_services.sh" ;;
        7) bash "$MANAGER_DIR/update_script.sh" ;;
        0) exit 0 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ!${NC}"; sleep 1 ;;
    esac
done
