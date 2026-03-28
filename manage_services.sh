#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SERVICE CONTROL
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

options=(
    "Khởi động Toàn bộ (Start All)"
    "Dừng Toàn bộ (Stop All)"
    "Khởi động lại Toàn bộ (Restart All)"
    "Bật Tự khởi động (Enable on Boot)"
    "Tắt Tự khởi động (Disable on Boot)"
    "Kiểm tra Trạng thái Dịch vụ"
    "Quay lại Menu chính"
)

current=0

execute_action() {
    local index=$1
    if [ $index -eq 6 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) systemctl start openclaw nginx redis-server ;;
        1) systemctl stop openclaw nginx redis-server ;;
        2) systemctl restart openclaw nginx redis-server ;;
        3) systemctl enable openclaw nginx redis-server ;;
        4) systemctl disable openclaw nginx redis-server ;;
        5) systemctl status openclaw nginx redis-server --no-pager ;;
    esac
    pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "ĐIỀU KHIỂN DỊCH VỤ (SERVICES)"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-6, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 7 ] && display_num=0
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${options[$i]}${NC}"
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"

    tput civis
    if read -rsn1 -t 3 key; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                    "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
                esac ;;
            [1-6]) execute_action $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_action $current ;;
        esac
    fi
done
