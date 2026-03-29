#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - AI AGENTS & BINDINGS (MULTI-AGENT)
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"
JSON_FILE="$HOME/.openclaw/openclaw.json"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

# Helper: Restart gateway
restart_gateway_sl() {
    echo -e "${YELLOW}⏳ Đang khởi động lại Gateway...${NC}"
    if systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1; then
        systemctl --user restart openclaw-gateway.service
    else
        openclaw gateway restart > /dev/null 2>&1
    fi
    [ $? -eq 0 ] && echo -e "${GREEN}✅ Thành công!${NC}" || echo -e "${RED}❌ Lỗi restart.${NC}"
    sleep 1
}

# Helper: Chọn Agent từ danh sách
select_agent() {
    mapfile -t agent_ids < <(jq -r '.agents.list[].id' "$JSON_FILE" 2>/dev/null)
    if [ ${#agent_ids[@]} -eq 0 ]; then
        echo -e "${RED}Không tìm thấy Agent nào.${NC}"
        return 1
    fi

    echo -e "${YELLOW}Chọn Agent:${NC}"
    for i in "${!agent_ids[@]}"; do
        echo -e "  $((i+1)). ${CYAN}${agent_ids[$i]}${NC}"
    done
    echo -ne "${YELLOW}➤ Nhập số thứ tự [1-${#agent_ids[@]}]:${NC} "
    read a_idx
    if [[ ! "$a_idx" =~ ^[0-9]+$ ]] || [ "$a_idx" -lt 1 ] || [ "$a_idx" -gt "${#agent_ids[@]}" ]; then
        echo -e "${RED}Lỗi: Lựa chọn không hợp lệ.${NC}"
        return 1
    fi
    selected_agent_id="${agent_ids[$((a_idx-1))]}"
    return 0
}

# Helper: Chọn Kênh và Tài khoản
select_channel_account() {
    # Chọn Channel
    mapfile -t channels < <(jq -r '.channels | keys[]' "$JSON_FILE" 2>/dev/null)
    if [ ${#channels[@]} -eq 0 ]; then
        echo -e "${RED}Không tìm thấy loại kênh nào.${NC}"
        return 1
    fi

    echo -e "${YELLOW}Chọn loại kênh:${NC}"
    for i in "${!channels[@]}"; do
        echo -e "  $((i+1)). ${CYAN}${channels[$i]}${NC}"
    done
    read -p "➤ Nhập số: " c_idx
    [ -z "$c_idx" ] || [[ ! "$c_idx" =~ ^[0-9]+$ ]] && return 1
    sel_chan="${channels[$((c_idx-1))]}"

    # Chọn Account
    mapfile -t accounts < <(jq -r ".channels.\"$sel_chan\".accounts | keys[]" "$JSON_FILE" 2>/dev/null)
    if [ ${#accounts[@]} -eq 0 ]; then
        echo -e "${RED}Không có tài khoản nào trong kênh này.${NC}"
        return 1
    fi

    echo -e "${YELLOW}Chọn tài khoản:${NC}"
    for i in "${!accounts[@]}"; do
        echo -e "  $((i+1)). ${WHITE}${accounts[$i]}${NC}"
    done
    read -p "➤ Nhập số: " ac_idx
    [ -z "$ac_idx" ] || [[ ! "$ac_idx" =~ ^[0-9]+$ ]] && return 1
    sel_acc="${accounts[$((ac_idx-1))]}"
    
    return 0
}

# 1. Liệt kê Agents
list_agents() {
    tput cnorm
    clear
    show_header "DANH SÁCH AI AGENTS (AGENT LIST)"
    echo -e "${WHITE}ID Agent             Workspace Path${NC}"
    echo -e "${CYAN}------------------------------------------------${NC}"
    jq -r '.agents.list[] | "\(.id)|\(.workspace)"' "$JSON_FILE" | while IFS='|' read -r id ws; do
        printf " ${MAGENTA}%-20s${NC} ${YELLOW}%-30s${NC}\n" "$id" "$ws"
    done
    echo ""
    pause_menu
}

# 2. Thêm Agent mới
add_agent_enhanced() {
    tput cnorm
    echo -e "\n${CYAN}--- THÊM AGENT MỚI ---${NC}"
    read -p "➤ Nhập ID cho Agent (VD: support-bot): " a_id
    [ -z "$a_id" ] && return
    
    # Check duplicate
    if jq -e ".agents.list[] | select(.id == \"$a_id\")" "$JSON_FILE" >/dev/null; then
        echo -e "${RED}Lỗi: ID này đã tồn tại.${NC}"
        sleep 2; return
    fi

    read -p "➤ Tên hiển thị (Tùy chọn): " a_name
    workspace="~/.openclaw/workspace-$a_id"
    
    # Add to JSON
    # Note: openclaw config set agents.list.[] '{"id": "...", "workspace": "..."}' is not standard.
    # We use jq directly to append to array.
    jq --arg id "$a_id" --arg ws "$workspace" '.agents.list += [{"id": $id, "workspace": $ws}]' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    
    echo -e "${GREEN}✅ Đã thêm Agent $a_id thành công!${NC}"
    
    echo -ne "${YELLOW}➤ Bạn có muốn Gán (Bind) Agent này cho kênh chat ngay không? (y/n):${NC} "
    read do_bind
    if [[ "$do_bind" =~ ^[yY] ]]; then
        if select_channel_account; then
            jq --arg aid "$a_id" --arg chan "$sel_chan" --arg acc "$sel_acc" \
               '.bindings += [{"agentId": $aid, "match": {"channel": $chan, "accountId": $acc}}]' \
               "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
            echo -e "${GREEN}✅ Đã gán thành công!${NC}"
        fi
    fi
    
    restart_gateway_sl
}

# 3. Sửa Agent
edit_agent_enhanced() {
    tput cnorm
    echo -e "\n${CYAN}--- CHỈNH SỬA AGENT ---${NC}"
    if select_agent; then
        echo -e "${YELLOW}Bạn đang sửa Agent: ${BOLD}${WHITE}$selected_agent_id${NC}"
        read -p "➤ Nhập workspace mới [Bỏ qua để giữ nguyên]: " new_ws
        if [ -n "$new_ws" ]; then
            jq --arg sid "$selected_agent_id" --arg ws "$new_ws" \
               '(.agents.list[] | select(.id == $sid)).workspace = $ws' \
               "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
            echo -e "${GREEN}✅ Đã cập nhật xong!${NC}"
            restart_gateway_sl
        fi
    fi
}

# 4. Xóa Agent
delete_agent_enhanced() {
    tput cnorm
    echo -e "\n${RED}--- XÓA AI AGENT ---${NC}"
    if select_agent; then
        echo -ne "${RED}${BOLD}➤ Xác nhận xóa Agent $selected_agent_id? (y/n):${NC} "
        read confirm
        if [[ "$confirm" =~ ^[yY] ]]; then
            # Xóa khỏi list
            jq --arg sid "$selected_agent_id" '.agents.list |= map(select(.id != $sid))' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
            # Xóa khỏi bindings
            jq --arg sid "$selected_agent_id" '.bindings |= map(select(.agentId != $sid))' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
            
            echo -e "${GREEN}✅ Đã xóa Agent và các kết nối liên quan!${NC}"
            restart_gateway_sl
        fi
    fi
}

# Sub-menu for Bindings (Gán kênh chat)
show_bindings_menu_enhanced() {
    local b_options=("Danh sách kết nối" "Tạo kết nối mới (Bind)" "Gỡ bỏ kết nối (Unbind)" "Quay lại")
    local b_current=0

    while true; do
        gather_system_stats
        clear
        show_header "GÁN KÊNH CHAT CHO AGENT (BINDINGS)"
        echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-3, 0]:${NC}"
        echo ""
        
        for i in "${!b_options[@]}"; do
            display_num=$((i + 1))
            [ $display_num -eq 4 ] && display_num=0
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
                1) # List
                    tput cnorm; echo -e "${YELLOW}Các kết nối (Agent ⇹ Channel):${NC}"
                    jq -r '.bindings[] | "\(.agentId) ⇹ \(.match.channel) (\(.match.accountId))"' "$JSON_FILE" || echo "Trống."
                    pause_menu ;;
                2) # Bind
                    tput cnorm
                    if select_agent; then
                        if select_channel_account; then
                            jq --arg aid "$selected_agent_id" --arg chan "$sel_chan" --arg acc "$sel_acc" \
                               '.bindings += [{"agentId": $aid, "match": {"channel": $chan, "accountId": $acc}}]' \
                               "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
                            echo -e "${GREEN}✅ Đã gán thành công!${NC}"
                            restart_gateway_sl
                        fi
                    fi
                    pause_menu ;;
                3) # Unbind
                    tput cnorm
                    echo -e "${YELLOW}Chọn kết nối để gỡ:${NC}"
                    mapfile -t binds < <(jq -r '.bindings[] | "\(.agentId)|\(.match.channel)|\(.match.accountId)"' "$JSON_FILE")
                    if [ ${#binds[@]} -eq 0 ]; then echo "Không có kết nối nào."; sleep 1; 
                    else
                        for i in "${!binds[@]}"; do
                            IFS='|' read -r aid chan acc <<< "${binds[$i]}"
                            echo -e "  $((i+1)). ${CYAN}$aid${NC} ⇹ $chan ($acc)"
                        done
                        read -p "➤ Nhập số để gỡ: " u_idx
                        if [[ -n "$u_idx" ]] && [ "$u_idx" -le "${#binds[@]}" ]; then
                            IFS='|' read -r aid chan acc <<< "${binds[$((u_idx-1))]}"
                            jq --arg aid "$aid" --arg chan "$chan" --arg acc "$acc" \
                               '.bindings |= map(select(.agentId != $aid or .match.channel != $chan or .match.accountId != $acc))' \
                               "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
                            echo -e "${GREEN}✅ Đã gỡ kết nối!${NC}"
                            restart_gateway_sl
                        fi
                    fi
                    pause_menu ;;
                0|4) return ;;
                "") # Enter
                    case $b_current in
                        0) tput cnorm; jq -r '.bindings[] | "\(.agentId) ⇹ \(.match.channel) (\(.match.accountId))"' "$JSON_FILE" || echo "Trống."; pause_menu ;;
                        1) # Bind same logic
                          tput cnorm; if select_agent; then if select_channel_account; then jq --arg aid "$selected_agent_id" --arg chan "$sel_chan" --arg acc "$sel_acc" '.bindings += [{"agentId": $aid, "match": {"channel": $chan, "accountId": $acc}}]' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"; echo -e "${GREEN}✅ Đã gán!${NC}"; restart_gateway_sl; fi; fi; pause_menu ;;
                        2) # Unbind same logic
                          tput cnorm; mapfile -t binds < <(jq -r '.bindings[] | "\(.agentId)|\(.match.channel)|\(.match.accountId)"' "$JSON_FILE"); if [ ${#binds[@]} -gt 0 ]; then for i in "${!binds[@]}"; do IFS='|' read -r aid chan acc <<< "${binds[$i]}"; echo -e "  $((i+1)). $aid ⇹ $chan ($acc)"; done; read -p "Chọn số: " u_idx; if [ -n "$u_idx" ]; then IFS='|' read -r aid chan acc <<< "${binds[$((u_idx-1))]}"; jq --arg aid "$aid" --arg chan "$chan" --arg acc "$acc" '.bindings |= map(select(.agentId != $aid or .match.channel != $chan or .match.accountId != $acc))' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"; echo "Đã gỡ."; restart_gateway_sl; fi; fi; pause_menu ;;
                        3) return ;;
                    esac ;;
            esac
        fi
    done
}

# 5. Gán Model cho Agent
set_agent_model() {
    tput cnorm
    echo -e "\n${CYAN}--- GÁN AI MODEL CHO AGENT ---${NC}"
    if select_agent; then
        # 1. Thu thập model từ nhiều nguồn
        echo -e "${YELLOW}⏳ Đang tải danh sách model khả dụng...${NC}"
        
        # Nguồn A: Từ CLI (Trích xuất ID từ cột đầu tiên)
        mapfile -t cli_models < <(openclaw models list 2>/dev/null | grep -E '^([a-z0-9_-]+/[a-z0-9_-]+)' | awk '{print $1}')
        
        # Nguồn B: Từ agents.defaults.models trong JSON
        mapfile -t default_models < <(jq -r '.agents.defaults.models | keys[]' "$JSON_FILE" 2>/dev/null)
        
        # Nguồn C: Từ models.catalog trong JSON
        mapfile -t catalog_models < <(jq -r '.models.catalog[].id' "$JSON_FILE" 2>/dev/null)
        
        # Gộp và loại bỏ trùng lặp
        all_models=($(printf "%s\n" "${cli_models[@]}" "${default_models[@]}" "${catalog_models[@]}" | sort -u))

        if [ ${#all_models[@]} -eq 0 ]; then
            echo -e "${YELLOW}➤ Không tìm thấy model nào trong hệ thống. Vui lòng nhập ID thủ công (VD: openrouter/auto):${NC} "
            read sel_model
        else
            echo -e "${YELLOW}Chọn AI Model cho Agent ${BOLD}${WHITE}$selected_agent_id${NC}:"
            for i in "${!all_models[@]}"; do
                echo -e "  $((i+1)). ${CYAN}${all_models[$i]}${NC}"
            done
            echo -ne "${YELLOW}➤ Nhập số thứ tự [1-${#all_models[@]}]:${NC} "
            read m_idx
            if [[ "$m_idx" =~ ^[0-9]+$ ]] && [ "$m_idx" -ge 1 ] && [ "$m_idx" -le "${#all_models[@]}" ]; then
                sel_model="${all_models[$((m_idx-1))]}"
            else
                echo -e "${RED}Lựa chọn không hợp lệ.${NC}"; return
            fi
        fi

        if [ -n "$sel_model" ]; then
            # Cập nhật model.primary cho agent cụ thể trong agents.list
            # Đồng thời đảm bảo cấu trúc model exist
            jq --arg sid "$selected_agent_id" --arg model "$sel_model" \
               '(.agents.list[] | select(.id == $sid)).model.primary = $model' \
               "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
            echo -e "${GREEN}✅ Đã gán model $sel_model cho agent $selected_agent_id!${NC}"
            restart_gateway_sl
        fi
    fi
}

options=(
    "Danh sách Agents (List)"
    "Thêm Agent mới (Add)"
    "Sửa cấu hình Agent (Edit)"
    "Xóa bỏ Agent (Delete)"
    "Kết nối kênh chat vào Agent (Bindings)"
    "Gán AI Model cho Agent (Set Model)"
    "Quay lại Menu chính"
)
current=0

execute_ai_action() {
    local index=$1
    case $index in
        0) list_agents ;;
        1) add_agent_enhanced ;;
        2) edit_agent_enhanced ;;
        3) delete_agent_enhanced ;;
        4) show_bindings_menu_enhanced ;;
        5) set_agent_model ;;
        6) exit 0 ;;
    esac
    [ "$index" -ne 4 ] && pause_menu
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        gather_system_stats
        clear
        show_header "QUẢN LÝ AI AGENTS"
        echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-6, 0]:${NC}"
        echo ""

        for i in "${!options[@]}"; do
            display_num=$((i + 1))
            [ $display_num -eq 7 ] && display_num=0
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
                [1-6]) execute_ai_action $((key - 1)) ;;
                0) exit 0 ;;
                "") execute_ai_action $current ;;
            esac
        fi
    done
fi
