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

BACKUP_DIR="/root/openclaw-backups"
mkdir -p "$BACKUP_DIR"

options=(
    "Sao lưu toàn bộ cấu hình OpenClaw"
    "Khôi phục cấu hình từ bản sao lưu"
    "Sao lưu cấu hình Nginx"
    "Xem danh sách các bản sao lưu"
    "Xóa tất cả bản sao lưu cũ"
    "Quay lại Menu chính"
)

current=0

trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_menu() {
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}SAO LƯU & KHÔI PHỤC (OCM)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-5]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 6 ] && display_num=0
        
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${options[$i]}               ${NC}"
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Backup Path: $BACKUP_DIR${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

execute_action() {
    local index=$1
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) # Backup OpenClaw
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            FILE_NAME="openclaw_backup_$TIMESTAMP.tar.gz"
            echo -e "${YELLOW}Đang sao lưu cấu hình OpenClaw...${NC}"
            tar -czf "$BACKUP_DIR/$FILE_NAME" -C /root .openclaw > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Thành công! File lưu tại: $BACKUP_DIR/$FILE_NAME${NC}"
            else
                echo -e "${RED}Lỗi khi sao lưu!${NC}"
            fi
            ;;
        1) # Restore OpenClaw
            echo -e "${YELLOW}Danh sách bản sao lưu OpenClaw:${NC}"
            ls -1 "$BACKUP_DIR" | grep "openclaw_backup"
            echo ""
            echo -n "Nhập tên file bạn muốn khôi phục (hoặc Enter để hủy): "
            read restore_file
            if [ -n "$restore_file" ] && [ -f "$BACKUP_DIR/$restore_file" ]; then
                echo -e "${YELLOW}Đang khôi phục...${NC}"
                tar -xzf "$BACKUP_DIR/$restore_file" -C /root
                echo -e "${GREEN}Khôi phục hoàn tất!${NC}"
            else
                echo -e "${RED}File không hợp lệ hoặc đã hủy.${NC}"
            fi
            ;;
        2) # Backup Nginx
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            FILE_NAME="nginx_backup_$TIMESTAMP.tar.gz"
            echo -e "${YELLOW}Đang sao lưu cấu hình Nginx...${NC}"
            tar -czf "$BACKUP_DIR/$FILE_NAME" /etc/nginx > /dev/null 2>&1
            echo -e "${GREEN}Thành công! File lưu tại: $BACKUP_DIR/$FILE_NAME${NC}"
            ;;
        3) # List backups
            echo -e "${YELLOW}Danh sách các bản sao lưu hiện có:${NC}"
            du -sh "$BACKUP_DIR"/* 2>/dev/null || echo "Không có bản sao lưu nào."
            ;;
        4) # Delete all
            echo -e "${RED}${BOLD}CẢNH BÁO: Hành động này sẽ xóa toàn bộ file backup!${NC}"
            echo -n "Bạn có chắc chắn? (y/n): "
            read confirm
            if [[ "$confirm" == "y" ]]; then
                rm -f "$BACKUP_DIR"/*.tar.gz
                echo -e "${GREEN}Đã xóa sạch thư mục backup.${NC}"
            fi
            ;;
        5) exit 0 ;;
    esac
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    read -p "Nhấn Enter để quay lại..."
    tput civis
    clear
}

tput civis
clear

while true; do
    show_menu
    read -rsn1 key
    case "$key" in
        $'\x1b')
            read -rsn2 -t 0.1 next_key
            case "$next_key" in
                "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
            esac
            ;;
        [1-5]) execute_action $((key - 1)) ;;
        0) exit 0 ;;
        "") execute_action $current ;;
    esac
done
