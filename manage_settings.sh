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

if ! command -v openclaw &> /dev/null; then
    echo -e "${RED}Lỗi: OpenClaw chưa được cài đặt.${NC}"
    read -p "Nhấn Enter để quay lại..."
    exit 1
fi

options=(
    "Cổng Gateway (gateway.port)"
    "Gateway Token (gateway.auth.token & remote.token)"
    "Tailscale Mode (gateway.tailscale.mode)"
    "Telegram Token (channels.telegram.botToken)"
    "Telegram Allowed Users (channels.telegram.allowFrom)"
    "AI Model Mặc định (agents.defaults.model.primary)"
    "Allowed Origins (gateway.controlUi.allowedOrigins)"
    "Cấu hình thủ công (Nhập Key & Value)"
    "Khởi động lại OpenClaw (Lưu các thay đổi)"
    "Quay lại Menu chính"
)

current=0
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_menu() {
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}CẤU HÌNH THÔNG SỐ OPENCLAW${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} Dashboard: ${CYAN}openclaw config set <key> <value>${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 10 ] && display_num=0
        
        # Colorize the Vietnamese/System description in parentheses
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
    if [ $index -eq 9 ]; then exit 0; fi # Option 0: Back
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) # Gateway Port
            echo -n "Nhập Cổng Gateway mới (Mặc định 18789): "
            read val
            if [ -n "$val" ]; then
                openclaw config set gateway.port "$val"
                echo -e "${GREEN}Đã cấu hình gateway.port = $val${NC}"
            fi
            ;;
        1) # Gateway Token
            echo -n "Nhập Gateway Token bảo mật mới: "
            read val
            if [ -n "$val" ]; then
                openclaw config set gateway.auth.token "$val" > /dev/null 2>&1
                openclaw config set gateway.remote.token "$val" > /dev/null 2>&1
                echo -e "${GREEN}Đã cấu hình Gateway Token thành công.${NC}"
            fi
            ;;
        2) # Tailscale Mode
            echo -e "${YELLOW}Chế độ Tailscale:${NC}"
            echo "1. Bật (on)"
            echo "2. Tắt (off)"
            echo -n "Chọn [1-2]: "
            read val
            if [ "$val" == "1" ]; then
                openclaw config set gateway.tailscale.mode "on"
                echo -e "${GREEN}Đã bật Tailscale.${NC}"
            elif [ "$val" == "2" ]; then
                openclaw config set gateway.tailscale.mode "off"
                echo -e "${GREEN}Đã tắt Tailscale.${NC}"
            fi
            ;;
        3) # Telegram Token
            echo -n "Nhập Telegram Bot Token: "
            read val
            if [ -n "$val" ]; then
                openclaw config set channels.telegram.botToken "$val"
                openclaw config set channels.telegram.enabled true
                echo -e "${GREEN}Đã cấu hình Telegram Bot Token và Enable kênh.${NC}"
            fi
            ;;
        4) # Telegram AllowFrom
            echo -n "Nhập ID người dùng Telegram (các ID cách nhau bởi khoảng trắng): "
            read -a val_array
            if [ ${#val_array[@]} -gt 0 ]; then
                # Convert array to JSON array format e.g. ["123", "456"]
                json_arr="["
                for id in "${val_array[@]}"; do
                    json_arr+="\"$id\","
                done
                json_arr="${json_arr%,}]" # Remove last comma and close
                openclaw config set channels.telegram.allowFrom "$json_arr"
                echo -e "${GREEN}Đã cấu hình AllowFrom: $json_arr${NC}"
            fi
            ;;
        5) # AI Model
            echo -n "Nhập Model ID AI mặc định (Vd: openrouter/auto): "
            read val
            if [ -n "$val" ]; then
                openclaw config set agents.defaults.model.primary "$val"
                echo -e "${GREEN}Đã cấu hình AI Agent Model mặc định = $val${NC}"
            fi
            ;;
        6) # Allowed Origins
            echo -n "Nhập Domain Dashboard (Vd: https://ai.example.com): "
            read val
            if [ -n "$val" ]; then
                openclaw config set gateway.controlUi.allowedOrigins "[\"$val\"]"
                echo -e "${GREEN}Đã cập nhật Allowed Origins thành $val${NC}"
            fi
            ;;
        7) # Custom Configuration
            echo -e "${YELLOW}Cấu hình thủ công:${NC}"
            echo -n "Nhập Key (VD: gateway.port): "
            read c_key
            if [ -n "$c_key" ]; then
                echo -n "Nhập Value tương ứng: "
                read c_val
                if [ -n "$c_val" ]; then
                    openclaw config set "$c_key" "$c_val"
                    # Display the updated value directly
                    echo -e "${GREEN}Đã thiết lập $c_key = $c_val${NC}"
                fi
            fi
            ;;
        8) # Restart Service
            echo -e "${YELLOW}Đang khởi động lại dịch vụ OpenClaw...${NC}"
            systemctl restart openclaw > /dev/null 2>&1
            echo -e "${GREEN}Khởi động lại hoàn tất! Cấu hình mới khả dụng.${NC}"
            ;;
    esac
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    read -p "Nhấn Enter để quay lại..."
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
        [1-9])
            execute_action $((key - 1))
            ;;
        0)
            execute_action 9
            ;;
        "")
            execute_action $current
            ;;
    esac
done
