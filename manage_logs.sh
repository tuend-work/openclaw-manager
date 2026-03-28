#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SYSTEM LOGS
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

options=(
    "Xem Log Gateway (Real-time)"
    "Xem Log OpenAI API (Error Logs)"
    "Xem Log Telegram Account"
    "Xóa sạch toàn bộ log"
    "Quay lại Menu chính"
)

current=0

execute_action() {
    local index=$1
    if [ $index -eq 4 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) openclaw logs --follow ;;
        1) journalctl -u openclaw -n 100 --no-pager ;;
        2) openclaw channels logs --channel all ;;
        3) journalctl --vacuum-time=1s && echo -e "${GREEN}Đã dọn dẹp log hệ thống.${NC}" ;;
    esac
    pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "NHẬT KÝ HỆ THỐNG (LOGS)"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-4, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 5 ] && display_num=0
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
            [1-4]) execute_action $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_action $current ;;
        esac
    fi
done
