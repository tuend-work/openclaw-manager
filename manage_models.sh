#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - AI MODELS (OPENROUTER/AUTO)
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

restart_gateway_sm() {
    echo -e "${YELLOW}⏳ Đang gửi yêu cầu làm mới Gateway...${NC}"
    export XDG_RUNTIME_DIR="/run/user/$UID"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    systemctl --user restart openclaw-gateway > /dev/null 2>&1
    echo -e "${GREEN}✅ Đã gửi lệnh làm mới!${NC}"
    sleep 0.5
}

options=(
    "Danh sách Models (List)"
    "Thêm Tài khoản / API Key mới"
    "Trạng thái Models (Status)"
    "Quản lý Phụ trợ (Fallbacks)"
    "Xóa Model (Delete)"
    "Quay lại Menu chính"
)

current=0

execute_action() {
    local index=$1
    if [ $index -eq 9 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) openclaw models list ;;
        1) openclaw models auth login --set-default;;
        2) openclaw models status --probe ;;
        # 3) [ -f "$MANAGER_DIR/scripts/get_free_model.sh" ] && bash "$MANAGER_DIR/scripts/get_free_model.sh" ;;
        # 4) echo -n "Nhập Model ID: "; read val; [ -n "$val" ] && openclaw models set "$val" && restart_gateway_sm ;;
        # 5) echo -n "Nhập Image Model ID: "; read val; [ -n "$val" ] && openclaw models set-image "$val" && restart_gateway_sm ;;
        3) openclaw models fallbacks list; read -p "Enter để đóng..." ;;
        4) openclaw models list; echo -n "Nhập Model cần xóa: "; read val; [ -n "$val" ] && openclaw models remove "$val" && restart_gateway_sm ;;
    esac
    pause_menu
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        gather_system_stats
        clear
        show_header "QUẢN LÝ AI MODELS (MODELS)"
        echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9, 0]:${NC}"
        echo ""

        for i in "${!options[@]}"; do
            display_num=$((i + 1))
            [ $display_num -eq 10 ] && display_num=0
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
                [1-9]) execute_action $((key - 1)) ;;
                0) exit 0 ;;
                "") execute_action $current ;;
            esac
        fi
    done
fi
