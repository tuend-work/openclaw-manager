#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_commands() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}       LỆNH OPENCLAW THƯỜNG DÙNG (OCM)          ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "1. Kiểm tra trạng thái Gateway (Status)"
    echo -e "2. Xem log Gateway mới nhất (Logs)"
    echo -e "3. Danh sách thiết bị đã kết nối (Devices)"
    echo -e "4. Danh sách các AI Agents (Agents)"
    echo -e "5. Danh sách các Skills đã cài (Skills)"
    echo -e "6. Xem thông tin Dashboard (URL/Token)"
    echo -e "7. Xem nội dung cấu hình (Config View)"
    echo -e "8. Chạy kiểm tra hệ thống (Onboarding Check)"
    echo -e "9. Khởi động lại dịch vụ OpenClaw (Restart)"
    echo -e "10. Cập nhật OpenClaw Core lên bản mới nhất"
    echo -e "0. Quay lại Menu chính"
    echo -e "${BLUE}================================================${NC}"
    echo -n "Chọn lệnh để chạy [0-10]: "
}

while true; do
    show_commands
    read choice
    echo -e "${BLUE}------------------------------------------------${NC}"
    case $choice in
        1) openclaw gateway status ;;
        2) openclaw gateway logs --lines 20 ;;
        3) openclaw devices list ;;
        4) openclaw agents list ;;
        5) openclaw skills list ;;
        6) openclaw dashboard ;;
        7) openclaw config view ;;
        8) openclaw onboard --check ;;
        9) systemctl restart openclaw && echo -e "${GREEN}Đã gửi lệnh Restart dịch vụ.${NC}" ;;
        10) curl -fsSL https://openclaw.ai/install.sh | bash ;;
        0) exit 0 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ!${NC}" ;;
    esac
    echo -e "${BLUE}------------------------------------------------${NC}"
    read -p "Nhấn Enter để tiếp tục..."
done
