#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - COMMON COMMANDS (SHORTCUTS)
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

options=(
    "Kiểm tra trạng thái Gateway (Status)"
    "View Log Openclaw Realtime (Logs)"
    "Danh sách thiết bị kết nối (Devices)"
    "Danh sách các AI Agents (Agents)"
    "Xem thông tin Dashboard (URL)"
    "Xem nội dung cấu hình (Config)"
    "Khởi động lại dịch vụ OpenClaw"
    "Cập nhật OpenClaw Core (Update)"
    "Gỡ cài đặt OpenClaw (Uninstall)"
    "Quay lại Menu chính"
)

commands=(
    "openclaw gateway status"
    "openclaw logs --follow"
    "openclaw devices list"
    "openclaw agents list"
    "openclaw dashboard"
    "openclaw config view"
    "systemctl restart openclaw"
    "curl -fsSL https://openclaw.ai/install.sh | bash"
    "openclaw uninstall --all --yes"
    ""
)

current=0

execute_cmd_sl() {
    local index=$1
    if [ $index -eq 9 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    echo -e "${YELLOW}Đang thực thi: ${WHITE}${commands[$index]}${NC}"
    
    case $index in
        1) echo -e "${BLUE}(Nhấn Ctrl+C để thoát log)${NC}"; eval "${commands[$index]}" ;;
        *) eval "${commands[$index]}" ;;
    esac
    
    pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "LỆNH ĐIỀU KHIỂN NHANH (COMMANDS)"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 10 ] && display_num=0
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
            [ -n "${commands[$i]}" ] && echo -e "     ${BLUE}→ ${commands[$i]}${NC}"
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
            [1-9]) execute_cmd_sl $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_cmd_sl $current ;;
        esac
    fi
done
