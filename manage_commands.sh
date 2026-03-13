#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BG_BLUE='\033[44m'

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
    "lsof -i :18789 หรือ netstat"
    ""
)

current=0

show_commands() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}       LỆNH OPENCLAW THƯỜNG DÙNG (OCM)          ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${CYAN}Sử dụng [↑/↓] để di chuyển, Enter để chạy lệnh:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_BLUE}${YELLOW} ▶ ${options[$i]} ${NC}"
            if [ -n "${commands[$i]}" ]; then
                echo -e "     ${BLUE}→ ${commands[$i]}${NC}"
            fi
        else
            echo -e "     ${options[$i]}"
        fi
    done
    echo ""
    echo -e "${BLUE}================================================${NC}"
}

while true; do
    show_commands
    read -rsn3 key
    case "$key" in
        $'\x1b[A') # Up arrow
            current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} ))
            ;;
        $'\x1b[B') # Down arrow
            current=$(( (current + 1) % ${#options[@]} ))
            ;;
        "") # Enter key
            echo -e "${BLUE}------------------------------------------------${NC}"
            case $current in
                0) echo -e "${YELLOW}Chạy: openclaw gateway status${NC}"; openclaw gateway status ;;
                1) echo -e "${YELLOW}Chạy: openclaw logs --limit 20${NC}"; openclaw logs --limit 20 ;;
                2) echo -e "${YELLOW}Chạy: openclaw devices list${NC}"; openclaw devices list ;;
                3) echo -e "${YELLOW}Chạy: openclaw agents list${NC}"; openclaw agents list ;;
                4) echo -e "${YELLOW}Chạy: openclaw skills list${NC}"; openclaw skills list ;;
                5) echo -e "${YELLOW}Chạy: openclaw dashboard${NC}"; openclaw dashboard ;;
                6) echo -e "${YELLOW}Chạy: openclaw config view${NC}"; openclaw config view ;;
                7) echo -e "${YELLOW}Chạy: openclaw onboard --check${NC}"; openclaw onboard --check ;;
                8) echo -e "${YELLOW}Chạy: systemctl restart openclaw${NC}"; systemctl restart openclaw ;;
                9) echo -e "${YELLOW}Chạy: Cập nhật OpenClaw Core...${NC}"; curl -fsSL https://openclaw.ai/install.sh | bash ;;
                10) echo -e "${YELLOW}Chạy: openclaw status --all${NC}"; openclaw status --all ;;
                11) echo -e "${YELLOW}Chạy: openclaw channels status --probe${NC}"; openclaw channels status --probe ;;
                12) echo -e "${YELLOW}Chạy: openclaw logs --follow${NC}"; echo -e "${BLUE}(Nhấn Ctrl+C để dừng)${NC}"; openclaw logs --follow ;;
                13) echo -e "${YELLOW}Chạy: openclaw models status${NC}"; openclaw models status ;;
                14) echo -e "${YELLOW}Chạy: lsof -i :18789${NC}"; lsof -i :18789 2>/dev/null || netstat -tuln | grep 18789 ;;
                15) exit 0 ;;
            esac
            echo -e "${BLUE}------------------------------------------------${NC}"
            read -p "Nhấn Enter để tiếp tục..."
            ;;
    esac
done

