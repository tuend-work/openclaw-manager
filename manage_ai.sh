#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - AI AGENTS & BINDINGS (MULTI-AGENT)
# =========================================================

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
BG_CYAN='\033[46m'
NC='\033[0m'

# Export env for systemctl --user
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Helper: Restart gateway
restart_gateway() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway để áp dụng thay đổi...${NC}"
    openclaw gateway restart > /dev/null 2>&1
    echo -e "${GREEN}✅ Gateway đã được khởi động lại thành công!${NC}"
    sleep 1
}

show_bindings_menu() {
    while true; do
        clear
        echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC}         ${BOLD}${WHITE}QUẢN LÝ KẾT NỐI (BINDINGS)${NC}           ${CYAN}│${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
        echo -e " ${WHITE}●${NC} Chức năng: Gán Agent cho một tài khoản cụ thể."
        echo -e "${CYAN}------------------------------------------------${NC}"
        echo -e "${YELLOW}Danh sách Kết nối Hiện tại:${NC}"
        openclaw agents bindings
        echo ""
        echo -e "  ${WHITE}1.${NC} Tạo kết nối mới (${CYAN}agents bind${NC})"
        echo -e "  ${WHITE}2.${NC} Gỡ bỏ kết nối (${CYAN}agents unbind${NC})"
        echo -e "  ${WHITE}0.${NC} Quay lại"
        echo -e "${CYAN}────────────────────────────────────────────────${NC}"
        read -p " Nhập lựa chọn: " b_choice

        case $b_choice in
            1)
                echo -e "${YELLOW}Danh sách Agents:${NC}"; openclaw agents list
                echo -ne "${YELLOW}➤ Nhập ID của Agent:${NC} "; read b_agent
                echo -e "${YELLOW}Danh sách Accounts:${NC}"; openclaw channels list
                echo -ne "${YELLOW}➤ Nhập Channel (VD: telegram):${NC} "; read b_chan
                echo -ne "${YELLOW}➤ Nhập Account ID (VD: default hoặc số ID):${NC} "; read b_acc
                
                if [ -n "$b_agent" ] && [ -n "$b_chan" ] && [ -n "$b_acc" ]; then
                    openclaw agents bind --agent "$b_agent" --channel "$b_chan" --account "$b_acc"
                    restart_gateway
                fi
                ;;
            2)
                echo -ne "${YELLOW}➤ Nhập ID Agent cần gỡ kết nối:${NC} "; read u_agent
                echo -ne "${YELLOW}➤ Nhập Channel (VD: telegram):${NC} "; read u_chan
                echo -ne "${YELLOW}➤ Nhập Account ID:${NC} "; read u_acc
                if [ -n "$u_agent" ]; then
                    openclaw agents unbind --agent "$u_agent" --channel "$u_chan" --account "$u_acc"
                    restart_gateway
                fi
                ;;
            0) return ;;
        esac
        [ "$b_choice" != "0" ] && { echo -e "\n${YELLOW}Nhấn Enter để tiếp tục...${NC}"; read; }
    done
}

options=(
    "Danh sách Agents (List All)"
    "Thêm Agent mới (Add Agent)"
    "Xóa Agent (Remove Agent)"
    "Quản lý Kết nối (Manage Bindings)"
    "Quay lại Menu chính"
)
current=0

while true; do
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}           ${BOLD}${WHITE}QUẢN LÝ AI AGENTS (MULTI)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} CLI: ${CYAN}openclaw agents <command>${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-4, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 5 ] && display_num=0
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${options[$i]}${NC}"
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"

    tput civis
    if read -rsn1 -t 5 key; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                    "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
                esac ;;
            1) tput cnorm; echo -e "${CYAN}Danh sách các Agents đang chạy:${NC}"; openclaw agents list ;;
            2) 
                tput cnorm
                echo -ne "${YELLOW}➤ Nhập ID cho Agent mới (VD: agent2):${NC} "; read a_id
                echo -ne "${YELLOW}➤ Nhập tên hiển thị (VD: My Second AI):${NC} "; read a_name
                if [ -n "$a_id" ]; then
                    openclaw agents add --id "$a_id" --name "$a_name"
                    restart_gateway
                fi ;;
            3) 
                tput cnorm; echo -e "${YELLOW}Danh sách Agents:${NC}"; openclaw agents list
                echo -ne "${YELLOW}➤ Nhập ID Agent cần xóa:${NC} "; read d_id
                if [ -n "$d_id" ]; then
                    openclaw agents remove "$d_id"
                    restart_gateway
                fi ;;
            4) show_bindings_menu ;;
            0|5) exit 0 ;;
            "") # Enter
                case $current in
                    0) tput cnorm; openclaw agents list ;;
                    1) tput cnorm; read -p "Nhập ID: " a_id; openclaw agents add --id "$a_id"; restart_gateway ;;
                    2) tput cnorm; read -p "Nhập ID xóa: " d_id; openclaw agents remove "$d_id"; restart_gateway ;;
                    3) show_bindings_menu ;;
                    4) exit 0 ;;
                esac ;;
        esac
        [ "$key" != "" ] && [ "$key" != "$'\x1b'" ] && [ "$current" -ne 3 ] && { echo -e "\n${YELLOW}Nhấn Enter để tiếp tục...${NC}"; read; }
    fi
done
