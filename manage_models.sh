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

# Helper: Restart gateway để cập nhật có hiệu lực
restart_gateway() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway để áp dụng thay đổi...${NC}"
    openclaw gateway restart > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Gateway đã được khởi động lại thành công!${NC}"
    else
        echo -e "${RED}⚠️  Không thể khởi động lại Gateway. Hãy chạy thủ công: openclaw gateway restart${NC}"
    fi
}

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
    "Xóa Models (Delete Models)"
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
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-9, a, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        if [ "$i" -lt 9 ]; then
            display_num=$((i + 1))
        elif [ "$i" -eq 9 ]; then
            display_num="a"
        else
            display_num="0"
        fi
        
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
    if [ $index -eq 10 ]; then exit 0; fi # Option 0: Back
    
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    tput cnorm
    
    case $index in
        0) # List
            echo -e "${YELLOW}Đang liệt kê các Models...${NC}"
            openclaw models list
            ;;
        1) # Status
            echo -e "${YELLOW}Kiểm tra trạng thái & API Key của các Models...${NC}"
            openclaw models status --probe --probe-provider openrouter --probe-timeout 60000
            ;;
        2) # Scan
            echo -e "${YELLOW}Đang quét danh sách Models mới...${NC}"
            openclaw models scan
            ;;
        3) # GET FREE MODEL
            if [ -f "$MANAGER_DIR/scripts/get_free_model.sh" ]; then
                bash "$MANAGER_DIR/scripts/get_free_model.sh"
            else
                echo -e "${RED}Lỗi: Không tìm thấy file scripts/get_free_model.sh${NC}"
            fi
            ;;
        4) # Set Primary
            echo -n "Nhập Model ID để làm mặc định (VD: openrouter/auto): "
            read val
            if [ -n "$val" ]; then
                openclaw models set "$val"
                echo -e "${GREEN}Đã đặt Model chính là $val${NC}"
                restart_gateway
            fi
            ;;
        5) # Set Image
            echo -n "Nhập Image Model ID (VD: openai/dall-e-3): "
            read val
            if [ -n "$val" ]; then
                openclaw models set-image "$val"
                echo -e "${GREEN}Đã đặt Image Model chính là $val${NC}"
                restart_gateway
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
                restart_gateway
            elif [ "$sub_opt" == "2" ]; then
                echo -n "Nhập tên Alias cần xóa: "
                read alias_name
                openclaw models aliases remove "$alias_name"
                restart_gateway
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
                restart_gateway
            elif [ "$sub_opt" == "2" ]; then
                echo -n "Nhập Model ID cần gỡ dự phòng: "
                read model_id
                openclaw models fallbacks remove "$model_id"
                restart_gateway
            elif [ "$sub_opt" == "3" ]; then
                openclaw models fallbacks clear
                restart_gateway
            fi
            ;;
        8) # Auth Profiles Management
            while true; do
                clear
                echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
                echo -e "${CYAN}│${NC}        ${BOLD}${WHITE}QUẢN LÝ XÁC THỰC MODEL (AUTH)${NC}         ${CYAN}│${NC}"
                echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
                echo -e "  ${WHITE}1.${NC} Login (Chạy flow đăng nhập OAuth/API Key)"
                echo -e "  ${WHITE}2.${NC} Add Token (Thêm Token thủ công - Hỗ trợ dán)"
                echo -e "  ${WHITE}3.${NC} Paste Token (Dán token trực tiếp vào cấu hình)"
                echo -e "  ${WHITE}4.${NC} Setup Token (Chạy CLI tạo/đồng bộ token)"
                echo -e "  ${WHITE}5.${NC} Login GitHub Copilot (Device Flow)"
                echo -e "  ${WHITE}0.${NC} Quay lại"
                echo -e "${CYAN}────────────────────────────────────────────────${NC}"
                echo -n -e "\n${YELLOW}Chọn tác vụ [1-5, 0]: ${NC}"
                read auth_opt

                case $auth_opt in
                    1) echo -e "${CYAN}Chạy: openclaw models auth login...${NC}"; openclaw models auth login ;;
                    2) echo -e "${CYAN}Chạy: openclaw models auth add...${NC}"; openclaw models auth add ;;
                    3) echo -e "${CYAN}Chạy: openclaw models auth paste-token...${NC}"; openclaw models auth paste-token ;;
                    4) echo -e "${CYAN}Chạy: openclaw models auth setup-token...${NC}"; openclaw models auth setup-token ;;
                    5) echo -e "${CYAN}Chạy: openclaw models auth login-github-copilot...${NC}"; openclaw models auth login-github-copilot ;;
                    0) break ;;
                    *) echo -e "${RED}Lựa chọn không hợp lệ!${NC}"; sleep 1 ;;
                esac
                echo ""
                read -p "Nhấn Enter để tiếp tục..."
            done
            ;;
        9) # Delete Models
            echo -e "${YELLOW}Đang tải danh sách Models...${NC}"
            CONFIG_PATH="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
            if [ -f "$CONFIG_PATH" ]; then
                mapfile -t model_list < <(jq -r 'if .agents?.defaults?.models then .agents.defaults.models | keys[] else empty end' "$CONFIG_PATH" 2>/dev/null)
            else
                model_list=()
            fi

            if [ ${#model_list[@]} -eq 0 ]; then
                echo -e "${RED}Chưa có model nào được thêm vào cấu hình (Hoặc đang dùng mặc định).${NC}"
                echo -e "Bạn có thể gõ tay để xóa."
                echo -n "Nhập Model ID cần xóa (bỏ trống để hủy): "
                read manual_id
                if [ -n "$manual_id" ]; then
                    openclaw models remove "$manual_id"
                    echo -e "${GREEN}Đã thực hiện lệnh xóa '$manual_id'.${NC}"
                    restart_gateway
                fi
            else
                echo -e "${CYAN}Danh sách Models hiện tại trong cấu hình:${NC}"
                for i in "${!model_list[@]}"; do
                    echo "  $((i+1)). ${model_list[$i]}"
                done
                echo "  ------------------------------------"
                echo "  all. Xóa tất cả Model (Delete All)"
                echo "  q. Nhập Model ID thủ công"
                echo "  c. Hủy thao tác"
                
                echo -n -e "\n${YELLOW}Chọn số thứ tự model cần xóa, [all] để xóa hết, hoặc [c] để quay lại: ${NC}"
                read del_opt
                
                if [[ "$del_opt" == "all" || "$del_opt" == "ALL" ]]; then
                    echo -n -e "${RED}⚠️  CẢNH BÁO: Xóa tất cả các models trong cấu hình? (y/n): ${NC}"
                    read confirm
                    if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
                        jq 'del(.agents.defaults.models) | del(.agents.defaults.model.fallbacks) | del(.agents.defaults.model.primary)' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
                        echo -e "${GREEN}Đã xóa sạch cấu hình bổ sung của AI Models.${NC}"
                        restart_gateway
                    else
                        echo -e "${YELLOW}Đã hủy thao tác.${NC}"
                    fi
                elif [[ "$del_opt" == "q" || "$del_opt" == "Q" ]]; then
                    echo -n "Nhập Model ID cần xóa: "
                    read manual_id
                    if [ -n "$manual_id" ]; then
                        openclaw models remove "$manual_id"
                        echo -e "${GREEN}Đã thực hiện lệnh xóa '$manual_id'.${NC}"
                        restart_gateway
                    fi
                elif [[ "$del_opt" == "c" || "$del_opt" == "C" || -z "$del_opt" ]]; then
                    echo -e "${YELLOW}Đã hủy thao tác.${NC}"
                elif [[ "$del_opt" =~ ^[0-9]+$ ]] && [ "$del_opt" -gt 0 ] && [ "$del_opt" -le "${#model_list[@]}" ]; then
                    m_to_delete="${model_list[$((del_opt-1))]}"
                    echo -n -e "${YELLOW}Bạn có chắc chắn muốn xóa model ${BOLD}'$m_to_delete'${NC}? (y/n): "
                    read confirm
                    if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
                        openclaw models remove "$m_to_delete"
                        echo -e "${GREEN}Đã xóa: $m_to_delete${NC}"
                        restart_gateway
                    else
                        echo -e "${YELLOW}Đã hủy xóa.${NC}"
                    fi
                else
                    echo -e "${RED}Lựa chọn không hợp lệ.${NC}"
                fi
            fi
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
        a|A)
            execute_action 9
            ;;
        0)
            execute_action 10
            ;;
        "")
            execute_action $current
            ;;
    esac
done
