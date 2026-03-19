#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - CHANNELS MANAGEMENT (UI/UX SYNC)
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

show_telegram_menu() {
    while true; do
        BOT_TOKEN=$(get_env_val "TELEGRAM_BOT_TOKEN")
        USER_IDS=$(get_env_val "TELEGRAM_ALLOW_USER_IDS_VALUE")
        
        clear
        echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}CẤU HÌNH KÊNH TELEGRAM (ON/OFF)${NC}        ${CYAN}│${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
        echo -e " ${WHITE}●${NC} Bot Token: ${YELLOW}${BOT_TOKEN:-'Chưa thiết lập'}${NC}"
        echo -e " ${WHITE}●${NC} User IDs: ${YELLOW}${USER_IDS:-'Chưa thiết lập'}${NC}"
        echo -e "${CYAN}------------------------------------------------${NC}"
        echo -e " ${BOLD}${YELLOW}Chọn hạng mục cần chỉnh sửa:${NC}"
        echo ""
        echo -e "  ${WHITE}1.${NC} Thay đổi API Bot Token"
        echo -e "  ${WHITE}2.${NC} Cấu hình ID Người dùng / Nhóm (Allow IDs)"
        echo -e "  ${WHITE}0.${NC} Quay lại"
        echo ""
        echo -e "${CYAN}────────────────────────────────────────────────${NC}"
        read -p " Nhập lựa chọn: " tg_choice

        case $tg_choice in
            1)
                echo -ne "\n${YELLOW}➤ Nhập API Token mới (hoặc Enter để giữ nguyên):${NC} "
                read new_token
                if [ -n "$new_token" ]; then
                    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$new_token|" "$ENV_FILE"
                    echo -e "${GREEN}✅ Đã cập nhật Token.${NC}"
                    restart_gateway
                fi
                ;;
            2)
                echo -e "\n${CYAN}Gợi ý: Nhiều ID cách nhau bởi dấu phẩy.${NC}"
                echo -ne "${YELLOW}➤ Nhập danh sách IDs mới (hoặc Enter để giữ nguyên):${NC} "
                read new_ids
                if [ -n "$new_ids" ]; then
                    sed -i "s|^TELEGRAM_ALLOW_USER_IDS_VALUE=.*|TELEGRAM_ALLOW_USER_IDS_VALUE=$new_ids|" "$ENV_FILE"
                    echo -e "${GREEN}✅ Đã cập nhật danh sách IDs.${NC}"
                    restart_gateway
                fi
                ;;
            0) return ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ!${NC}"; sleep 1 ;;
        esac
    done
}

# Main Loop for manage_channels
while true; do
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}          ${BOLD}${WHITE}QUẢN LÝ KÊNH CHAT (CHANNELS)${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} Trạng thái OpenClaw: ${GREEN}Đang hoạt động${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e "  ${WHITE}1.${NC} ${BOLD}Telegram${NC} (Hỗ trợ cấu hình nhanh)"
    echo -e "  ${WHITE}2.${NC} ${GRAY}Other Channels (Manual Setup)${NC}"
    echo -e "  ${WHITE}0.${NC} Quay lại Menu chính"
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    read -p " Nhập lựa chọn: " choice

    case $choice in
        1)
            show_telegram_menu
            ;;
        2)
            echo -e "\n${MAGENTA}------------------------------------------------${NC}"
            echo -e "${YELLOW}💡 THÔNG BÁO:${NC}"
            echo -e "OCM Script hiện chỉ hỗ trợ giao diện cấu hình nhanh"
            echo -e "cho ${BOLD}Telegram${NC}. Các kênh khác (Discord, Slack, v.v.)"
            echo -e "vui lòng setup thủ công trong file config."
            echo -e "${MAGENTA}------------------------------------------------${NC}"
            read -p "Nhấn Enter để quay lại..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ!${NC}"
            sleep 1
            ;;
    esac
done
