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
BOLD='\033[1m'
NC='\033[0m'
BG_CYAN='\033[46m'

options=(
    "Kiểm tra trạng thái Gateway (Status)"
    "Xem log Gateway mới nhất (Logs)"
    "Danh sách thiết bị đã kết nối (Devices)"
    "Danh sách các AI Agents (Agents)"
    "Danh sách các Skills đã cài (Skills)"
    "Xem thông tin Dashboard (URL/Token)"
    "Xem nội dung cấu hình (Config View)"
    "Chạy kiểm tra hệ thống (Onboarding Check)"
    "Khởi động lại dịch vụ OpenClaw (Restart)"
    "Cập nhật OpenClaw Core lên bản mới nhất"
    "Kiểm tra trạng thái TẤT CẢ (Status All)"
    "Kiểm tra kết nối Kênh Chat (Probe Channels)"
    "Xem Log thời gian thực (Follow Logs)"
    "Kiểm tra sức khỏe Model (Models Status)"
    "Kiểm tra Port 18789 (Check Port Conflict)"
    "Cập nhật Script OCM (Update Manager)"
    "Quay lại Menu chính"
)

commands=(
    "openclaw gateway status"
    "openclaw logs --limit 20"
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
    "openclaw logs --follow"
    "openclaw models status"
    "lsof -i :18789"
    "bash \"$MANAGER_DIR/update_script.sh\""
    ""
)

current=0

# Clean up on exit
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_commands() {
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}LỆNH OPENCLAW THƯỜNG DÙNG${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-16]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        # For sub-menus, 1-16 are commands, last one (17) is Back
        [ $display_num -eq 17 ] && display_display="0" || display_display="$display_num"
        
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_display. ${options[$i]} ${NC}"
            if [ -n "${commands[$i]}" ]; then
                echo -e "     ${BLUE}→ ${commands[$i]}${NC}"
            fi
        else
            echo -e "     ${WHITE}$display_display. ${options[$i]}               ${NC}"
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Shortcut: [Enter]: Chạy | [0]: Quay lại${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

execute_cmd() {
    local index=$1
    if [ $index -eq 16 ]; then exit 0; fi # Option 0: Back
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    case $index in
        0) echo -e "${YELLOW}Chạy: openclaw gateway status${NC}"; openclaw gateway status ;;
        1) echo -e "${YELLOW}Chạy: openclaw logs --limit 20${NC}"; openclaw logs --limit 20 ;;
        2) echo -e "${YELLOW}Chạy: openclaw devices list${NC}"; openclaw devices list ;;
        3) echo -e "${YELLOW}Chạy: openclaw agents list${NC}"; openclaw agents list ;;
        4) echo -e "${YELLOW}Chạy: openclaw skills list${NC}"; openclaw skills list ;;
        5) echo -e "${YELLOW}Chạy: openclaw dashboard${NC}"; openclaw dashboard ;;
        6) echo -e "${YELLOW}Chạy: openclaw config view${NC}"; openclaw config view ;;
        7) echo -e "${YELLOW}Chạy: openclaw onboard --check${NC}"; openclaw onboard --check ;;
        8) echo -e "${YELLOW}Chạy: systemctl restart openclaw${NC}"; systemctl restart openclaw ;;
        9) echo -e "${YELLOW}Chạy: Cập nhật Core...${NC}"; curl -fsSL https://openclaw.ai/install.sh | bash ;;
        10) echo -e "${YELLOW}Chạy: openclaw status --all${NC}"; openclaw status --all ;;
        11) echo -e "${YELLOW}Chạy: openclaw channels status --probe${NC}"; openclaw channels status --probe ;;
        12) echo -e "${YELLOW}Chạy: openclaw logs --follow${NC}"; echo -e "${BLUE}(Nhấn Ctrl+C để dừng)${NC}"; openclaw logs --follow ;;
        13) echo -e "${YELLOW}Chạy: openclaw models status${NC}"; openclaw models status ;;
        14) echo -e "${YELLOW}Chạy: lsof -i :18789${NC}"; lsof -i :18789 2>/dev/null || netstat -tuln | grep 18789 ;;
        15) echo -e "${YELLOW}Chạy: Cập nhật công cụ OCM...${NC}"; bash "$MANAGER_DIR/update_script.sh" ;;
    esac
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    read -p "Nhấn Enter để tiếp tục..."
    tput civis
    clear
}

# Hide cursor
tput civis
clear

while true; do
    show_commands
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
            # For 10-15 we need more logic, but user requested 1-digit select
            # If user presses 1, we might need to wait for 0-5 to see if it's 10-15
            # Simplified: 1-9 direct, 0 for back.
            execute_cmd $((key - 1))
            ;;
        0) execute_cmd 16 ;;
        "") execute_cmd $current ;;
    esac
done
