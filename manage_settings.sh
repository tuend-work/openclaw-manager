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
    echo -e "${YELLOW}⏳ Đang gửi yêu cầu làm mới Gateway...${NC}"
    systemctl restart openclaw-gateway > /dev/null 2>&1
    echo -e "${GREEN}✅ Đã gửi lệnh làm mới dịch vụ!${NC}"
    sleep 0.5
}

options=(
    "Cổng Gateway (gateway.port)"
    "Gateway Token (Auth Token)"
    "Allowed Origins (CORS)"
    "SetupWizard (Trình khởi tạo nhanh)"
    "Khởi động lại OpenClaw"
    "Quay lại Menu chính"
)

current=0

execute_action() {
    local index=$1
    if [ $index -eq 5 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) echo -n "Nhập Cổng mới (Mặc định 18789): "; read val
           [ -n "$val" ] && openclaw config set gateway.port "$val" && restart_gateway ;;
        1) echo -n "Nhập Gateway Token bảo mật mới: "; read val
           if [ -n "$val" ]; then
                ENV_PATH="/root/.openclaw/.env"
                if [ ! -f "$ENV_PATH" ]; then
                    # Fallback to local .env if root one missing
                    ENV_PATH="$MANAGER_DIR/.env"
                fi

                if [ -f "$ENV_PATH" ]; then
                    if grep -q "^OPENCLAW_GATEWAY_TOKEN=" "$ENV_PATH"; then
                        sed -i "s|^OPENCLAW_GATEWAY_TOKEN=.*|OPENCLAW_GATEWAY_TOKEN=\"$val\"|" "$ENV_PATH"
                    else
                        echo "OPENCLAW_GATEWAY_TOKEN=\"$val\"" >> "$ENV_PATH"
                    fi
                    echo -e "${GREEN}✅ Đã cập nhật Token mới vào file $ENV_PATH!${NC}"
                    
                    echo -e "${YELLOW}🧹 Đang dọn dẹp Sessions và Devices cũ...${NC}"
                    openclaw sessions reset --all --yes 2>/dev/null
                    openclaw devices remove --all --yes 2>/dev/null
                    echo -e "${GREEN}✅ Đã dọn dẹp sạch sẽ!${NC}"
                    
                    restart_gateway
                else
                    echo -e "${RED}❌ Lỗi: Không tìm thấy file .env tại bất kỳ đâu.${NC}"
                fi
           fi ;;
        2) echo -n "Nhập Domain (CORS allowedOrigins): "; read val
           [ -n "$val" ] && openclaw config set gateway.controlUi.allowedOrigins "[\"$val\"]" && restart_gateway ;;
        3) bash "$MANAGER_DIR/SetupWizard.sh" ;;
        4) systemctl restart openclaw > /dev/null 2>&1; echo -e "${GREEN}Restart hoàn tất!${NC}" ;;
    esac
    pause_menu
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
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
fi
