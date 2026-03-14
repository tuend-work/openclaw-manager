#!/bin/bash

# Path to the manager directory (automatically detect real script directory, handles symlinks)
REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"


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
BG_CYAN='\033[46m'
BG_BLACK='\033[40m'

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}➤ Lỗi: Vui lòng chạy lệnh này với quyền root (sudo ocm)${NC}"
    exit 1
fi

# Caching system info to prevent lag
IP_ADDR=$(hostname -I | awk '{print $1}')
OPENCLAW_VER=$(openclaw --version 2>/dev/null | awk '{print $2}' || echo "N/A")

# Load variables from OpenClaw .env
DOMAIN_NAME=$(hostname)
GATEWAY_TOKEN="N/A"
if [ -f "/root/.openclaw/.env" ]; then
    DOMAIN_NAME=$(grep "^DOMAIN_NAME=" /root/.openclaw/.env | cut -d'=' -f2 | tr -d '"'\'' ')
    GATEWAY_TOKEN=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /root/.openclaw/.env | cut -d'=' -f2 | tr -d '"'\'' ')
fi
[ -z "$DOMAIN_NAME" ] && DOMAIN_NAME=$(hostname)

options=(
    "Domain & SSL (Quản lý Tên miền & SSL)"
    "AI Agents (Quản lý AI Agents)"
    "Channels (Quản lý Kênh Chat)"
    "Versions (Quản lý Phiên bản)"
    "System Logs (Nhật ký Hệ thống)"
    "Services (Điều khiển Dịch vụ)"
    "Update OCM Script (Cập nhật Script OCM)"
    "Tools (Công cụ)"
    "Backup & Restore (Sao lưu & Khôi phục)"
    "Exit (Thoát)"
)

current=0

# Clean up on exit (restore cursor)
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_menu() {
    # Move cursor to top-left instead of clear to reduce flicker
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}WELCOME TO OPEN-CLAW MANAGER${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} CPU: ${YELLOW}${SYS_CPU}${NC} | RAM: ${YELLOW}${SYS_RAM}${NC}"
    echo -e " ${WHITE}●${NC} Disk: ${YELLOW}${SYS_DISK}${NC} | Uptime: ${YELLOW}${SYS_UPTIME}${NC}"
    echo -e " ${WHITE}●${NC} Net: ${GREEN}↓ ${SYS_NET_IN} MB/s${NC} | ${RED}↑ ${SYS_NET_OUT} MB/s${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${WHITE}●${NC} Dashboard: ${CYAN}https://${DOMAIN_NAME}/#token=${GATEWAY_TOKEN}${NC}"
    echo -e " ${WHITE}●${NC} OC: ${MAGENTA}${OPENCLAW_VER}${NC} | OCM: ${MAGENTA}v2.1.0${NC} | IP: ${BLUE}${IP_ADDR}${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 10 ] && display_num=0
        
        # Colorize the Vietnamese description in parentheses
        item_text="${options[$i]}"
        if [[ "$item_text" =~ (.*)(\(.*\))(.*) ]]; then
            colored_text="${BASH_REMATCH[1]}${GRAY}${BASH_REMATCH[2]}${NC}${BASH_REMATCH[3]}"
        else
            colored_text="$item_text"
        fi

        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${colored_text} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${colored_text}               ${NC}" 
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Shortcut: [Enter]: Chọn | [0]: Thoát${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

# Function to execute module based on index
execute_module() {
    local index=$1
    tput cnorm
    case $index in
        0) bash "$MANAGER_DIR/manage_domain.sh" ;;
        1) bash "$MANAGER_DIR/manage_ai.sh" ;;
        2) bash "$MANAGER_DIR/manage_channels.sh" ;;
        3) bash "$MANAGER_DIR/manage_versions.sh" ;;
        4) bash "$MANAGER_DIR/manage_logs.sh" ;;
        5) bash "$MANAGER_DIR/manage_services.sh" ;;
        6) bash "$MANAGER_DIR/update_script.sh" ;;
        7) bash "$MANAGER_DIR/manage_commands.sh" ;;
        8) bash "$MANAGER_DIR/manage_backup.sh" ;;
        9) exit 0 ;;
    esac
    tput civis
    clear
}

gather_system_stats() {
    SYS_RAM=$(free -m | awk 'NR==2{printf "%.1fGB / %.1fGB", $3/1024, $2/1024}')
    SYS_DISK=$(df -h / | awk '$NF=="/"{printf "%s / %s", $3, $2}')
    SYS_UPTIME=$(uptime -p | sed 's/^up //')
    local cpu1=($(awk '/^cpu / {print $2+$3+$4+$6+$7+$8+$9, $5}' /proc/stat))
    local net1=($(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev))
    sleep 0.2
    local cpu2=($(awk '/^cpu / {print $2+$3+$4+$6+$7+$8+$9, $5}' /proc/stat))
    local net2=($(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev))
    local active=$((cpu2[0] - cpu1[0]))
    local idle=$((cpu2[1] - cpu1[1]))
    local total=$((active + idle + 1))
    SYS_CPU=$(awk -v act="$active" -v tot="$total" -v cores="$(nproc 2>/dev/null || echo 1)" 'BEGIN {printf "%.1f%% (%s Core)", act * 100 / tot, cores}')
    SYS_NET_IN=$(awk -v r1="${net1[0]:-0}" -v r2="${net2[0]:-0}" 'BEGIN {printf "%.2f", (r2 - r1) * 5 / 1048576}')
    SYS_NET_OUT=$(awk -v t1="${net1[1]:-0}" -v t2="${net2[1]:-0}" 'BEGIN {printf "%.2f", (t2 - t1) * 5 / 1048576}')
}

# Hide cursor
tput civis
clear # Initial clear
gather_system_stats

while true; do
    show_menu
    if read -rsn1 -t 2 key; then
        case "$key" in
            # Arrow keys starting with escape
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") # Up arrow
                        current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} ))
                        ;;
                    "[B") # Down arrow
                        current=$(( (current + 1) % ${#options[@]} ))
                        ;;
                esac
                ;;
            [1-9]) # Number keys 1-9
                execute_module $((key - 1))
                show_menu
                gather_system_stats
                ;;
            0) # Number key 0 (Exit)
                execute_module 9
                ;;
            "") # Enter key
                execute_module $current
                show_menu
                gather_system_stats
                ;;
        esac
    else
        gather_system_stats
    fi
done


