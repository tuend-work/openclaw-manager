#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SETUP WIZARD
# Dẫn dắt người dùng cấu hình hệ thống lần đầu
# =========================================================

MANAGER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_FILE="/root/.openclaw/.env"
[ -f "$ENV_FILE" ] || ENV_FILE="$MANAGER_DIR/.env"
JSON_FILE="/root/.openclaw/openclaw.json"
[ -f "$JSON_FILE" ] || JSON_FILE="$MANAGER_DIR/openclaw-templates/openclaw.json"

# Nâng cao tính tương thích
export TERM=${TERM:-xterm-256color}

# Load UI Helper
source "$MANAGER_DIR/scripts/ui_helper.sh"

show_wizard_header() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}       OPENCLAW MANAGER - SETUP WIZARD          ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${CYAN}  Hệ thống sẽ dẫn dắt bạn cấu hình từng bước.    ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# --- BƯỚC 1: KIỂM TRA DOMAIN ---
step_1_domain() {
    [ -f "$ENV_FILE" ] && source "$ENV_FILE"
    if [[ "$DOMAIN_NAME" == "ai.example.com" || -z "$DOMAIN_NAME" ]]; then
        echo -e "${YELLOW}[BƯỚC 1/6] Cấu hình Domain & SSL${NC}"
        echo -e "Phát hiện Domain chưa được thiết lập."
        echo -ne "Bạn có muốn cấu hình Domain ngay bây giờ? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_domain.sh"
            setup_domain_ssl
        else
            echo -e "${MAGENTA}Bỏ qua Bước 1.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ Bước 1: Domain đã được cấu hình ($DOMAIN_NAME).${NC}"
    fi
}

# --- BƯỚC 2: KIỂM TRA GATEWAY TOKEN ---
step_2_token() {
    [ -f "$ENV_FILE" ] && source "$ENV_FILE"
    if [[ "$OPENCLAW_GATEWAY_TOKEN" == "your_secure_random_token_here" || -z "$OPENCLAW_GATEWAY_TOKEN" ]]; then
        echo -e "${YELLOW}[BƯỚC 2/6] Cấu hình Gateway Token (Auth)${NC}"
        echo -e "Phát hiện Token bảo mật hiện tại là mặc định hoặc trống."
        echo -ne "Bạn có muốn tạo Token bảo mật mới? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_settings.sh"
            execute_action 1 # 1 là index của Gateway Token
        else
            echo -e "${MAGENTA}Bỏ qua Bước 2.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ Bước 2: Gateway Token đã có.${NC}"
    fi
}

# --- BƯỚC 3: KIỂM TRA KÊNH CHAT ---
step_3_channels() {
    NUM_CHANNELS=$(jq '.channels.telegram.accounts | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$NUM_CHANNELS" -eq 0 ]; then
        echo -e "${YELLOW}[BƯỚC 3/6] Thêm Kênh Chat (Telegram)${NC}"
        echo -e "Chưa tìm thấy Tài khoản Bot Telegram nào trong cấu hình."
        echo -ne "Bạn có muốn thêm Tài khoản Bot ngay? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_channels.sh"
            add_channel_enhanced
        else
            echo -e "${MAGENTA}Bỏ qua Bước 3.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ Bước 3: Đã có $NUM_CHANNELS kênh chat.${NC}"
    fi
}

# --- BƯỚC 4: KIỂM TRA AI MODELS ---
step_4_models() {
    NUM_PROFILES=$(jq '.auth.profiles | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$NUM_PROFILES" -eq 0 ]; then
        echo -e "${YELLOW}[BƯỚC 4/6] Cấu hình AI Model (API Key)${NC}"
        echo -e "Chưa tìm thấy API Key (OpenRouter/OpenAI...) nào được xác thực."
        echo -ne "Bạn có muốn thêm API Key ngay? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_models.sh"
            execute_action 1 # 1 là index Thêm Tài khoản mới
        else
            echo -e "${MAGENTA}Bỏ qua Bước 4.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ Bước 4: Đã cấu hình $NUM_PROFILES tài khoản AI.${NC}"
    fi
}

# --- BƯỚC 5: KIỂM TRA AGENT MODEL ---
step_5_agent_model() {
    PRIMARY_MODEL=$(jq -r '.agents.defaults.model.primary // empty' "$JSON_FILE" 2>/dev/null)
    if [ -z "$PRIMARY_MODEL" ] || [ "$PRIMARY_MODEL" == "null" ]; then
        echo -e "${YELLOW}[BƯỚC 5/6] Gán Model cho Agent${NC}"
        echo -e "Agent 'main' chưa được gán Model AI mặc định."
        echo -ne "Bạn có muốn gán Model cho Agent ngay? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_ai.sh"
            set_agent_model
        else
            echo -e "${MAGENTA}Bỏ qua Bước 5.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ Bước 5: Agent đã được gán model ($PRIMARY_MODEL).${NC}"
    fi
}

# --- BƯỚC 6: KIỂM TRA BINDINGS ---
step_6_bindings() {
    NUM_BINDINGS=$(jq '.bindings | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$NUM_BINDINGS" -eq 0 ]; then
        echo -e "${YELLOW}[BƯỚC 6/6] Kết nối Kênh chat vào Agent (Bindings)${NC}"
        echo -e "Chưa có kết nối nào giữa Bot và Agent."
        echo -ne "Bạn có muốn tạo kết nối (Bind) ngay? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_ai.sh"
            show_bindings_menu_enhanced
        else
            echo -e "${MAGENTA}Bỏ qua Bước 6.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ Bước 6: Đã có $NUM_BINDINGS kết nối Bindings.${NC}"
    fi
}

# --- CHẠY WIZARD ---
show_wizard_header

# Thực hiện tuần tự
step_1_domain
step_2_token
step_3_channels
step_4_models
step_5_agent_model
step_6_bindings

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}       WIZARD CẤU HÌNH ĐÃ HOÀN TẤT!             ${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}Bạn có thể sử dụng 'ocm' để quản lý chi tiết hơn.${NC}"
echo -e "${YELLOW}⚡ Đang chuyển sang Menu quản lý chính...${NC}"
sleep 1
bash "$MANAGER_DIR/menu.sh"
