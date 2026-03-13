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
    "Danh sách các bản sao lưu"
    "Tạo bản sao lưu mới (OpenClaw + Nginx)"
    "Khôi phục từ bản sao lưu"
    "Xóa bản sao lưu"
    "Quay lại Menu chính"
)

current=0

trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_menu() {
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}QUẢN LÝ SAO LƯU HỆ THỐNG${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-4]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 5 ] && display_num=0
        
        if [ "$i" -eq "$current" ]; then
            echo -e "  ${BG_CYAN}${BOLD}${WHITE} ➜ $display_num. ${options[$i]} ${NC}"
        else
            echo -e "     ${WHITE}$display_num. ${options[$i]}               ${NC}"
        fi
    done
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Thư mục lưu trữ: $BACKUP_DIR${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

execute_action() {
    local index=$1
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) # List backups
            echo -e "${YELLOW}Danh sách các bản sao lưu hiện có:${NC}"
            ls -lh "$BACKUP_DIR" | grep ".tar.gz" || echo "Chưa có bản sao lưu nào."
            ;;
        1) # Create Backup
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            FILE_NAME="OCM_FULL_BACKUP_$TIMESTAMP.tar.gz"
            echo -e "${YELLOW}Đang tiến hành sao lưu toàn bộ hệ thống...${NC}"
            echo -e " - Đang đóng gói: ~/.openclaw và /etc/nginx"
            
            # Create a combined archive
            tar -czf "$BACKUP_DIR/$FILE_NAME" -C / /root/.openclaw /etc/nginx > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}${BOLD}Thành công!${NC}"
                echo -e "File: ${WHITE}$FILE_NAME${NC}"
                echo -e "Dung lượng: ${YELLOW}$(du -sh "$BACKUP_DIR/$FILE_NAME" | awk '{print $1}')${NC}"
            else
                echo -e "${RED}Lỗi xảy ra trong quá trình sao lưu!${NC}"
            fi
            ;;
        2) # Restore Backup
            echo -e "${YELLOW}Chọn bản sao lưu để khôi phục:${NC}"
            mapfile -t files < <(ls -1 "$BACKUP_DIR" | grep "OCM_FULL_BACKUP")
            
            if [ ${#files[@]} -eq 0 ]; then
                echo -e "${RED}Không tìm thấy bản sao lưu nào!${NC}"
            else
                for i in "${!files[@]}"; do
                    echo -e " $((i+1)). ${WHITE}${files[$i]}${NC}"
                done
                echo ""
                echo -n "Chọn số thứ tự (hoặc Enter để hủy): "
                read choice
                
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#files[@]}" ]; then
                    target_file="${files[$((choice-1))]}"
                    echo -e "${RED}${BOLD}CẢNH BÁO: Khôi phục sẽ ghi đè cấu hình hiện tại!${NC}"
                    echo -n "Xác nhận khôi phục $target_file? (y/n): "
                    read confirm
                    if [[ "$confirm" == "y" ]]; then
                        echo -e "${YELLOW}Đang khôi phục hệ thống...${NC}"
                        # Restore both paths
                        tar -xzf "$BACKUP_DIR/$target_file" -C /
                        # Test Nginx
                        nginx -t && systemctl restart nginx
                        echo -e "${GREEN}${BOLD}Khôi phục hoàn tất! Hệ thống đã sẵn sàng.${NC}"
                    fi
                else
                    echo -e "${BLUE}Đã hủy khôi phục.${NC}"
                fi
            fi
            ;;
        3) # Delete Backup
            echo -e "${YELLOW}Danh sách bản sao lưu:${NC}"
            ls -1 "$BACKUP_DIR" | grep ".tar.gz"
            echo ""
            echo -n "Nhập tên file muốn xóa (hoặc ALL để xóa hết): "
            read del_choice
            if [[ "$del_choice" == "ALL" ]]; then
                rm -f "$BACKUP_DIR"/*.tar.gz
                echo -e "${GREEN}Đã xóa toàn bộ bản sao lưu.${NC}"
            elif [ -f "$BACKUP_DIR/$del_choice" ]; then
                rm -f "$BACKUP_DIR/$del_choice"
                echo -e "${GREEN}Đã xóa file: $del_choice${NC}"
            else
                echo -e "${RED}File không tồn tại.${NC}"
            fi
            ;;
        4) exit 0 ;;
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
        [1-4]) execute_action $((key - 1)) ;;
        0) exit 0 ;;
        "") execute_action $current ;;
    esac
done
