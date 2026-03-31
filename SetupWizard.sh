#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SETUP WIZARD
# Hướng dẫn người dùng cấu hình hệ thống lần đầu
# =========================================================

MANAGER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_FILE="/root/.openclaw/.env"
[ -f "$ENV_FILE" ] || ENV_FILE="$MANAGER_DIR/.env"
JSON_FILE="/root/.openclaw/openclaw.json"
[ -f "$JSON_FILE" ] || JSON_FILE="$MANAGER_DIR/openclaw-templates/openclaw.json"

# Nâng cao tính tương thích
export TERM=${TERM:-xterm-256color}

# Load UI Helper & Modules
source "$MANAGER_DIR/scripts/ui_helper.sh"
source "$MANAGER_DIR/manage_domain.sh"

show_wizard_header() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}       OPENCLAW MANAGER - SETUP WIZARD          ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${CYAN}  Hệ thống sẽ hướng dẫn bạn cấu hình từng bước.    ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# --- BƯỚC 1: KIỂM TRA DOMAIN, NGINX & SSL ---
step_1_domain() {
    [ -f "$ENV_FILE" ] && source "$ENV_FILE"
    
    local domain_ok=true
    local reason=""

    # 1. Kiểm tra biến trong .env
    if [ -z "$DOMAIN_NAME" ]; then
        domain_ok=false
        reason="chưa cấu hình domain trong .env"
    else
        # 2. Kiểm tra Nginx Proxy
        if [ ! -f "/etc/nginx/sites-enabled/$DOMAIN_NAME" ]; then
            domain_ok=false
            reason="thiếu tệp cấu hình Nginx Proxy"
        # 3. Kiểm tra SSL
        elif [ ! -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
            domain_ok=false
            reason="chưa có chứng chỉ SSL (HTTPS)"
        fi
    fi

    if [ "$domain_ok" = false ]; then
        echo -e "${YELLOW}[BƯỚC 1/6] KIỂM TRA DOMAIN & SSL${NC}"
        echo -e "(DOMAIN $DOMAIN_NAME $reason.)"
        setup_domain_ssl "$DOMAIN_NAME"
        echo ""
    else
        echo -e "${GREEN}✅ BƯỚC 1: DOMAIN & SSL hiện tại ($DOMAIN_NAME) đã sẵn sàng.${NC}"
        echo -ne "Bạn có muốn thay đổi tên miền khác hoặc cấu hình lại không? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_domain.sh"
            setup_domain_ssl "$DOMAIN_NAME"
        fi
        echo ""
    fi
}

# --- BƯỚC 2: THIẾT LẬP PASSWORD MODE ---
step_2_password() {
    [ -f "$ENV_FILE" ] && source "$ENV_FILE"
    if [ -z "$OPENCLAW_GATEWAY_PASSWORD" ]; then
        echo -e "${YELLOW}[BƯỚC 2/6] THIẾT LẬP MẬT KHẨU DASHBOARD (PASSWORD MODE)${NC}"
        echo -e "Chưa thiết lập mật khẩu đăng nhập Dashboard."
        echo -ne "Bạn có muốn tạo mật khẩu ngay? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_settings.sh"
            execute_action 2 # 2 là index của Password Mode
        else
            echo -e "${MAGENTA}Bỏ qua Bước 2.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ BƯỚC 2: PASSWORD MODE đã được thiết lập.${NC}"
    fi
}

# --- BƯỚC 3: KIỂM TRA KÊNH CHAT ---
step_3_channels() {
    NUM_CHANNELS=$(jq '.channels.telegram.accounts | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$NUM_CHANNELS" -eq 0 ]; then
        echo -e "${YELLOW}[BƯỚC 3/6] THÊM KÊNH CHAT (TELEGRAM)${NC}"
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
        echo -e "${GREEN}✅ BƯỚC 3: Đã có $NUM_CHANNELS kênh chat.${NC}"
    fi
}

# --- BƯỚC 4: KIỂM TRA AI MODELS ---
step_4_models() {
    NUM_PROFILES=$(jq '.auth.profiles | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$NUM_PROFILES" -eq 0 ]; then
        echo -e "${YELLOW}[BƯỚC 4/6] CẤU HÌNH AI MODEL (API KEY)${NC}"
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
        echo -e "${GREEN}✅ BƯỚC 4: Đã cấu hình $NUM_PROFILES tài khoản AI.${NC}"
    fi
}

# --- BƯỚC 5: KIỂM TRA AGENT MODEL ---
step_5_agent_model() {
    PRIMARY_MODEL=$(jq -r '.agents.defaults.model.primary // empty' "$JSON_FILE" 2>/dev/null)
    if [ -z "$PRIMARY_MODEL" ] || [ "$PRIMARY_MODEL" == "null" ]; then
        echo -e "${YELLOW}[BƯỚC 5/6] GÁN MODEL CHO AGENT${NC}"
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
        echo -e "${GREEN}✅ BƯỚC 5: Agent đã được gán model ($PRIMARY_MODEL).${NC}"
    fi
}

# --- BƯỚC 6: KIỂM TRA BINDINGS ---
step_6_bindings() {
    NUM_BINDINGS=$(jq '.bindings | length' "$JSON_FILE" 2>/dev/null || echo 0)
    if [ "$NUM_BINDINGS" -eq 0 ]; then
        echo -e "${YELLOW}[BƯỚC 6/6] KẾT NỐI KÊNH CHAT VÀO AGENT (BINDINGS)${NC}"
        echo -e "Chưa có kết nối nào giữa Bot và Agent."
        echo -ne "Bạn có muốn tạo kết nối (Bind) ngay? (y/n): "; read choice
        if [[ "$choice" =~ ^[yY] ]]; then
            source "$MANAGER_DIR/manage_ai.sh"
            add_binding_enhanced
        else
            echo -e "${MAGENTA}Bỏ qua Bước 6.${NC}"
        fi
        echo ""
    else
        echo -e "${GREEN}✅ BƯỚC 6: Đã có $NUM_BINDINGS kết nối Bindings.${NC}"
    fi
}

# --- CHẠY WIZARD ---
show_wizard_header

# Thực hiện tuần tự
step_1_domain
step_2_password
step_3_channels
step_4_models
step_5_agent_model
step_6_bindings

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}       WIZARD CẤU HÌNH ĐÃ HOÀN TẤT!             ${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}Bạn có thể sử dụng 'ocm' để quản lý chi tiết hơn.${NC}"
# Đánh dấu đã chạy Wizard lần đầu
mkdir -p "$(dirname "$ENV_FILE")"
touch "$HOME/.openclaw/.wizard_done"

echo -e "${YELLOW}⚡ Đang chuyển sang Menu quản lý chính...${NC}"
sleep 1
bash "$MANAGER_DIR/menu.sh"
