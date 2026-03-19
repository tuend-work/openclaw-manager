#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - CHANNELS V2 (ADVANCED)
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"
ENV_FILE="$HOME/.openclaw/.env"

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
BG_CYAN='\033[46m'
NC='\033[0m'

# Export env for systemctl --user
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Helper function to restart gateway
restart_gateway() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway để áp dụng thay đổi...${NC}"
    openclaw gateway restart > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Đã áp dụng cấu hình mới thành công!${NC}"
    else
        echo -e "${RED}❌ Có lỗi khi khởi động lại dịch vụ.${NC}"
    fi
    sleep 1
}

# Helper to get current value
get_env_val() {
    local key=$1
    if [ -f "$ENV_FILE" ]; then
        grep "^${key}=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'"
    else
        echo ""
    fi
}

# Sub-menu for Telegram Quick Config
show_telegram_quick_config() {
    local options=("API Bot Token" "Allow User / Group IDs" "Back (Quay lại)")
    local current=0

    while true; do
        BOT_TOKEN=$(get_env_val "TELEGRAM_BOT_TOKEN")
        USER_IDS=$(get_env_val "TELEGRAM_ALLOW_USER_IDS_VALUE")
        
        clear
        echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}CẤU HÌNH NHANH TELEGRAM (QUICK)${NC}        ${CYAN}│${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
        echo -e " ${WHITE}●${NC} Bot Token: ${YELLOW}${BOT_TOKEN:-'Chưa thiết lập'}${NC}"
        echo -e " ${WHITE}●${NC} User IDs: ${YELLOW}${USER_IDS:-'Chưa thiết lập'}${NC}"
        echo -e "${CYAN}------------------------------------------------${NC}"
        echo ""

        for i in "${!options[@]}"; do
            display_num=$((i + 1))
            [ $display_num -eq 3 ] && display_num=0
            if [ "$i" -eq "$current" ]; then
                echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
            else
                echo -e "     ${WHITE}$display_num. ${options[$i]}${NC}"
            fi
        done
        echo ""
        echo -e "${CYAN}────────────────────────────────────────────────${NC}"

        tput civis
        if read -rsn1 -t 5 key; then
            case "$key" in
                $'\x1b')
                    read -rsn2 -t 0.1 next_key
                    case "$next_key" in
                        "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                        "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
                    esac ;;
                1) execute_tg_action 0 ;;
                2) execute_tg_action 1 ;;
                0|3) return ;;
                "") # Enter
                    execute_tg_action $current
                    [ $current -eq 2 ] && return ;;
            esac
        fi
    done
}

execute_tg_action() {
    tput cnorm
    case $1 in
        0)
            echo -ne "\n${YELLOW}➤ Nhập API Token mới:${NC} "; read new_token
            if [ -n "$new_token" ]; then
                sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$new_token|" "$ENV_FILE"
                echo -e "${GREEN}✅ Đã cập nhật Token.${NC}"; restart_gateway
            fi ;;
        1)
            echo -e "\n${CYAN}Gợi ý: Nhiều ID cách nhau bởi dấu phẩy.${NC}"
            echo -ne "${YELLOW}➤ Nhập danh sách IDs mới:${NC} "; read new_ids
            if [ -n "$new_ids" ]; then
                sed -i "s|^TELEGRAM_ALLOW_USER_IDS_VALUE=.*|TELEGRAM_ALLOW_USER_IDS_VALUE=$new_ids|" "$ENV_FILE"
                echo -e "${GREEN}✅ Đã cập nhật danh sách IDs.${NC}"; restart_gateway
            fi ;;
    esac
}

# Main Loop for manage_channels
main_options=(
    "Cấu hình nhanh Telegram (Quick Config)"
    "Danh sách các Kênh / Tài khoản (List Accounts)"
    "Trạng thái kết nối (Status Probe)"
    "Kiểm tra khả năng Kênh (Capabilities)"
    "Tìm kiếm Channel ID (Resolve Names)"
    "Xem nhật ký Kênh (Channels Logs)"
    "Quay lại Menu chính"
)
main_current=0

while true; do
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}           ${BOLD}${WHITE}QUẢN LÝ KÊNH CHAT - CHANNELS V2${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} Trạng thái OpenClaw: ${GREEN}Đang hoạt động${NC}"
    echo -e " ${WHITE}●${NC} Docs: ${GRAY}https://docs.openclaw.ai/cli/channels${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-6, 0]:${NC}"
    echo ""

    for i in "${!main_options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 7 ] && display_num=0
        if [ "$i" -eq "$main_current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${main_options[$i]} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${main_options[$i]}${NC}"
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"

    tput civis
    if read -rsn1 -t 5 key; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") main_current=$(( (main_current - 1 + ${#main_options[@]}) % ${#main_options[@]} )) ;;
                    "[B") main_current=$(( (main_current + 1) % ${#main_options[@]} )) ;;
                esac ;;
            1) show_telegram_quick_config ;;
            2) tput cnorm; echo -e "${CYAN}Danh sách các kênh & tài khoản:${NC}"; openclaw channels list ;;
            3) tput cnorm; echo -e "${CYAN}Kiểm tra trạng thái kết nối...${NC}"; openclaw channels status ;;
            4) tput cnorm; echo -e "${CYAN}Kiểm tra khả năng phản hồi (Capabilities)...${NC}"; openclaw channels capabilities ;;
            5) 
                tput cnorm; echo -n "Chọn kênh (telegram/slack/discord): "; read ch_name
                echo -n "Nhập tên cần tìm (VD: #general): "; read r_name
                openclaw channels resolve --channel "$ch_name" "$r_name" ;;
            6) tput cnorm; echo -e "${CYAN}Xem nhật ký hoạt động của các kênh...${NC}"; openclaw channels logs --channel all ;;
            0|7) exit 0 ;;
            "") # Enter
                case $main_current in
                    0) show_telegram_quick_config ;;
                    1) tput cnorm; openclaw channels list ;;
                    2) tput cnorm; openclaw channels status ;;
                    3) tput cnorm; openclaw channels capabilities ;;
                    4) tput cnorm; echo -n "Channel: "; read ch_name; echo -n "Name: "; read r_name; openclaw channels resolve --channel "$ch_name" "$r_name" ;;
                    5) tput cnorm; openclaw channels logs --channel all ;;
                    6) exit 0 ;;
                esac ;;
        esac
        [ "$key" != "" ] && [ "$key" != "$'\x1b'" ] && [ "$key" != "1" ] && { echo -e "\n${YELLOW}Nhấn Enter để tiếp tục...${NC}"; read; }
    fi
done
