#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SAO LƯU & KHÔI PHỤC
# =========================================================

REAL_PATH=$(readlink -f "$0")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

BACKUP_DIR="/root/openclaw-backups"
mkdir -p "$BACKUP_DIR"

options=(
    "Danh sách các bản sao lưu"
    "Tạo bản sao lưu mới (Full)"
    "Khôi phục từ bản sao lưu"
    "Xóa bản sao lưu"
    "Quay lại Menu chính"
)

current=0

execute_action() {
    local index=$1
    if [ $index -eq 4 ]; then exit 0; fi 
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) ls -lh "$BACKUP_DIR" | grep ".tar.gz" || echo "Trống." ;;
        1) 
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            FILE_NAME="OCM_FULL_BACKUP_$TIMESTAMP.tar.gz"
            echo -e "${YELLOW}Đang sao lưu: ~/.openclaw và /etc/nginx...${NC}"
            tar -czf "$BACKUP_DIR/$FILE_NAME" -C / /root/.openclaw /etc/nginx > /dev/null 2>&1
            [ $? -eq 0 ] && echo -e "${GREEN}Thành công! File: $FILE_NAME${NC}" || echo -e "${RED}Lỗi sao lưu!${NC}"
            ;;
        2) 
            mapfile -t files < <(ls -1 "$BACKUP_DIR" | grep "OCM_FULL_BACKUP")
            if [ ${#files[@]} -eq 0 ]; then echo -e "${RED}Không có bản sao lưu.${NC}"
            else
                for i in "${!files[@]}"; do echo -e " $((i+1)). ${files[$i]}"; done
                read -p "Chọn số thứ tự: " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#files[@]}" ]; then
                    tar -xzf "$BACKUP_DIR/${files[$((choice-1))]}" -C /
                    nginx -t && systemctl restart nginx
                    echo -e "${GREEN}Khôi phục hoàn tất!${NC}"
                fi
            fi ;;
        3) 
            ls -1 "$BACKUP_DIR"/*.tar.gz
            read -p "Nhập tên file xóa (hoặc ALL): " del_choice
            [ "$del_choice" == "ALL" ] && rm -f "$BACKUP_DIR"/*.tar.gz && echo "Đã xóa hết."
            [ -f "$BACKUP_DIR/$del_choice" ] && rm -f "$BACKUP_DIR/$del_choice" && echo "Đã xóa file."
            ;;
    esac
    pause_menu
}

while true; do
    gather_system_stats
    clear
    show_header "SAO LƯU & KHÔI PHỤC (BACKUP)"
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
    echo -e " ${WHITE}Backup Path: $BACKUP_DIR${NC}"

    tput civis
    if read -rsn1 -t 3 key; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                    "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
                esac ;;
            [1-4]) execute_action $((key - 1)) ;;
            0) exit 0 ;;
            "") execute_action $current ;;
        esac
    fi
done
