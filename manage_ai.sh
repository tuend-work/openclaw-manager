#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - AI AGENTS & BINDINGS
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

# Helper: Restart gateway
restart_gateway() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway...${NC}"
    openclaw gateway restart > /dev/null 2>&1
    echo -e "${GREEN}✅ Gateway đã được khởi động lại thành công!${NC}"
    sleep 1
}

# Sub-menu for Bindings with Header & Navigation
show_bindings_menu() {
    local b_options=("Tạo kết nối mới (Bind)" "Gỡ bỏ kết nối (Unbind)" "Quay lại")
    local b_current=0

    while true; do
        gather_system_stats
        clear
        show_header "QUẢN LÝ KẾT NỐI (BINDINGS)"
        echo -e " ${WHITE}●${NC} Chức năng: Gán Agent cho một tài khoản cụ thể."
        echo -e "${CYAN}------------------------------------------------${NC}"
        echo -e "${YELLOW}Danh sách Kết nối Hiện tại:${NC}"
        openclaw agents bindings
        echo ""
        
        for i in "${!b_options[@]}"; do
            display_num=$((i + 1))
            [ $display_num -eq 3 ] && display_num=0
            if [ "$i" -eq "$b_current" ]; then
                echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${b_options[$i]} ${NC}"
            else
                echo -e "     ${WHITE}$display_num. ${b_options[$i]}${NC}"
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
                        "[A") b_current=$(( (b_current - 1 + ${#b_options[@]}) % ${#b_options[@]} )) ;;
                        "[B") b_current=$(( (b_current + 1) % ${#b_options[@]} )) ;;
                    esac ;;
                1) # Bind
                    tput cnorm
                    echo -e "${YELLOW}Danh sách Agents:${NC}"; openclaw agents list
                    echo -ne "${YELLOW}➤ Nhập ID của Agent:${NC} "; read b_agent
                    echo -e "${YELLOW}Danh sách Accounts:${NC}"; openclaw channels list
                    echo -ne "${YELLOW}➤ Nhập Channel (telegram):${NC} "; read b_chan
                    echo -ne "${YELLOW}➤ Nhập Account ID (default):${NC} "; read b_acc
                    [ -n "$b_agent" ] && openclaw agents bind --agent "$b_agent" --channel "$b_chan" --account "$b_acc" && restart_gateway
                    pause_menu ;;
                2) # Unbind
                    tput cnorm
                    echo -ne "${YELLOW}➤ Nhập ID Agent cần gỡ kết nối:${NC} "; read u_agent
                    echo -ne "${YELLOW}➤ Nhập Channel:${NC} "; read u_chan
                    echo -ne "${YELLOW}➤ Nhập Account ID:${NC} "; read u_acc
                    [ -n "$u_agent" ] && openclaw agents unbind --agent "$u_agent" --channel "$u_chan" --account "$u_acc" && restart_gateway
                    pause_menu ;;
                0|3) return ;;
                "") # Enter key
                    case $b_current in
                        0) # Same logic as key 1
                           tput cnorm; echo -ne "${YELLOW}Agent ID: "; read b_agent; echo -ne "Channel: "; read b_chan; echo -ne "Account ID: "; read b_acc
                           [ -n "$b_agent" ] && openclaw agents bind --agent "$b_agent" --channel "$b_chan" --account "$b_acc" && restart_gateway; pause_menu ;;
                        1) # Same logic as key 2
                           tput cnorm; echo -ne "Agent ID: "; read u_agent; echo -ne "Channel: "; read u_chan; echo -ne "Account ID: "; read u_acc
                           [ -n "$u_agent" ] && openclaw agents unbind --agent "$u_agent" --channel "$u_chan" --account "$u_acc" && restart_gateway; pause_menu ;;
                        2) return ;;
                    esac ;;
            esac
        fi
    done
}

options=(
    "Danh sách Agents (List All)"
    "Thêm Agent mới (Add Agent)"
    "Xóa Agent (Remove Agent)"
    "Quản lý Kết nối (Bindings)"
    "Quay lại Menu chính"
)
current=0

execute_ai_action() {
    local index=$1
    tput cnorm
    case $index in
        0) openclaw agents list ;;
        1) 
            echo -ne "${YELLOW}➤ Nhập ID cho Agent mới (VD: agent2):${NC} "; read a_id
            echo -ne "${YELLOW}➤ Nhập tên hiển thị:${NC} "; read a_name
            [ -n "$a_id" ] && openclaw agents add --id "$a_id" --name "$a_name" && restart_gateway ;;
        2) 
            openclaw agents list
            echo -ne "${YELLOW}➤ Nhập ID Agent cần xóa:${NC} "; read d_id
            [ -n "$d_id" ] && openclaw agents remove "$d_id" && restart_gateway ;;
        3) show_bindings_menu; return ;;
        4) exit 0 ;;
    esac
    [ "$index" -ne 3 ] && pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "QUẢN LÝ AI AGENTS"
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
    if read -rsn1 -t 3 key; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                    "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
                esac ;;
            [1-4]) execute_ai_action $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_ai_action $current ;;
        esac
    fi
done
