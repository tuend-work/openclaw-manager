#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - CHANNEL MANAGEMENT (FILE-BASED V2)
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"
JSON_FILE="$HOME/.openclaw/openclaw.json"
ENV_FILE="$HOME/.openclaw/.env"

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

# Helper function to restart gateway
restart_gateway() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway để áp dụng thay đổi...${NC}"
    # Use systemctl if running as service, or openclaw gateway restart
    if systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1; then
        systemctl --user restart openclaw-gateway.service
    else
        openclaw gateway restart > /dev/null 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Đã áp dụng cấu hình và khởi động lại thành công!${NC}"
    else
        echo -e "${RED}❌ Lỗi khi khởi động lại dịch vụ.${NC}"
    fi
    sleep 1
}

# Ensure JSON structure is compatible with Multi-Account
ensure_json_structure() {
    if [ ! -f "$JSON_FILE" ]; then
        # If not exists, try to copy from template
        if [ -f "$MANAGER_DIR/openclaw-templates/openclaw.json" ]; then
            mkdir -p "$HOME/.openclaw"
            cp "$MANAGER_DIR/openclaw-templates/openclaw.json" "$JSON_FILE"
        else
            echo "{ \"channels\": { \"telegram\": { \"enabled\": true, \"accounts\": {} } } }" > "$JSON_FILE"
        fi
    fi
    
    # Check if .channels.telegram.accounts exists, if not, convert
    HAS_ACCOUNTS=$(jq -e '.channels.telegram.accounts' "$JSON_FILE" 2>/dev/null)
    if [ "$?" -ne 0 ]; then
        echo -e "${YELLOW}Cấu trúc cũ phát hiện. Đang chuyển đổi sang Multi-Account...${NC}"
        OLD_TOKEN=$(jq -r '.channels.telegram.botToken // empty' "$JSON_FILE")
        OLD_POLICY=$(jq -r '.channels.telegram.dmPolicy // "pairing"' "$JSON_FILE")
        OLD_ALLOW=$(jq -c '.channels.telegram.allowFrom // []' "$JSON_FILE")
        
        jq --arg token "$OLD_TOKEN" --arg policy "$OLD_POLICY" --argjson allow "$OLD_ALLOW" \
           '.channels.telegram.accounts.default = {botToken: $token, dmPolicy: $policy, allowFrom: $allow} | del(.channels.telegram.botToken) | del(.channels.telegram.dmPolicy) | del(.channels.telegram.allowFrom)' \
           "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    fi
}

list_channels() {
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}           ${BOLD}${WHITE}DANH SÁCH KÊNH TELEGRAM${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e "${WHITE}ID Tài khoản         Token                   Chính sách${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    
    jq -r '.channels.telegram.accounts | to_entries[] | "\(.key)|\(.value.botToken)|\(.value.dmPolicy)"' "$JSON_FILE" | while IFS='|' read -r id token policy; do
        if [ "$token" == "null" ] || [ -z "$token" ]; then
            masked_token="${RED}Chưa có Token${NC}"
        else
            masked_token="${token:0:6}...${token: -6}"
        fi
        printf " ${YELLOW}%-19s${NC} %-23s %-10s\n" "$id" "$masked_token" "$policy"
    done
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e "\n${WHITE}Nhấn Enter để quay lại...${NC}"
    read
}

add_channel() {
    echo -e "\n${CYAN}--- THÊM KÊNH TELEGRAM MỚI ---${NC}"
    echo -ne "${YELLOW}➤ Nhập Account ID (VD: bot2, alerts):${NC} "
    read account_id
    if [ -z "$account_id" ]; then return; fi
    
    if jq -e ".channels.telegram.accounts.\"$account_id\"" "$JSON_FILE" >/dev/null; then
        echo -e "${RED}Lỗi: Account ID '$account_id' đã tồn tại.${NC}"
        sleep 2; return
    fi
    
    echo -ne "${YELLOW}➤ Nhập Telegram Bot Token:${NC} "
    read bot_token
    echo -ne "${YELLOW}➤ Chọn dmPolicy (1. pairing | 2. allowlist | 3. open):${NC} [1] "
    read pol_choice
    case $pol_choice in
        2) dm_policy="allowlist" ;;
        3) dm_policy="open" ;;
        *) dm_policy="pairing" ;;
    esac
    
    allow_ids="[]"
    if [ "$dm_policy" == "allowlist" ]; then
        echo -ne "${YELLOW}➤ Nhập danh sách ID (cách nhau dấu phẩy):${NC} "
        read raw_ids
        allow_ids=$(echo "[$raw_ids]" | jq -c 'split(",") | map(select(length > 0))')
    fi

    # Update JSON using jq
    jq --arg id "$account_id" --arg token "$bot_token" --arg policy "$dm_policy" --argjson allow "$allow_ids" \
       '.channels.telegram.accounts[$id] = {botToken: $token, dmPolicy: $policy, allowFrom: $allow}' \
       "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    
    # Sync environment variable if it's default
    if [ "$account_id" == "default" ] && [ -f "$ENV_FILE" ]; then
        sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$bot_token|" "$ENV_FILE"
    fi
    
    echo -e "${GREEN}✅ Đã thêm tài khoản $account_id thành công!${NC}"
    restart_gateway
}

edit_channel() {
    echo -e "\n${CYAN}--- SỬA CẤU HÌNH KÊNH TELEGRAM ---${NC}"
    mapfile -t ids < <(jq -r '.channels.telegram.accounts | keys[]' "$JSON_FILE")
    
    if [ ${#ids[@]} -eq 0 ]; then
        echo -e "${RED}Chưa có tài khoản nào để sửa.${NC}"
        sleep 2; return
    fi

    for i in "${!ids[@]}"; do
        echo -e "  $((i+1)). ${YELLOW}${ids[$i]}${NC}"
    done
    echo -ne "${YELLOW}➤ Chọn số thứ tự hoặc nhập ID:${NC} "
    read choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#ids[@]}" ]; then
        account_id="${ids[$((choice-1))]}"
    else
        account_id="$choice"
    fi

    if [ -z "$account_id" ] || ! jq -e ".channels.telegram.accounts.\"$account_id\"" "$JSON_FILE" >/dev/null; then
        echo -e "${RED}Lỗi: Không tìm thấy tài khoản.$NC"
        sleep 2; return
    fi
    
    curr_token=$(jq -r ".channels.telegram.accounts.\"$account_id\".botToken // empty" "$JSON_FILE")
    curr_policy=$(jq -r ".channels.telegram.accounts.\"$account_id\".dmPolicy // \"pairing\"" "$JSON_FILE")
    curr_allow=$(jq -r ".channels.telegram.accounts.\"$account_id\".allowFrom | join(\",\")" "$JSON_FILE" 2>/dev/null)

    echo -e "${CYAN}Đang sửa: $account_id${NC}"
    echo -ne "${YELLOW}➤ Bot Token mới [Enter giữ cũ]:${NC} "
    read bot_token
    bot_token=${bot_token:-$curr_token}
    
    echo -ne "${YELLOW}➤ dmPolicy mới (1. pairing | 2. allowlist | 3. open) [$curr_policy]:${NC} "
    read pol_choice
    case $pol_choice in
        1) dm_policy="pairing" ;;
        2) dm_policy="allowlist" ;;
        3) dm_policy="open" ;;
        *) dm_policy="$curr_policy" ;;
    esac
    
    echo -ne "${YELLOW}➤ AllowFrom mới (ID cách nhau dấu phẩy) [$curr_allow]:${NC} "
    read raw_ids
    if [ -z "$raw_ids" ]; then
        allow_ids=$(jq -c ".channels.telegram.accounts.\"$account_id\".allowFrom // []" "$JSON_FILE")
    else
        allow_ids=$(echo "[$raw_ids]" | jq -c 'split(",") | map(select(length > 0))')
    fi

    jq --arg id "$account_id" --arg token "$bot_token" --arg policy "$dm_policy" --argjson allow "$allow_ids" \
       '.channels.telegram.accounts[$id] = {botToken: $token, dmPolicy: $policy, allowFrom: $allow}' \
       "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    
    if [ "$account_id" == "default" ] && [ -f "$ENV_FILE" ]; then
        sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$bot_token|" "$ENV_FILE"
    fi
    
    echo -e "${GREEN}✅ Đã cập nhật tài khoản $account_id thành công!${NC}"
    restart_gateway
}

delete_channel() {
    echo -e "\n${CYAN}--- XÓA KÊNH TELEGRAM ---${NC}"
    mapfile -t ids < <(jq -r '.channels.telegram.accounts | keys[]' "$JSON_FILE")
    
    for i in "${!ids[@]}"; do
        echo -e "  $((i+1)). ${RED}${ids[$i]}${NC}"
    done
    echo -ne "${YELLOW}➤ Chọn số thứ tự hoặc nhập ID cần xóa:${NC} "
    read choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#ids[@]}" ]; then
        account_id="${ids[$((choice-1))]}"
    else
        account_id="$choice"
    fi

    if [ -z "$account_id" ] || ! jq -e ".channels.telegram.accounts.\"$account_id\"" "$JSON_FILE" >/dev/null; then
        echo -e "${RED}Lỗi: Không tìm thấy tài khoản để xóa.$NC"
        sleep 2; return
    fi
    
    echo -ne "${RED}⚠️  Bạn có chắc muốn xóa tài khoản '$account_id'? (y/n):${NC} "
    read confirm
    if [[ "$confirm" =~ ^[yY] ]]; then
        jq --arg id "$account_id" 'del(.channels.telegram.accounts[$id])' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
        echo -e "${GREEN}✅ Đã xóa tài khoản $account_id.${NC}"
        restart_gateway
    else
        echo -e "${YELLOW}Hủy bỏ thao tác xóa.${NC}"
        sleep 1
    fi
}

# --- Initialization ---
ensure_json_structure

options=(
    "Danh sách kênh chat (Channel list)"
    "Thêm kênh chat (Add Channel)"
    "Sửa cấu hình kênh chat (Edit Channel)"
    "Xóa kênh chat (Delete Channel)"
    "Cấu hình nâng cao (Status/Probe/Logs)"
    "Quay lại Menu chính"
)
current=0

while true; do
    clear
    echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}           ${BOLD}${WHITE}QUẢN LÝ KÊNH CHAT (MULTI)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} Cấu hình: ${YELLOW}$JSON_FILE${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-5, 0]:${NC}"
    echo ""

    for i in "${!options[@]}"; do
        display_num=$((i + 1))
        [ $display_num -eq 6 ] && display_num=0
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
            1) list_channels ;;
            2) add_channel ;;
            3) edit_channel ;;
            4) delete_channel ;;
            5) # Submenu for other commands
                echo -e "${YELLOW}1. Trạng thái kết nối${NC}"
                echo -e "${YELLOW}2. Xem nhật ký Kênh${NC}"
                echo -ne "${YELLOW}Chọn [1-2]:${NC} "
                read sub
                [ "$sub" == "1" ] && openclaw channels status && read
                [ "$sub" == "2" ] && openclaw channels logs --channel all && read
                ;;
            0|6) exit 0 ;;
            "") 
                case $current in
                    0) list_channels ;;
                    1) add_channel ;;
                    2) edit_channel ;;
                    3) delete_channel ;;
                    4) # Same as key 5
                        echo -e "${YELLOW}1. Trạng thái kết nối${NC}"
                        echo -e "${YELLOW}2. Xem nhật ký Kênh${NC}"
                        echo -ne "${YELLOW}Chọn [1-2]:${NC} "
                        read sub
                        [ "$sub" == "1" ] && openclaw channels status && read
                        [ "$sub" == "2" ] && openclaw channels logs --channel all && read
                        ;;
                    5) exit 0 ;;
                esac ;;
        esac
    fi
done
