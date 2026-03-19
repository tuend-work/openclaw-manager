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
    # 1. Telegram Bot Token & Auto User ID Detection
    if [[ "$TELEGRAM_BOT_TOKEN" == "your_telegram_bot_token" || -z "$TELEGRAM_BOT_TOKEN" ]]; then
        echo -e "\n${BLUE}================================================${NC}"
        echo -e "${YELLOW}   🔑 CẤU HÌNH CÁ NHÂN OPENCLAW (ONBOARDING)    ${NC}"
        echo -e "${BLUE}================================================${NC}"
        echo -e "${CYAN}Hệ thống phát hiện cấu hình Telegram chưa được thiết lập.${NC}"
        echo -ne "${YELLOW}➤ Nhập Telegram Bot Token:${NC} "
        read input_token
        
        if [ -n "$input_token" ]; then
            sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$input_token|" "$ENV_FILE"
            echo -e "${GREEN}✅ Đã lưu Telegram Token.${NC}"
            
            echo -e "\n${MAGENTA}------------------------------------------------${NC}"
            echo -e "${BOLD}${WHITE}HƯỚNG DẪN LẤY ID TỰ ĐỘNG:${NC}"
            echo -e "1. Mở Telegram và tìm Bot bạn vừa tạo."
            echo -e "2. Nhấn ${YELLOW}/start${NC} hoặc gửi ${YELLOW}bất kỳ tin nhắn nào${NC} cho Bot."
            echo -e "${MAGENTA}------------------------------------------------${NC}"
            echo -e "${CYAN}⏳ Đang chờ tin nhắn từ bạn (Timeout 60s)...${NC}"

            # Polling Telegram API to get User ID
            USER_ID=""
            for i in {1..12}; do
                # Gọi API getUpdates
                RESPONSE=$(curl -s --max-time 5 "https://api.telegram.org/bot${input_token}/getUpdates")
                
                # Check nếu tin nhắn hợp lệ (dùng jq để parse)
                USER_ID=$(echo "$RESPONSE" | jq -r '.result[0].message.from.id // empty' 2>/dev/null)
                
                if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
                    echo -e "${GREEN}🎯 Đã nhận diện được User ID: ${BOLD}${WHITE}$USER_ID${NC}"
                    sed -i "s|^TELEGRAM_ALLOW_USER_IDS_VALUE=.*|TELEGRAM_ALLOW_USER_IDS_VALUE=$USER_ID|" "$ENV_FILE"
                    echo -e "${GREEN}✅ Đã tự động cấu hình quyền truy cập cho ID này.${NC}"
                    # Cập nhật biến local để các bước sau không hỏi lại
                    TELEGRAM_ALLOW_USER_IDS_VALUE="$USER_ID"
                    break
                fi
                echo -ne "${GRAY}.${NC}"
                sleep 5
            done

            if [ -z "$USER_ID" ] || [ "$USER_ID" == "null" ]; then
                echo -e "\n${RED}⚠️  Không tìm thấy tin nhắn hoặc quá thời gian chờ.${NC}"
                echo -e "${YELLOW}Bạn sẽ cần nhập ID thủ công ở bước sau.${NC}"
            fi
        fi
        UPDATE_REQUIRED=true
    fi

    # 3. Telegram User IDs (Xác nhận và nhập thêm nếu cần)
    if [ "$UPDATE_REQUIRED" = true ]; then
        # Nếu đã lấy được ID tự động thì hiện ra cho người dùng biết
        CURRENT_IDS=""
        if [[ -n "$TELEGRAM_ALLOW_USER_IDS_VALUE" && "$TELEGRAM_ALLOW_USER_IDS_VALUE" != "your_telegram_allow_user_ids_value" ]]; then
            CURRENT_IDS="$TELEGRAM_ALLOW_USER_IDS_VALUE"
            PROMPT_TEXT="➤ ID hiện tại là [${BOLD}${WHITE}$CURRENT_IDS${NC}]. Nhập thêm các ID khác (cách nhau dấu phẩy) hoặc Enter để giữ nguyên:"
        else
            PROMPT_TEXT="➤ Nhập danh sách ID Telegram được phép chat (cách nhau dấu phẩy):"
        fi

        echo -ne "${YELLOW}$PROMPT_TEXT${NC} "
        read input_ids
        
        if [ -n "$input_ids" ]; then
            # Nếu đã có ID cũ thì cộng dồn vào
            if [ -n "$CURRENT_IDS" ]; then
                # Chuyển dấu phẩy thành dấu cách nếu OpenClaw yêu cầu dấu cách, 
                # hoặc giữ nguyên nếu yêu cầu dấu phẩy. Ở đây tôi giữ theo yêu cầu của bạn.
                FINAL_IDS="$CURRENT_IDS,$input_ids"
                # Xử lý trường hợp người dùng nhập thừa dấu phẩy
                FINAL_IDS=$(echo "$FINAL_IDS" | sed 's/,,/,/g' | sed 's/^,//' | sed 's/,$//')
            else
                FINAL_IDS="$input_ids"
            fi
            
            sed -i "s|^TELEGRAM_ALLOW_USER_IDS_VALUE=.*|TELEGRAM_ALLOW_USER_IDS_VALUE=$FINAL_IDS|" "$ENV_FILE"
            echo -e "${GREEN}✅ Đã cập nhật danh sách IDs: ${BOLD}${WHITE}$FINAL_IDS${NC}"
        fi
    fi


    # 2. OpenRouter API Key (Dùng làm Key AI chính)
    if [[ "$OPENROUTER_API_KEY" == "your_openrouter_api_key" || -z "$OPENROUTER_API_KEY" ]]; then
        echo -n "Nhập OpenRouter API Key (sk-or-...) hoặc Enter để bỏ qua: "
        read input_key
        if [ -n "$input_key" ]; then
            sed -i "s/^OPENROUTER_API_KEY=.*/OPENROUTER_API_KEY=$input_key/" "$ENV_FILE"
            echo -e "${GREEN}✅ Đã lưu OpenRouter API Key.${NC}"
        fi
        UPDATE_REQUIRED=true
    fi


    if $UPDATE_REQUIRED; then
        echo -e "${YELLOW}⚡ Đang cập nhật model và khởi động lại dịch vụ...${NC}"
        openclaw config set channels.telegram.enabled true > /dev/null 2>&1
        openclaw gateway restart > /dev/null 2>&1
        openclaw channels status --probe  > /dev/null 2>&1
        echo -e "${GREEN}✅ Hoàn tất cấu hình onboarding!${NC}"
        echo -e "${BLUE}================================================${NC}"
        sleep 1
    fi
fi

# 3. Launch Menu
bash "$MANAGER_DIR/menu.sh"
