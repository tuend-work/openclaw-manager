#!/bin/bash

# Real path to script directory
REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# Modern Color Palette
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
BLUE='\033[0;94m'
MAGENTA='\033[0;95m'
CYAN='\033[0;96m'
WHITE='\033[0;97m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'
BG_CYAN='\033[46m'

options=(
    "Chat Now! (Mở giao diện Chat TUI)"
    "Service Status (Kiểm tra sức khỏe hệ thống)"
    "Restart All (Khởi động lại toàn bộ dịch vụ)"
    "Quay lại Menu chính"
)

current=0
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_menu() {
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}OPENCLAW COMMAND CENTER${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-3, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 4 ] && display_num=0
        
        # Colorize the description in parentheses
        item_text="${options[$i]}"
        if [[ "$item_text" =~ (.*)(\(.*\))(.*) ]]; then
            colored_text="${BASH_REMATCH[1]}${GRAY}${BASH_REMATCH[2]}${NC}${BASH_REMATCH[3]}"
        else
            colored_text="$item_text"
        fi

        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${colored_text} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${colored_text}               ${NC}" 
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Shortcut: [Enter]: Chọn | [0]: Quay lại${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

execute_action() {
    local index=$1
    if [ $index -eq 3 ]; then exit 0; fi # Back
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    case $index in
        0) # Chat Now
            if command -v openclaw &> /dev/null; then
                openclaw tui
            else
                echo -e "${RED}Lỗi: Không tìm thấy lệnh openclaw.${NC}"
            fi
            ;;
        1) # Service Status
            if [ -f "$MANAGER_DIR/scripts/check_openclaw_service.sh" ]; then
                bash "$MANAGER_DIR/scripts/check_openclaw_service.sh"
            else
                echo -e "${RED}Lỗi: Không tìm thấy file check_openclaw_service.sh${NC}"
            fi
            ;;
        2) # Restart All
            echo -e "${YELLOW}Đang khởi động lại OpenClaw & Nginx...${NC}"
            systemctl restart openclaw nginx > /dev/null 2>&1
            echo -e "${GREEN}Đã khởi động lại toàn bộ dịch vụ!${NC}"
            ;;
    esac
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    if [ $index -ne 0 ]; then # TUI handles its own exit
        read -p "Nhấn Enter để quay lại..."
    fi
    tput civis
    clear
}

# Hide cursor
tput civis
clear

while true; do
    show_menu
    read -rsn1 key
    case "$key" in
        $'\x1b')
            read -rsn2 -t 0.1 next_key
            case "$next_key" in
                "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
            esac
            ;;
        [1-3])
            execute_action $((key - 1))
            ;;
        0)
            execute_action 3
            ;;
        "")
            execute_action $current
            ;;
    esac
done
