#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - MAIN MENU
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}➤ Lỗi: Vui lòng chạy lệnh này với quyền root (sudo ocm)${NC}"
    exit 1
fi

# Tự động chạy Wizard nếu phát hiện lần đầu chưa cấu hình
WIZARD_DONE="$HOME/.openclaw/.wizard_done"
if [ ! -f "$WIZARD_DONE" ] && [ -f "$MANAGER_DIR/SetupWizard.sh" ]; then
    echo -e "${YELLOW}🔍 Phát hiện hệ thống chưa hoàn tất cấu hình nhanh.${NC}"
    echo -e "${CYAN}🚀 Đang khởi động Setup Wizard (Trình khởi tạo nhanh)...${NC}"
    sleep 1.5
    exec bash "$MANAGER_DIR/SetupWizard.sh"
    exit 0
fi

IP_ADDR=$(hostname -I | awk '{print $1}')
OPENCLAW_VER=$(openclaw --version 2>/dev/null | awk '{print $2}' || echo "N/A")
OCM_VER="${OCM_VERSION:-N/A}"
options=(
    "Domain & SSL (Tên miền)"
    "AI Agents (Agents)"
    "Channels (Kênh Chat)"
    "Models (AI Models)"
    "System Logs (Nhật ký)"
    "Tools (Công cụ)"
    "Settings (Cấu hình)"
    "Backup & Restore (Sao lưu)"
    "Exit (Thoát)"
)

current=0
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

execute_module() {
    local index=$1
    tput cnorm
    case $index in
        0) bash "$MANAGER_DIR/manage_domain.sh" ;;
        1) bash "$MANAGER_DIR/manage_ai.sh" ;;
        2) bash "$MANAGER_DIR/manage_channels.sh" ;;
        3) bash "$MANAGER_DIR/manage_models.sh" ;;
        4) bash "$MANAGER_DIR/manage_logs.sh" ;;
        5) bash "$MANAGER_DIR/manage_tools.sh" ;;
        6) bash "$MANAGER_DIR/manage_settings.sh" ;;
        7) bash "$MANAGER_DIR/manage_backup.sh" ;;
        8) exit 0 ;;
    esac
    tput civis
}

while true; do
    gather_system_stats
    clear
    show_header "WELCOME TO OPEN-CLAW MANAGER"
    echo -e " ${WHITE}●${NC} OC: ${MAGENTA}${OPENCLAW_VER}${NC} | OCM: ${MAGENTA}${OCM_VER}${NC} | IP: ${BLUE}${IP_ADDR}${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 11 ] && display_num=0
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${options[$i]}${NC}"
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Enter: Chọn | Mũi tên: Di chuyển | 0: Thoát${NC}"

    tput civis
    if read -rsn1 -t 3 key; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                    "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
                esac ;;
            [1-9]) execute_module $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_module $current ;;
        esac
    fi
done
