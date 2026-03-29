#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - DOMAIN & SSL MANAGEMENT
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# UI Helper inclusion
source "$MANAGER_DIR/scripts/ui_helper.sh"

setup_domain_ssl() {
    local domain=$1
    local port=$2

    [ -t 1 ] && tput cnorm
    echo -e "${YELLOW}>>> CẤU HÌNH DOMAIN & SSL (AUTO MODE) <<<${NC}"
    echo -e "${BLUE}------------------------------------------------${NC}"
    
    # Nếu không có tham số -> Yêu cầu nhập
    if [ -z "$domain" ]; then
        echo -n "Nhập domain mới (vd: ai.example.com): "
        read domain
    fi

    if [ -z "$domain" ]; then echo -e "${RED}Lỗi: Domain trống!${NC}"; [ -t 1 ] && sleep 2; return; fi
    if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then echo -e "${RED}Domain không hợp lệ!${NC}"; [ -t 1 ] && sleep 2; return; fi

    if [ -z "$port" ]; then
        echo -n "Nhập Port của OpenClaw (Mặc định: 18789): "
        read port
    fi
    port=${port:-18789}

    echo -e "${YELLOW}[1/4] Đang đổi hostname thành $domain...${NC}"
    hostnamectl set-hostname "$domain" 2>/dev/null
    echo "127.0.0.1 $domain" >> /etc/hosts

    echo -e "${YELLOW}[2/4] Đang tạo cấu hình Nginx cho port $port...${NC}"
    CONF_FILE="/etc/nginx/sites-available/$domain"
    cat > "$CONF_FILE" <<EOF
server {
    listen 80;
    server_name $domain;
    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    ln -sf "$CONF_FILE" "/etc/nginx/sites-enabled/" 2>/dev/null
    nginx -t && systemctl restart nginx

    echo -e "${YELLOW}[3/4] Đang cài đặt SSL (Let's Encrypt)...${NC}"
    certbot --nginx -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[4/4] Cài đặt SSL thành công!${NC}"
    else
        echo -e "${RED}Lỗi SSL. Kiểm tra DNS của $domain.${NC}"
    fi

    if command -v openclaw &> /dev/null; then
        openclaw config set gateway.controlUi.allowedOrigins "[\"https://$domain\"]" > /dev/null 2>&1
        systemctl restart openclaw-gateway > /dev/null 2>&1
    fi
    
    # Chỉ pause nếu có terminal và không có tham số đầu vào
    [ -t 1 ] && [ -z "$1" ] && pause_menu
}

# --- DISPATCHER ---
# Nếu được gọi với tham số (vú dụ từ First Boot), chạy thẳng rồi thoát
if [[ -n "$1" ]]; then
    setup_domain_ssl "$@"
    exit 0
fi

# --- MODE MENU TƯƠNG TÁC ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    options=("Cài đặt bài bản Domain & SSL" "Kiểm tra cấu hình Nginx" "Quay lại Menu chính")
    current=0
    
    while true; do
        gather_system_stats
        [ -t 1 ] && clear
        show_header "QUẢN LÝ DOMAIN & SSL"
        echo -e " ${BOLD}${YELLOW}Sử dụng [↑/↓] hoặc phím số [1-2, 0]:${NC}"
        echo ""

        for i in "${!options[@]}"; do
            display_num=$((i + 1))
            [ $display_num -eq 3 ] && display_num=0
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
                1) setup_domain_ssl ;;
                2) nginx -t && pause_menu ;;
                0|3) exit 0 ;;
                "") [ $current -eq 0 ] && setup_domain_ssl
                    [ $current -eq 1 ] && nginx -t && pause_menu
                    [ $current -eq 2 ] && exit 0 ;;
            esac
        fi
    done
fi
