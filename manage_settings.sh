#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SETTINGS & CONFIGURATION
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

# Helper: Restart gateway
restart_gateway() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway để áp dụng thay đổi...${NC}"
    openclaw gateway restart > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Gateway đã được khởi động lại thành công!${NC}"
    else
        echo -e "${RED}⚠️  Không thể khởi động lại Gateway.${NC}"
    fi
    sleep 1
}

options=(
    "Cổng Gateway (gateway.port)"
    "Gateway Token (Auth Token)"
    "Tailscale Mode (VPN Mode)"
    "Telegram Token (botToken)"
    "Telegram Allowed Users"
    "AI Model Mặc định (Primary)"
    "Allowed Origins (CORS)"
    "Cấu hình thủ công (Key & Value)"
    "Khởi động lại OpenClaw"
    "Quay lại Menu chính"
)

current=0

execute_action() {
    local index=$1
    if [ $index -eq 9 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) echo -n "Nhập Cổng mới (Mặc định 18789): "; read val
           [ -n "$val" ] && openclaw config set gateway.port "$val" && restart_gateway ;;
        1) echo -n "Nhập Gateway Token bảo mật: "; read val
           [ -n "$val" ] && openclaw config set gateway.auth.token "$val" && restart_gateway ;;
        2) echo -e "${YELLOW}1. Bật | 2. Tắt${NC}"; read val
           [ "$val" == "1" ] && openclaw config set gateway.tailscale.mode "on" && restart_gateway
           [ "$val" == "2" ] && openclaw config set gateway.tailscale.mode "off" && restart_gateway ;;
        3) echo -n "Nhập Telegram Bot Token: "; read val
           [ -n "$val" ] && openclaw config set channels.telegram.botToken "$val" && restart_gateway ;;
        4) echo -n "Nhập ID Telegram (cách nhau khoảng trắng): "; read -a val_array
           if [ ${#val_array[@]} -gt 0 ]; then
               json_arr="["
               for id in "${val_array[@]}"; do json_arr+="\"$id\","; done
               json_arr="${json_arr%,}]"
               openclaw config set channels.telegram.allowFrom "$json_arr" && restart_gateway
           fi ;;
        5) echo -n "Nhập Model ID (VD: openrouter/auto): "; read val
           [ -n "$val" ] && openclaw config set agents.defaults.model.primary "$val" && restart_gateway ;;
        6) echo -n "Nhập Domain (VD: https://ai.example.com): "; read val
           [ -n "$val" ] && openclaw config set gateway.controlUi.allowedOrigins "[\"$val\"]" && restart_gateway ;;
        7) echo -n "Nhập Key: "; read c_key; echo -n "Nhập Value: "; read c_val
           [ -n "$c_key" ] && openclaw config set "$c_key" "$c_val" && restart_gateway ;;
        8) systemctl restart openclaw > /dev/null 2>&1; echo -e "${GREEN}Restart hoàn tất!${NC}" ;;
    esac
    pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "CẤU HÌNH THÔNG SỐ (SETTINGS)"
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
