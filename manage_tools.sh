#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - COMMON TOOLS (QUICK COMMANDS)
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

options=(
    "Kiểm tra trạng thái Gateway (Status)"
    "View Log Openclaw Realtime (Logs)"
    "Danh sách thiết bị kết nối (Devices)"
    "Danh sách các AI Agents (Agents)"
    "Danh sách các Skills đã cài (Skills)"
    "Xem thông tin Dashboard (URL)"
    "Xem nội dung cấu hình (Config)"
    "Chạy kiểm tra hệ thống (Onboarding)"
    "Khởi động lại dịch vụ OpenClaw"
    "Cập nhật OpenClaw Core (Update)"
    "Kiểm tra trạng thái TẤT CẢ (Status All)"
    "Kiểm tra kết nối Kênh Chat (Probe)"
    "Kiểm tra sức khỏe Model (Probe Models)"
    "Kiểm tra Port 18789 (Conflict)"
    "Cập nhật Script OCM (Update Manager)"
    "Bật/Tắt Auto-Approve Device (Cron)"
    "Gỡ cài đặt OpenClaw (Uninstall)"
    "Quay lại Menu chính"
)

commands=(
    "openclaw gateway status"
    "openclaw logs --follow"
    "openclaw devices list"
    "openclaw agents list"
    "openclaw skills list"
    "openclaw dashboard"
    "openclaw config view"
    "openclaw onboard --check"
    "systemctl restart openclaw"
    "curl -fsSL https://openclaw.ai/install.sh | bash"
    "openclaw status --all"
    "openclaw channels status --probe"
    "openclaw models status --probe --probe-provider openrouter --probe-timeout 60000"
    "lsof -i :18789"
    "bash \"$MANAGER_DIR/update_script.sh\""
    "toggle_cron"
    "openclaw uninstall --all --yes --non-interactive"
    ""
)

current=0

execute_cmd_sl() {
    local index=$1
    if [ $index -eq 17 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        15) # Toggle Cron
            echo -e "${YELLOW}Đang thiết lập Cronjob...${NC}"
            CRON_CMD="/usr/bin/openclaw devices approve --latest"
            if crontab -l 2>/dev/null | grep -q "openclaw devices approve"; then
                (crontab -l 2>/dev/null | grep -v "openclaw devices approve") | crontab -
                echo -e "${RED}Đã TẮT tự động duyệt thiết bị.${NC}"
            else
                (crontab -l 2>/dev/null; echo "* * * * * $CRON_CMD > /dev/null 2>&1") | crontab -
                echo -e "${GREEN}Đã BẬT tự động duyệt thiết bị (mỗi phút).${NC}"
            fi
            ;;
        *) # Direct command
            echo -e "${YELLOW}Đang thực thi: ${WHITE}${commands[$index]}${NC}"
            [ "$index" -eq 1 ] && echo -e "${BLUE}(Nhấn Ctrl+C để thoát log)${NC}"
            eval "${commands[$index]}"
            ;;
    esac
    
    pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "CÔNG CỤ & LỆNH ĐIỀU KHIỂN (TOOLS)"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 18 ] && display_num=0
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
            [ -n "${commands[$i]}" ] && [ $i -ne 15 ] && echo -e "     ${BLUE}→ ${commands[$i]}${NC}"
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
            [1-9]) execute_cmd_sl $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_cmd_sl $current ;;
        esac
    fi
done