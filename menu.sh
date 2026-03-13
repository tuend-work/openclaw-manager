#!/bin/bash

# Path to the manager directory (automatically detect real script directory, handles symlinks)
REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"


# Modern Color Palette
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
BLUE='\033[0;94m'
MAGENTA='\033[0;95m'
CYAN='\033[0;96m'
WHITE='\033[0;97m'
BOLD='\033[1m'
NC='\033[0m'
BG_CYAN='\033[46m'
BG_BLACK='\033[40m'

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}➤ Lỗi: Vui lòng chạy lệnh này với quyền root (sudo ocm)${NC}"
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
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}WELCOME TO OPEN-CLAW MANAGER${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} Trạng thái: ${GREEN}${BOLD}Active${NC}"
    echo -e " ${WHITE}●${NC} OCM Version: ${MAGENTA}v2.1.0${NC}"
    echo -e " ${WHITE}●${NC} OpenClaw: ${YELLOW}${OPENCLAW_VER}${NC}"
    echo -e " ${WHITE}●${NC} IP v4: ${BLUE}${IP_ADDR}${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-8]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 9 ] && display_num=0
        
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${options[$i]}               ${NC}" 
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Shortcut: [Enter]: Chọn | [0]: Thoát${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

# Function to execute module based on index
execute_module() {
    local index=$1
    tput cnorm
    case $index in
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
    tput civis
    clear
}

# Hide cursor
tput civis
clear # Initial clear

while true; do
    show_menu
    read -rsn1 key # Read 1 character only
    
    case "$key" in
        # Arrow keys starting with escape
        $'\x1b')
            read -rsn2 -t 0.1 next_key
            case "$next_key" in
                "[A") # Up arrow
                    current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} ))
                    ;;
                "[B") # Down arrow
                    current=$(( (current + 1) % ${#options[@]} ))
                    ;;
            esac
            ;;
        [1-8]) # Number keys 1-8
            execute_module $((key - 1))
            ;;
        0) # Number key 0 (Exit)
            execute_module 8
            ;;
        "") # Enter key
            execute_module $current
            ;;
    esac
done


