#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - CHANNEL MANAGEMENT (MULTI-CHANNEL)
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"
JSON_FILE="$HOME/.openclaw/openclaw.json"
ENV_FILE="$HOME/.openclaw/.env"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

# Export env for systemctl --user
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Helper function to restart gateway
restart_gateway_sl() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway để áp dụng thay đổi...${NC}"
    if systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1; then
        systemctl --user restart openclaw-gateway.service
    else
        openclaw gateway restart > /dev/null 2>&1
    fi
    [ $? -eq 0 ] && echo -e "${GREEN}✅ Đã cập nhật thành công!${NC}" || echo -e "${RED}❌ Lỗi khởi động dịch vụ.${NC}"
    sleep 1
}

# Ensure JSON structure
ensure_json_structure() {
    if [ ! -f "$JSON_FILE" ]; then
        mkdir -p "$HOME/.openclaw"
        [ -f "$MANAGER_DIR/openclaw-templates/openclaw.json" ] && cp "$MANAGER_DIR/openclaw-templates/openclaw.json" "$JSON_FILE" || echo "{ \"channels\": { \"telegram\": { \"enabled\": true, \"accounts\": {} } } }" > "$JSON_FILE"
    fi
    jq -e '.channels.telegram.accounts' "$JSON_FILE" >/dev/null 2>&1 || {
        OLD_TOKEN=$(jq -r '.channels.telegram.botToken // empty' "$JSON_FILE")
        OLD_POLICY=$(jq -r '.channels.telegram.dmPolicy // "pairing"' "$JSON_FILE")
        jq --arg token "$OLD_TOKEN" --arg policy "$OLD_POLICY" '.channels.telegram.accounts.default = {botToken: $token, dmPolicy: $policy} | del(.channels.telegram.botToken) | del(.channels.telegram.dmPolicy)' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    }
}

detect_telegram_id() {
    local token=$1
    echo -e "\n${MAGENTA}------------------------------------------------${NC}"
    echo -e "${BOLD}${WHITE}HƯỚNG DẪN LẤY ID TỰ ĐỘNG:${NC}"
    echo -e "1. Mở Telegram và tìm Bot bạn vừa thêm."
    echo -e "2. Nhấn ${YELLOW}/start${NC} hoặc gửi ${YELLOW}tin nhắn bất kỳ${NC} cho Bot."
    echo -e "${MAGENTA}------------------------------------------------${NC}"
    echo -e "${CYAN}⏳ Đang chờ tin nhắn từ bạn (Timeout 60s)...${NC}"
    
    found_id=""
    for i in {1..12}; do
        local response=$(curl -s --max-time 5 "https://api.telegram.org/bot${token}/getUpdates")
        found_id=$(echo "$response" | jq -r '.result[0].message.from.id // empty' 2>/dev/null)
        if [ -n "$found_id" ] && [ "$found_id" != "null" ]; then
            echo -e "${GREEN}🎯 Đã nhận diện được User ID: ${BOLD}${WHITE}$found_id${NC}"
            return 0
        fi
        echo -ne "${GRAY}.${NC}"
        sleep 5
    done
    echo -e "\n${RED}⚠️  Không tìm thấy tin nhắn hoặc quá thời gian chờ.${NC}"
    return 1
}

list_channels() {
    tput cnorm
    clear
    show_header "DANH SÁCH KÊNH CHAT (CHANNEL LIST)"
    echo -e "${WHITE}ID Tài khoản         Token                   Chính sách${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    jq -r '.channels | to_entries[] | .key as $chan | .value.accounts | to_entries[] | "\($chan)|\(.key)|\(.value.botToken)|\(.value.dmPolicy)"' "$JSON_FILE" | while IFS='|' read -r chan acc token policy; do
        masked_token="${token:0:6}...${token: -6}"
        printf " ${MAGENTA}%-10s${NC} ${YELLOW}%-9s${NC} %-23s %-10s\n" "$chan" "$acc" "$masked_token" "$policy"
    done
    echo -e "${CYAN}------------------------------------------------${NC}"
    pause_menu
}

add_channel_enhanced() {
    tput cnorm
    echo -e "\n${CYAN}--- BƯỚC 1: CHỌN LOẠI KÊNH ---${NC}"
    echo -e "1. Telegram"
    echo -e "2. Zalo (Dùng số điện thoại/token)"
    echo -e "3. Khác (Tự nhập tay)"
    echo -ne "${YELLOW}➤ Lựa chọn [1-3]:${NC} "
    read c_type_choice
    
    case $c_type_choice in
        1) channel_type="telegram" ;;
        2) channel_type="zalo" ;;
        3) echo -ne "${YELLOW}➤ Nhập tên loại kênh (VD: discord):${NC} "; read channel_type ;;
        *) channel_type="telegram" ;;
    esac

    echo -ne "${YELLOW}➤ Nhập Account ID (VD: main, user1):${NC} "
    read account_id
    [ -z "$account_id" ] && return

    echo -ne "${YELLOW}➤ Nhập Token / API Key:${NC} "
    read bot_token
    
    echo -ne "${YELLOW}➤ Chọn dmPolicy (1. pairing | 2. allowlist | 3. open):${NC} [1] "
    read pol_choice
    case $pol_choice in
        2) dm_policy="allowlist" ;;
        3) dm_policy="open" ;;
        *) dm_policy="pairing" ;;
    esac

    # Logic riêng cho Telegram
    user_ids="[]"
    if [ "$channel_type" == "telegram" ]; then
        echo -ne "${YELLOW}➤ Bạn có muốn tự động nhận diện ID không? (y/n):${NC} "
        read do_detect
        if [[ "$do_detect" =~ ^[yY] ]]; then
            if detect_telegram_id "$bot_token"; then
                user_ids="[\"$found_id\"]"
            fi
        fi
        if [ "$user_ids" == "[]" ] && [ "$dm_policy" == "allowlist" ]; then
            echo -ne "${YELLOW}➤ Nhập danh sách ID thủ công (cách nhau bởi dấu phẩy):${NC} "
            read manual_ids
            if [ -z "$manual_ids" ]; then
                user_ids="[]"
            else
                user_ids=$(jq -nc --arg ids "$manual_ids" '$ids | split(",") | map(select(length > 0))')
            fi
        fi
    fi

    # Update openclaw.json
    jq --arg chan "$channel_type" --arg acc "$account_id" --arg token "$bot_token" --arg policy "$dm_policy" --argjson allow "$user_ids" \
       '.channels[$chan].accounts[$acc] = {botToken: $token, dmPolicy: $policy, allowFrom: $allow}' \
       "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

    # Sync to .env (Form: [CHANNEL]_[ACCOUNT]_TOKEN)
    ENV_PREFIX=$(echo "${channel_type}_${account_id}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    if [ -f "$ENV_FILE" ]; then
        sed -i "/^${ENV_PREFIX}_TOKEN=/d" "$ENV_FILE"
        echo "${ENV_PREFIX}_TOKEN=\"$bot_token\"" >> "$ENV_FILE"
        if [ "$account_id" == "default" ] && [ "$channel_type" == "telegram" ]; then
            sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"$bot_token\"|" "$ENV_FILE"
            [ "$user_ids" != "[]" ] && sed -i "s|^TELEGRAM_ALLOW_USER_IDS_VALUE=.*|TELEGRAM_ALLOW_USER_IDS_VALUE=\"$(echo "$user_ids" | jq -r 'join(",")')\"|" "$ENV_FILE"
        fi
    fi

    echo -e "${GREEN}✅ Đã thêm kênh $channel_type ($account_id) thành công!${NC}"
    restart_gateway_sl
}

edit_channel_direct() {
    tput cnorm
    echo -e "\n${CYAN}--- SỬA CẤU HÌNH KÊNH CHAT ---${NC}"
    
    # 1. Chọn Channel Type
    mapfile -t channels < <(jq -r '.channels | keys[]' "$JSON_FILE" 2>/dev/null)
    if [ ${#channels[@]} -eq 0 ]; then
        echo -e "${RED}Không tìm thấy kênh nào để sửa.${NC}"
        sleep 2; return
    fi

    echo -e "${YELLOW}Chọn loại kênh:${NC}"
    for i in "${!channels[@]}"; do
        echo -e "  $((i+1)). ${CYAN}${channels[$i]}${NC}"
    done
    echo -ne "${YELLOW}➤ Nhập số thứ tự [1-${#channels[@]}]:${NC} "
    read c_idx
    if [[ ! "$c_idx" =~ ^[0-9]+$ ]] || [ "$c_idx" -lt 1 ] || [ "$c_idx" -gt "${#channels[@]}" ]; then
        echo -e "${RED}Lựa chọn không hợp lệ.${NC}"
        sleep 1; return
    fi
    channel_type="${channels[$((c_idx-1))]}"

    # 2. Chọn Account ID
    mapfile -t accounts < <(jq -r ".channels.\"$channel_type\".accounts | keys[]" "$JSON_FILE" 2>/dev/null)
    if [ ${#accounts[@]} -eq 0 ]; then
        echo -e "${RED}Không tìm thấy tài khoản nào trong kênh $channel_type.${NC}"
        sleep 2; return
    fi

    echo -e "${YELLOW}Chọn tài khoản cần sửa trong kênh $channel_type:${NC}"
    for i in "${!accounts[@]}"; do
        echo -e "  $((i+1)). ${WHITE}${accounts[$i]}${NC}"
    done
    echo -ne "${YELLOW}➤ Nhập số thứ tự [1-${#accounts[@]}]:${NC} "
    read a_idx
    if [[ ! "$a_idx" =~ ^[0-9]+$ ]] || [ "$a_idx" -lt 1 ] || [ "$a_idx" -gt "${#accounts[@]}" ]; then
        echo -e "${RED}Lựa chọn không hợp lệ.${NC}"
        sleep 1; return
    fi
    account_id="${accounts[$((a_idx-1))]}"
    
    # 3. Lấy thông tin hiện tại
    curr_token=$(jq -r ".channels.\"$channel_type\".accounts.\"$account_id\".botToken // empty" "$JSON_FILE")
    curr_policy=$(jq -r ".channels.\"$channel_type\".accounts.\"$account_id\".dmPolicy // \"pairing\"" "$JSON_FILE")
    curr_allow=$(jq -r ".channels.\"$channel_type\".accounts.\"$account_id\".allowFrom | join(\",\")" "$JSON_FILE" 2>/dev/null)

    echo -ne "${YELLOW}➤ Token mới [Enter giữ cũ]:${NC} "
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
        allow_ids=$(jq -c ".channels.\"$channel_type\".accounts.\"$account_id\".allowFrom // []" "$JSON_FILE")
    else
        allow_ids=$(jq -nc --arg ids "$raw_ids" '$ids | split(",") | map(select(length > 0))')
    fi

    jq --arg chan "$channel_type" --arg acc "$account_id" --arg token "$bot_token" --arg policy "$dm_policy" --argjson allow "$allow_ids" \
       '.channels[$chan].accounts[$acc] = {botToken: $token, dmPolicy: $policy, allowFrom: $allow}' \
       "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

    # Sync to .env if editing main telegram
    ENV_PREFIX=$(echo "${channel_type}_${account_id}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    if [ -f "$ENV_FILE" ]; then
        sed -i "/^${ENV_PREFIX}_TOKEN=/d" "$ENV_FILE"
        echo "${ENV_PREFIX}_TOKEN=\"$bot_token\"" >> "$ENV_FILE"
        if [ "$account_id" == "default" ] && [ "$channel_type" == "telegram" ]; then
            sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"$bot_token\"|" "$ENV_FILE"
            [ "$allow_ids" != "[]" ] && sed -i "s|^TELEGRAM_ALLOW_USER_IDS_VALUE=.*|TELEGRAM_ALLOW_USER_IDS_VALUE=\"$(echo "$allow_ids" | jq -r 'join(",")')\"|" "$ENV_FILE"
        fi
    fi
    
    echo -e "${GREEN}✅ Đã cập nhật xong!${NC}"
    restart_gateway_sl
}

delete_channel_direct() {
    tput cnorm
    echo -e "\n${RED}--- XÓA KÊNH CHAT ---${NC}"
    
    # 1. Chọn Channel Type
    mapfile -t channels < <(jq -r '.channels | keys[]' "$JSON_FILE" 2>/dev/null)
    if [ ${#channels[@]} -eq 0 ]; then
        echo -e "${RED}Không tìm thấy kênh nào trong cấu hình.${NC}"
        sleep 2; return
    fi

    echo -e "${YELLOW}Chọn loại kênh:${NC}"
    for i in "${!channels[@]}"; do
        echo -e "  $((i+1)). ${CYAN}${channels[$i]}${NC}"
    done
    echo -ne "${YELLOW}➤ Nhập số thứ tự [1-${#channels[@]}]:${NC} "
    read c_idx
    if [[ ! "$c_idx" =~ ^[0-9]+$ ]] || [ "$c_idx" -lt 1 ] || [ "$c_idx" -gt "${#channels[@]}" ]; then
        echo -e "${RED}Lựa chọn không hợp lệ.${NC}"
        sleep 1; return
    fi
    channel_type="${channels[$((c_idx-1))]}"

    # 2. Chọn Account ID
    mapfile -t accounts < <(jq -r ".channels.\"$channel_type\".accounts | keys[]" "$JSON_FILE" 2>/dev/null)
    if [ ${#accounts[@]} -eq 0 ]; then
        echo -e "${RED}Không tìm thấy tài khoản nào trong kênh $channel_type.${NC}"
        sleep 2; return
    fi

    echo -e "${YELLOW}Chọn tài khoản cần xóa trong kênh $channel_type:${NC}"
    for i in "${!accounts[@]}"; do
        echo -e "  $((i+1)). ${WHITE}${accounts[$i]}${NC}"
    done
    echo -ne "${YELLOW}➤ Nhập số thứ tự [1-${#accounts[@]}]:${NC} "
    read a_idx
    if [[ ! "$a_idx" =~ ^[0-9]+$ ]] || [ "$a_idx" -lt 1 ] || [ "$a_idx" -gt "${#accounts[@]}" ]; then
        echo -e "${RED}Lựa chọn không hợp lệ.${NC}"
        sleep 1; return
    fi
    account_id="${accounts[$((a_idx-1))]}"

    # 3. Xác nhận và Xóa
    echo -ne "${RED}${BOLD}➤ Xác nhận xóa tài khoản $account_id thuộc kênh $channel_type? (y/n):${NC} "
    read confirm
    if [[ "$confirm" =~ ^[yY] ]]; then
        jq --arg chan "$channel_type" --arg acc "$account_id" 'del(.channels[$chan].accounts[$acc])' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
        
        # Nếu xóa mất default telegram, xóa luôn trong .env cho sạch
        if [ "$account_id" == "default" ] && [ "$channel_type" == "telegram" ]; then
            sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"\"|" "$ENV_FILE"
        fi
        
        echo -e "${GREEN}✅ Đã xóa tài khoản.$NC"
        restart_gateway_sl
    else
        echo -e "${YELLOW}Đã hủy thao tác.${NC}"
        sleep 1
    fi
}

ensure_json_structure

# --- Helpers cho Gán Agent vào Group ---
select_agent() {
    mapfile -t agent_ids < <(jq -r '.agents.list[].id' "$JSON_FILE" 2>/dev/null)
    if [ ${#agent_ids[@]} -eq 0 ]; then echo -e "${RED}Không tìm thấy Agent nào.${NC}"; return 1; fi
    echo -e "${YELLOW}Chọn Agent:${NC}"
    for i in "${!agent_ids[@]}"; do echo -e "  $((i+1)). ${CYAN}${agent_ids[$i]}${NC}"; done
    echo -ne "${YELLOW}➤ Nhập STT: ${NC}"; read a_idx
    [ -z "$a_idx" ] || [[ ! "$a_idx" =~ ^[0-9]+$ ]] && return 1
    selected_agent_id="${agent_ids[$((a_idx-1))]}"
    return 0
}

select_channel_account_local() {
    mapfile -t channels < <(jq -r '.channels | keys[]' "$JSON_FILE" 2>/dev/null)
    [ ${#channels[@]} -eq 0 ] && return 1
    echo -e "${YELLOW}Chọn loại kênh:${NC}"
    for i in "${!channels[@]}"; do echo -e "  $((i+1)). ${CYAN}${channels[$i]}${NC}"; done
    read -p "➤ Nhập số: " c_idx
    [ -z "$c_idx" ] || [[ ! "$c_idx" =~ ^[0-9]+$ ]] && return 1
    sel_chan="${channels[$((c_idx-1))]}"
    mapfile -t accounts < <(jq -r ".channels.\"$sel_chan\".accounts | keys[]" "$JSON_FILE" 2>/dev/null)
    [ ${#accounts[@]} -eq 0 ] && return 1
    echo -e "${YELLOW}Chọn tài khoản:${NC}"
    for i in "${!accounts[@]}"; do echo -e "  $((i+1)). ${WHITE}${accounts[$i]}${NC}"; done
    read -p "➤ Nhập số: " ac_idx
    [ -z "$ac_idx" ] || [[ ! "$ac_idx" =~ ^[0-9]+$ ]] && return 1
    sel_acc="${accounts[$((ac_idx-1))]}"
    return 0
}

add_agent_to_group() {
    tput cnorm
    echo -e "\n${CYAN}--- GÁN AGENT VÀO GROUP TELEGRAM ---${NC}"
    if select_agent && select_channel_account_local; then
        echo -ne "${YELLOW}➤ Nhập ID Group Telegram (VD: -100123456789):${NC} "
        read group_id
        [ -z "$group_id" ] && return

        jq --arg gid "$group_id" '.channels.telegram.groupPolicy = "allowlist" | 
            .channels.telegram.groups //= {} |
            if .channels.telegram.groups[$gid] == null then 
                .channels.telegram.groups[$gid] = {"requireMention": true, "allowFrom": []} 
            else . end' \
           "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

        jq --arg aid "$selected_agent_id" --arg acc "$sel_acc" --arg gid "$group_id" \
           '.bindings += [{"agentId": $aid, "match": {"channel": "telegram", "accountId": $acc, "chatId": $gid}}]' \
           "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

        echo -e "${GREEN}✅ Gán thành công!${NC}"
        restart_gateway_sl
    fi
}

# Main Menu Logic
options=("Danh sách kênh (List)" "Thêm kênh chat (Add)" "Sửa kênh chat (Edit)" "Xóa kênh chat (Delete)" "Gán Agent vào Group (Telegram)" "Quay lại Menu chính")
current=0

while true; do
    gather_system_stats
    clear
    show_header "QUẢN LÝ KÊNH CHAT (CHANNELS)"
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
    if read -rsn1 -t 3 key; then
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 next_key
                case "$next_key" in
                    "[A") current=$(( (current - 1 + ${#options[@]}) % ${#options[@]} )) ;;
                    "[B") current=$(( (current + 1) % ${#options[@]} )) ;;
                esac ;;
            1) list_channels ;;
            2) add_channel_enhanced ;;
            3) edit_channel_direct ;;
            4) delete_channel_direct ;;
            5) add_agent_to_group ;;
            0|6) exit 0 ;;
            "") 
                case $current in
                    0) list_channels ;;
                    1) add_channel_enhanced ;;
                    2) edit_channel_direct ;;
                    3) delete_channel_direct ;;
                    4) add_agent_to_group ;;
                    5) exit 0 ;;
                esac ;;
        esac
    fi
done
