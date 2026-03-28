#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - COMMAND CENTER
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

options=(
    "Mở giao diện Chat (TUI)"
    "Kiểm tra sức khỏe hệ thống"
    "Khởi động lại toàn bộ dịch vụ"
    "Bật/Tắt Tự động Check Update (Login)"
    "Quay lại Menu chính"
)

current=0
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

execute_action_sl() {
    local index=$1
    if [ $index -eq 4 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    case $index in
        0) openclaw tui ;;
        1) [ -f "$MANAGER_DIR/scripts/check_openclaw_service.sh" ] && bash "$MANAGER_DIR/scripts/check_openclaw_service.sh" ;;
        2) systemctl restart openclaw nginx > /dev/null 2>&1 && echo -e "${GREEN}Đã khởi động lại dịch vụ!${NC}" ;;
        3) 
            CHECK_LINE="[ -f $MANAGER_DIR/scripts/check_update_silent.sh ] && bash $MANAGER_DIR/scripts/check_update_silent.sh"
            if grep -q "check_update_silent.sh" ~/.bashrc; then
                sed -i "/check_update_silent.sh/d" ~/.bashrc
                echo -e "${RED}Đã TẮT tự động kiểm tra update khi login.${NC}"
            else
                echo "$CHECK_LINE" >> ~/.bashrc
                echo -e "${GREEN}Đã BẬT tự động kiểm tra update khi login.${NC}"
            fi
            ;;
    esac
    [ "$index" -ne 0 ] && pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "OPENCLAW COMMAND CENTER"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-3, 0]:${NC}"
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
            [1-4]) execute_action_sl $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_action_sl $current ;;
        esac
    fi
done
