#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - CHANNELS MANAGEMENT
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"
ENV_FILE="$HOME/.openclaw/.env"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Export env for systemctl --user
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Function to restart gateway to apply changes
restart_gateway() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway để áp dụng thay đổi...${NC}"
    openclaw gateway restart > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Gateway đã được khởi động lại thành công!${NC}"
    else
        echo -e "${RED}❌ Có lỗi khi khởi động lại Gateway.${NC}"
    fi
    sleep 1
}

# Function to get current value from .env
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
        echo -e "${BLUE}================================================${NC}"
        echo -e "${YELLOW}       QUẢN LÝ KÊNH TELEGRAM (ON/OFF)          ${NC}"
        echo -e "${BLUE}================================================${NC}"
        echo -e " 1. API Token "
        echo -e "    ${GRAY}Hiện tại: ${CYAN}${BOT_TOKEN:-'Chưa thiết lập'}${NC}"
        echo -e " 2. Allow User / Group IDs "
        echo -e "    ${GRAY}Hiện tại: ${CYAN}${USER_IDS:-'Chưa thiết lập'}${NC}"
        echo -e " 3. Quay lại"
        echo -e "${BLUE}────────────────────────────────────────────────${NC}"
        read -p "Chọn tác vụ [1-3]: " tg_choice

        case $tg_choice in
            1)
                echo -ne "${YELLOW}➤ Nhập API Token mới (hoặc Enter để giữ nguyên):${NC} "
                read new_token
                if [ -n "$new_token" ]; then
                    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$new_token|" "$ENV_FILE"
                    echo -e "${GREEN}✅ Đã cập nhật Token.${NC}"
                    restart_gateway
                fi
                ;;
            2)
                echo -e "${CYAN}Gợi ý: Nhiều ID cách nhau bởi dấu phẩy.${NC}"
                echo -ne "${YELLOW}➤ Nhập danh sách IDs mới (hoặc Enter để giữ nguyên):${NC} "
                read new_ids
                if [ -n "$new_ids" ]; then
                    sed -i "s|^TELEGRAM_ALLOW_USER_IDS_VALUE=.*|TELEGRAM_ALLOW_USER_IDS_VALUE=$new_ids|" "$ENV_FILE"
                    echo -e "${GREEN}✅ Đã cập nhật danh sách IDs.${NC}"
                    restart_gateway
                fi
                ;;
            3) return ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ!${NC}"; sleep 1 ;;
        esac
    done
}

while true; do
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}          QUẢN LÝ KÊNH CHAT (CHANNELS)          ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e " 1. ${BOLD}Telegram${NC} (Đã hỗ trợ config nhanh)"
    echo -e " 2. Other Channels (Manual Setup)"
    echo -e " 3. Thoát (Quay lại Menu OCM)"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    read -p "Chọn tác vụ [1-3]: " choice

    case $choice in
        1)
            show_telegram_menu
            ;;
        2)
            echo -e "\n${MAGENTA}------------------------------------------------${NC}"
            echo -e "${YELLOW}💡 THÔNG BÁO:${NC}"
            echo -e "OCM Script hiện chỉ hỗ trợ cấu hình nhanh cho ${BOLD}Telegram${NC}."
            echo -e "Các kênh khác (Discord, Slack, v.v.) vui lòng setup"
            echo -e "thủ công theo hướng dẫn chính thức của OpenClaw."
            echo -e "${MAGENTA}------------------------------------------------${NC}"
            read -p "Nhấn Enter để quay lại..."
            ;;
        3)
            exit 0
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ!${NC}"
            sleep 1
            ;;
    esac
done
