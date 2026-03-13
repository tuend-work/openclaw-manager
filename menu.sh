#!/bin/bash

# Path to the manager directory (automatically detect real script directory, handles symlinks)
REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"


# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BG_BLUE='\033[44m'

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Lỗi: Vui lòng chạy lệnh này với quyền root (Sử dụng: sudo ocm hoặc đăng nhập root)${NC}"
    exit 1
fi

# Caching system info to prevent lag
IP_ADDR=$(hostname -I | awk '{print $1}')
OPENCLAW_VER=$(openclaw --version 2>/dev/null | awk '{print $2}' || echo "N/A")

options=(
    "Quản lý Domain & SSL"
    "Quản lý AI Agents"
    "Quản lý Kênh Chat"
    "Quản lý Phiên bản"
    "Nhật ký Hệ thống"
    "Điều khiển Dịch vụ"
    "Cập nhật Script OCM"
    "Lệnh OpenClaw thường dùng"
    "Thoát"
)

current=0

# Clean up on exit (restore cursor)
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_menu() {
    # Move cursor to top-left instead of clear to reduce flicker
    printf "\033[H"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}       WELCOME TO OPEN-CLAW MANAGER (OCM)       ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "Trạng thái hệ thống: ${GREEN}Đang hoạt động${NC}"
    echo -e "OCM Version: ${YELLOW}v2.0.0${NC}"
    echo -e "OpenClaw Version: ${YELLOW}${OPENCLAW_VER}${NC}"
    echo -e "Địa chỉ IP: ${BLUE}${IP_ADDR}${NC}"
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${CYAN}Sử dụng phím mũi tên [↑/↓] và phím Enter để chọn:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_BLUE}${YELLOW} ▶ ${options[$i]} ${NC}"
        else
            echo -e "     ${options[$i]}               " # Padding to overwrite old content
        fi
    done
    echo ""
    echo -e "${BLUE}================================================${NC}"
}

# Hide cursor
tput civis
clear # Initial clear

while true; do
    show_menu
    read -rsn3 key
    case "$key" in
        $'\x1b[A') # Up arrow
            current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} ))
            ;;
        $'\x1b[B') # Down arrow
            current=$(( (current + 1) % ${#options[@]} ))
            ;;
        "") # Enter key
            tput cnorm # Show cursor for sub-scripts
            case $current in
                0) bash "$MANAGER_DIR/manage_domain.sh" ;;
                1) bash "$MANAGER_DIR/manage_ai.sh" ;;
                2) bash "$MANAGER_DIR/manage_channels.sh" ;;
                3) bash "$MANAGER_DIR/manage_versions.sh" ;;
                4) bash "$MANAGER_DIR/manage_logs.sh" ;;
                5) bash "$MANAGER_DIR/manage_services.sh" ;;
                6) bash "$MANAGER_DIR/update_script.sh" ;;
                7) bash "$MANAGER_DIR/manage_commands.sh" ;;
                8) exit 0 ;;
            esac
            tput civis # Hide cursor again
            clear # Re-clear for smooth return
            ;;
    esac
done


