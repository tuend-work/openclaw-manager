#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SSH BOOT & ONBOARDING
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# 1. Silent OCM Update
if [ -d "$MANAGER_DIR/.git" ]; then
    cd "$MANAGER_DIR"
    git fetch --all > /dev/null 2>&1 &
    FETCH_PID=$!
    sleep 3
    kill $FETCH_PID 2>/dev/null
    wait $FETCH_PID 2>/dev/null
    LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null)
    REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null)
    if [ -n "$REMOTE_HASH" ] && [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        git reset --hard origin/main > /dev/null 2>&1
        chmod +x "$MANAGER_DIR"/*.sh > /dev/null 2>&1
    fi
fi

# 2. Check Completeness of .env (Onboarding)
ENV_FILE="$HOME/.openclaw/.env"
OCM_ENV_FILE="$MANAGER_DIR/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Chờ First Boot Setup nếu đang chạy background
if [ -f "$LOG_FILE" ] && ! grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE"; then
    echo -e "${YELLOW}⏳ OpenClaw đang được cài đặt trong lần khởi động đầu tiên...${NC}"
    echo -e "${YELLOW}Vui lòng chờ giây lát hoặc xem log tại: /var/log/ocm_first_boot.log${NC}"
    # Đợi tối đa 30s hoặc cho đến khi log báo xong
    for i in {1..30}; do
        if grep -q "FIRST BOOT SETUP HOÀN TẤT" "/var/log/ocm_first_boot.log" 2>/dev/null; then
            break
        fi
        sleep 1
    done
fi

if [ -f "$ENV_FILE" ]; then
    UPDATE_REQUIRED=false
    source "$ENV_FILE"

    # Định nghĩa các giá trị mẫu cần hỏi người dùng
    # 1. Telegram Bot Token
    if [[ "$TELEGRAM_BOT_TOKEN" == "123456789:ABCDefghIJKLmnopQRSTuvwxYZ" || -z "$TELEGRAM_BOT_TOKEN" ]]; then
        echo -e "\n${BLUE}================================================${NC}"
        echo -e "${YELLOW}   🔑 CẤU HÌNH CÁ NHÂN OPENCLAW (ONBOARDING)    ${NC}"
        echo -e "${BLUE}================================================${NC}"
        echo -e "${CYAN}Hệ thống phát hiện cấu hình Telegram chưa được thiết lập.${NC}"
        echo -n "Nhập Telegram Bot Token (hoặc Enter để bỏ qua): "
        read input_token
        if [ -n "$input_token" ]; then
            sed -i "s/^TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=$input_token/" "$ENV_FILE"
            echo -e "${GREEN}✅ Đã lưu Telegram Token.${NC}"
        fi
        UPDATE_REQUIRED=true
    fi

    # 2. OpenRouter API Key (Dùng làm Key AI chính)
    if [[ "$OPENROUTER_API_KEY" == "sk-or-v1-xxxxxxxxxxxx" || -z "$OPENROUTER_API_KEY" ]]; then
        echo -n "Nhập OpenRouter API Key (sk-or-...) hoặc Enter để bỏ qua: "
        read input_key
        if [ -n "$input_key" ]; then
            sed -i "s/^OPENROUTER_API_KEY=.*/OPENROUTER_API_KEY=$input_key/" "$ENV_FILE"
            echo -e "${GREEN}✅ Đã lưu OpenRouter API Key.${NC}"
        fi
        UPDATE_REQUIRED=true
    fi

    # 3. Telegram User IDs
    if [[ "$TELEGRAM_ALLOW_USER_IDS_VALUE" == "12345678" || -z "$TELEGRAM_ALLOW_USER_IDS_VALUE" ]]; then
        echo -n "Nhập ID người dùng Telegram được phép chat (cách nhau bởi phím cách): "
        read input_ids
        if [ -n "$input_ids" ]; then
            sed -i "s/^TELEGRAM_ALLOW_USER_IDS_VALUE=.*/TELEGRAM_ALLOW_USER_IDS_VALUE=$input_ids/" "$ENV_FILE"
            echo -e "${GREEN}✅ Đã lưu danh sách Telegram IDs.${NC}"
        fi
        UPDATE_REQUIRED=true
    fi

    if $UPDATE_REQUIRED; then
        echo -e "${YELLOW}⚡ Đang cập nhật model và khởi động lại dịch vụ...${NC}"
        openclaw config set channels.telegram.enabled true > /dev/null 2>&1
        openclaw gateway restart > /dev/null 2>&1
        echo -e "${GREEN}✅ Hoàn tất cấu hình onboarding!${NC}"
        echo -e "${BLUE}================================================${NC}"
        sleep 1
    fi
fi

# 3. Launch Menu
bash "$MANAGER_DIR/menu.sh"
