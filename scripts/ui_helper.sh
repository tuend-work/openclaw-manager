#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - UI HELPER & SYSTEM STATS
# =========================================================

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

# Get Directory
REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
UI_HELPER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# Load Project Configuration (Version, Brand Name, etc)
if [ -f "$UI_HELPER_DIR/ocm-config.sh" ]; then
    source "$UI_HELPER_DIR/ocm-config.sh"
fi
[ -z "$OCM_VERSION" ] && OCM_VERSION="vUnknown"

gather_system_stats() {
    SYS_RAM=$(free -m | awk 'NR==2{printf "%.1fGB/%.1fGB", $3/1024, $2/1024}')
    SYS_DISK=$(df -h / | awk '$NF=="/"{printf "%s/%s", $3, $2}')
    SYS_UPTIME=$(uptime -p | sed 's/^up //')
    local cpu1=($(awk '/^cpu / {print $2+$3+$4+$6+$7+$8+$9, $5}' /proc/stat))
    local net1=($(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev))
    sleep 0.1
    local cpu2=($(awk '/^cpu / {print $2+$3+$4+$6+$7+$8+$9, $5}' /proc/stat))
    local net2=($(awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev))
    local active=$((cpu2[0] - cpu1[0]))
    local idle=$((cpu2[1] - cpu1[1]))
    local total=$((active + idle + 1))
    SYS_CPU=$(awk -v act="$active" -v tot="$total" -v cores="$(nproc 2>/dev/null || echo 1)" 'BEGIN {printf "%.1f%% (%sC)", act * 100 / tot, cores}')
    SYS_NET_IN=$(awk -v r1="${net1[0]:-0}" -v r2="${net2[0]:-0}" 'BEGIN {printf "%.2f", (r2 - r1) * 10 / 1048576}')
    SYS_NET_OUT=$(awk -v t1="${net1[1]:-0}" -v t2="${net2[1]:-0}" 'BEGIN {printf "%.2f", (t2 - t1) * 10 / 1048576}')
}

show_header() {
    local title=$1
    local domain_name=$(hostname)
    local gateway_token="N/A"
    if [ -f "/root/.openclaw/.env" ]; then
        domain_name=$(grep "^DOMAIN_NAME=" /root/.openclaw/.env | cut -d'=' -f2 | tr -d '"'\'' ')
        gateway_token=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /root/.openclaw/.env | cut -d'=' -f2 | tr -d '"'\'' ')
    fi
    [ -z "$domain_name" ] && domain_name=$(hostname)

    # Move cursor to top-left to reduce flicker in loops
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}${title:-WELCOME TO OPEN-CLAW MANAGER}${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} CPU: ${YELLOW}${SYS_CPU}${NC} | RAM: ${YELLOW}${SYS_RAM}${NC}"
    echo -e " ${WHITE}●${NC} Disk: ${YELLOW}${SYS_DISK}${NC} | Uptime: ${YELLOW}${SYS_UPTIME}${NC}"
    echo -e " ${WHITE}●${NC} Net: ${GREEN}↓ ${SYS_NET_IN}M/s${NC} | ${RED}↑ ${SYS_NET_OUT}M/s${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${WHITE}●${NC} Dashboard: ${CYAN}https://${domain_name}/#token=${gateway_token}${NC}"
}

# Added Pause function for reuse
pause_menu() {
    echo -e "\n${YELLOW}────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}Nhấn Enter để quay lại menu...${NC}"
    read
}
