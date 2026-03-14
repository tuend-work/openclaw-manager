# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}>>> QUẢN LÝ DOMAIN & SSL (NGINX PROXY) <<<${NC}"
echo -e "${BLUE}------------------------------------------------${NC}"

# 1. Nhập thông tin (Hỗ trợ tham số dòng lệnh)
if [ -n "$1" ]; then
    domain="$1"
    port="${2:-18789}"
    AUTO_MODE=1
    echo -e "${YELLOW}Chạy tự động với domain: $domain (Port: $port)${NC}"
else
    AUTO_MODE=0
    echo -n "Nhập domain mới (vd: ai.example.com): "
    read domain

    if [[ -z "$domain" ]]; then
        echo -e "${RED}Lỗi: Domain không được để trống!${NC}"
        sleep 2; exit 1
    fi

    # Nhập Port OpenClaw (Mặc định thường là 18789)
    echo -n "Nhập Port của OpenClaw (Mặc định: 18789): "
    read port
    port=${port:-18789}
fi

# 2. Check Valid Domain (Sơ bộ)
if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}Lỗi: Định dạng domain không hợp lệ!${NC}"
    sleep 2; exit 1
fi

# 3. Đổi hostname hệ thống
echo -e "${YELLOW}[1/4] Đang đổi hostname hệ thống thành $domain...${NC}"
hostnamectl set-hostname "$domain"
echo "127.0.0.1 $domain" >> /etc/hosts

# 4. Tạo cấu hình Nginx Proxy (HTTP trước để Certbot verify)
echo -e "${YELLOW}[2/4] Đang tạo cấu hình Nginx Proxy cho port $port...${NC}"
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
        
        # Hỗ trợ Websocket (Cần cho một số AI Channels)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

ln -sf "$CONF_FILE" "/etc/nginx/sites-enabled/"
nginx -t && systemctl restart nginx

# 5. Cài đặt SSL Let's Encrypt
echo -e "${YELLOW}[3/4] Đang tiến hành cài đặt SSL (Let's Encrypt)...${NC}"
echo -e "${BLUE}Lưu ý: Domain phải được trỏ IP về VPS này trước khi thực hiện.${NC}"

certbot --nginx -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[4/4] Cài đặt SSL thành công!${NC}"
    echo -e "${GREEN}Domain: https://$domain${NC}"
else
    echo -e "${RED}Lỗi: Không thể cài đặt SSL. Hãy kiểm tra lại DNS của domain.${NC}"
fi

# 6. Cập nhật OpenClaw Config
echo -e "${YELLOW}>> Đang cập nhật Allowed Origins cho OpenClaw Dashboard...${NC}"
if command -v openclaw &> /dev/null; then
    openclaw config set gateway.controlUi.allowedOrigins "https://$domain" > /dev/null 2>&1
    systemctl restart openclaw > /dev/null 2>&1
    echo -e "${GREEN}Đã cấu hình OpenClaw nhận diện Domain mới!${NC}"
fi

echo -e "${BLUE}------------------------------------------------${NC}"
if [ "$AUTO_MODE" -ne 1 ]; then
    read -p "Nhấn Enter để quay lại menu..."
fi
