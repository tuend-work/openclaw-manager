#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SSH BOOT & ONBOARDING
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# 1. Silent OCM Update Check
if [ -f "$MANAGER_DIR/scripts/check_update_silent.sh" ]; then
    bash "$MANAGER_DIR/scripts/check_update_silent.sh"
fi

# 2. Check Completeness of .env & openclaw.json (Onboarding)
ENV_FILE="$HOME/.openclaw/.env"
JSON_FILE="$HOME/.openclaw/openclaw.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Chờ First Boot Setup nếu đang chạy background
LOG_FILE="/var/log/ocm_first_boot.log"
if [ -f "$LOG_FILE" ] && ! grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE"; then
    echo -e "${YELLOW}⏳ OpenClaw đang được cài đặt trong lần khởi động đầu tiên...${NC}"
    echo -e "${YELLOW}Vui lòng chờ giây lát hoặc xem log tại: $LOG_FILE${NC}"
    for i in {1..60}; do
        if grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE" 2>/dev/null; then break; fi
        sleep 2
    done
fi

if [ -f "$ENV_FILE" ]; then
    UPDATE_REQUIRED=false
    source "$ENV_FILE"

    # KIỂM TRA MULTI-ACCOUNT TRONG JSON
    NUM_ACCOUNTS=$(jq '.channels.telegram.accounts | length' "$JSON_FILE" 2>/dev/null || echo 0)

    if [ "$NUM_ACCOUNTS" -eq 0 ]; then
        echo -e "\n${BLUE}================================================${NC}"
        echo -e "${YELLOW}   🔑 CẤU HÌNH CÁ NHÂN OPENCLAW (ONBOARDING)    ${NC}"
        echo -e "${BLUE}================================================${NC}"
        echo -e "${CYAN}Hệ thống phát hiện cấu hình Telegram chưa được thiết lập.${NC}"
        echo -ne "${YELLOW}➤ Nhập Telegram Bot Token cho tài khoản 'default':${NC} "
        read input_token
        
        if [ -n "$input_token" ]; then
            USER_ID=""
            echo -e "\n${MAGENTA}------------------------------------------------${NC}"
            echo -e "${BOLD}${WHITE}HƯỚNG DẪN LẤY ID TỰ ĐỘNG:${NC}"
            echo -e "1. Mở Telegram và tìm Bot bạn vừa dán token."
            echo -e "2. Nhấn ${YELLOW}/start${NC} hoặc gửi ${YELLOW}tin nhắn bất kỳ${NC} cho Bot."
            echo -e "${MAGENTA}------------------------------------------------${NC}"
            echo -e "${CYAN}⏳ Đang chờ tin nhắn từ bạn (Timeout 60s)...${NC}"

            for i in {1..12}; do
                RESPONSE=$(curl -s --max-time 5 "https://api.telegram.org/bot${input_token}/getUpdates")
                USER_ID=$(echo "$RESPONSE" | jq -r '.result[0].message.from.id // empty' 2>/dev/null)
                if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
                    echo -e "${GREEN}🎯 Đã nhận diện được User ID: ${BOLD}${WHITE}$USER_ID${NC}"
                    break
                fi
                echo -ne "${CYAN}.${NC}"
                sleep 5
            done

            [ -z "$USER_ID" ] || [ "$USER_ID" == "null" ] && USER_ID=""
            
            # Cập nhật trực tiếp vào openclaw.json thay vì chỉ .env
            jq --arg token "$input_token" --arg uid "$USER_ID" \
               '.channels.telegram.accounts.default = {botToken: $token, dmPolicy: "allowlist", allowFrom: (if $uid != "" then [$uid] else [] end)}' \
               "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
            
            echo -e "${GREEN}✅ Đã cấu hình tài khoản 'default' trong JSON.${NC}"
            UPDATE_REQUIRED=true
        fi
    fi

    # OpenRouter API Key
    if [[ "$OPENROUTER_API_KEY" == "your_openrouter_api_key" || -z "$OPENROUTER_API_KEY" ]]; then
        echo -ne "${YELLOW}➤ Nhập OpenRouter API Key (sk-or-...) [Enter để bỏ qua]:${NC} "
        read input_key
        if [ -n "$input_key" ]; then
            sed -i "s/^OPENROUTER_API_KEY=.*/OPENROUTER_API_KEY=$input_key/" "$ENV_FILE"
            echo -e "${GREEN}✅ Đã lưu OpenRouter API Key.${NC}"
        fi
        UPDATE_REQUIRED=true
    fi

    if $UPDATE_REQUIRED; then
        echo -e "${YELLOW}⚡ Đang khởi động lại dịch vụ...${NC}"
        openclaw config set channels.telegram.enabled true > /dev/null 2>&1
        export XDG_RUNTIME_DIR="/run/user/$UID"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
        openclaw gateway restart > /dev/null 2>&1
        echo -e "${GREEN}✅ Hoàn tất cấu hình onboarding!${NC}"
        echo -e "${BLUE}================================================${NC}"
        sleep 1
    fi
fi

# 3. Launch Menu
bash "$MANAGER_DIR/menu.sh"
