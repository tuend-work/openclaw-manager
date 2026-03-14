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
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'
BG_CYAN='\033[46m'

if ! command -v openclaw &> /dev/null; then
    echo -e "${RED}Lỗi: OpenClaw chưa được cài đặt.${NC}"
    read -p "Nhấn Enter để quay lại..."
    exit 1
fi

options=(
    "Danh sách Models (List All)"
    "Trạng thái Models (Status)"
    "Quét các AI Models (Scan Catalog)"
    "GET FREE MODEL (Tự động tìm & cài Model miễn phí)"
    "Thiết lập Model chính (Set Primary)"
    "Thiết lập Image Model (Set Image)"
    "Quản lý Aliases (Model Aliases)"
    "Quản lý Fallbacks (Model Fallbacks)"
    "Xác thực Models (Model Auth)"
    "Quay lại Menu chính"
)

current=0
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

show_menu() {
    printf "\033[H"
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}       ${BOLD}${WHITE}QUẢN LÝ AI MODELS (OPENCLAW)${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} CLI: ${CYAN}openclaw models <subcommand>${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 10 ] && display_num=0
        
        # Colorize the parentheses description
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
    echo -e " ${WHITE}Shortcut: [Enter]: Chọn | [0]: Quay lại${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}

execute_action() {
    local index=$1
    if [ $index -eq 9 ]; then exit 0; fi # Option 0: Back
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) # List
            echo -e "${YELLOW}Đang liệt kê các Models...${NC}"
            openclaw models list
            ;;
        1) # Status
            echo -e "${YELLOW}Kiểm tra trạng thái các Models...${NC}"
            openclaw models status
            ;;
        2) # Scan
            echo -e "${YELLOW}Đang quét danh sách Models mới...${NC}"
            openclaw models scan
            ;;
        3) # GET FREE MODEL
            echo -e "${YELLOW}Đang thực hiện quy trình tối ưu AI Miễn phí (Xử lý song song)...${NC}"
            
            echo -e "${CYAN}1. Cập nhật Catalog Models...${NC}"
            openclaw models scan > /dev/null 2>&1
            
            # Lấy danh sách ID các model free
            mapfile -t free_models < <(openclaw models list | grep -i "free" | awk '{print $2}' | sort -u)
            total_free=${#free_models[@]}
            
            if [ $total_free -eq 0 ]; then
                echo -e "${RED}Không tìm thấy Model miễn phí nào. Cài đặt mặc định openrouter/auto...${NC}"
                openclaw models set "openrouter/auto"
            else
                echo -e "\n${CYAN}2. Tìm thấy ${total_free} Model. Đang kiểm tra tốc độ đồng loạt...${NC}"
                echo -e "${GRAY}Hệ thống đang gửi tín hiệu test tới tất cả server cùng lúc...${NC}"
                
                # Tạo thư mục tạm để lưu kết quả song song
                tmp_results=$(mktemp -d)
                
                # Chạy song song tất cả các test
                for i in "${!free_models[@]}"; do
                    (
                        m="${free_models[$i]}"
                        start_time=$(date +%s%N)
                        if timeout 8s openclaw agent ask "hi" --model "$m" --plain > /dev/null 2>&1; then
                            end_time=$(date +%s%N)
                            delta=$(( (end_time - start_time) / 1000000 ))
                            echo "$delta $m" > "$tmp_results/res_$i"
                        fi
                    ) &
                done
                
                # Hiển thị thanh tiến trình động trong khi chờ các background jobs
                echo -n -e "  ➜ Tiến trình: ["
                for ((i=0; i<30; i++)); do
                    echo -n "●"
                    sleep 0.3
                done
                echo -e "] ${GREEN}Xong!${NC}"

                # Thu thập và phân tích kết quả
                fastest_model=""
                min_time=99999
                
                # Gom kết quả
                if ls "$tmp_results"/res_* >/dev/null 2>&1; then
                    while IFS= read -r line; do
                        t=$(echo "$line" | awk '{print $1}')
                        mod=$(echo "$line" | awk '{print $2}')
                        if [ -n "$t" ] && [ "$t" -lt "$min_time" ]; then
                            min_time=$t
                            fastest_model=$mod
                        fi
                    done < <(cat "$tmp_results"/res_*)
                fi
                
                # Dọn dẹp
                rm -rf "$tmp_results"
                
                if [ -n "$fastest_model" ]; then
                    echo -e "\n${MAGENTA}${BOLD}┌──────────────────────────────────────────────┐${NC}"
                    echo -e "${MAGENTA}${BOLD}│${NC}  ${BOLD}${WHITE}KẾT QUẢ TỐI ƯU HÓA HOÀN TẤT${NC}               ${MAGENTA}${BOLD}│${NC}"
                    echo -e "${MAGENTA}${BOLD}└──────────────────────────────────────────────┘${NC}"
                    echo -e " 🥇 ${BOLD}Nhanh nhất:${NC} ${GREEN}$fastest_model${NC} (${min_time}ms)"
                    
                    echo -e "\n${CYAN}3. Đang cấu hình hệ thống...${NC}"
                    echo -e "  ➜ Đặt làm Model chính... ${GREEN}OK${NC}"
                    openclaw models set "$fastest_model" > /dev/null 2>&1
                    
                    echo -e "  ➜ Nạp các model còn lại vào danh sách dự phòng...${NC}"
                    fb_count=0
                    for m in "${free_models[@]}"; do
                        if [ "$m" != "$fastest_model" ]; then
                            openclaw models fallbacks add "$m" > /dev/null 2>&1
                            fb_count=$((fb_count + 1))
                        fi
                    done
                    echo -e "  ➜ Đã nạp ${GREEN}${fb_count}${NC} model dự phòng. ${GREEN}Hoàn tất!${NC}"
                else
                    echo -e "\n${RED}Tất cả Model thử nghiệm đều thất bại hoặc Timeout.${NC}"
                    echo -e "${YELLOW}Gợi ý: Hãy kiểm tra Internet hoặc dùng lệnh 'OpenClaw Command > Health' để check.${NC}"
                fi
            fi
            ;;
        4) # Set Primary
            echo -n "Nhập Model ID để làm mặc định (VD: openrouter/auto): "
            read val
            if [ -n "$val" ]; then
                openclaw models set "$val"
                echo -e "${GREEN}Đã đặt Model chính là $val${NC}"
            fi
            ;;
        5) # Set Image
            echo -n "Nhập Image Model ID (VD: openai/dall-e-3): "
            read val
            if [ -n "$val" ]; then
                openclaw models set-image "$val"
                echo -e "${GREEN}Đã đặt Image Model chính là $val${NC}"
            fi
            ;;
        6) # Aliases
            echo -e "${YELLOW}Danh sách Aliases hiện tại:${NC}"
            openclaw models aliases list
            echo ""
            echo "1. Thêm Alias"
            echo "2. Xóa Alias"
            echo "3. Quay lại"
            echo -n "Chọn [1-3]: "
            read sub_opt
            if [ "$sub_opt" == "1" ]; then
                echo -n "Nhập tên Alias (VD: gpt4): "
                read alias_name
                echo -n "Nhập Model ID thực (VD: openai/gpt-4o): "
                read model_id
                openclaw models aliases add "$alias_name" "$model_id"
            elif [ "$sub_opt" == "2" ]; then
                echo -n "Nhập tên Alias cần xóa: "
                read alias_name
                openclaw models aliases remove "$alias_name"
            fi
            ;;
        7) # Fallbacks
            echo -e "${YELLOW}Danh sách Fallbacks hiện tại:${NC}"
            openclaw models fallbacks list
            echo ""
            echo "1. Thêm Fallback"
            echo "2. Xóa Fallback"
            echo "3. Xóa tất cả"
            echo "4. Quay lại"
            echo -n "Chọn [1-4]: "
            read sub_opt
            if [ "$sub_opt" == "1" ]; then
                echo -n "Nhập Model ID dự phòng: "
                read model_id
                openclaw models fallbacks add "$model_id"
            elif [ "$sub_opt" == "2" ]; then
                echo -n "Nhập Model ID cần gỡ dự phòng: "
                read model_id
                openclaw models fallbacks remove "$model_id"
            elif [ "$sub_opt" == "3" ]; then
                openclaw models fallbacks clear
            fi
            ;;
        8) # Auth
            echo -e "${YELLOW}Quản lý xác thực Model (Auth):${NC}"
            openclaw models auth
            ;;
    esac
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    read -p "Nhấn Enter để quay lại..."
    tput civis
    clear
}

# Hide cursor
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
        [1-9])
            execute_action $((key - 1))
            ;;
        0)
            execute_action 9
            ;;
        "")
            execute_action $current
            ;;
    esac
done
