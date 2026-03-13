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
    echo -e "   ${BLUE}→ Lệnh: openclaw gateway status${NC}"
    echo -e "2. Xem log Gateway mới nhất (Logs)"
    echo -e "   ${BLUE}→ Lệnh: openclaw logs --limit 20${NC}"
    echo -e "3. Danh sách thiết bị đã kết nối (Devices)"
    echo -e "   ${BLUE}→ Lệnh: openclaw devices list${NC}"
    echo -e "4. Danh sách các AI Agents (Agents)"
    echo -e "   ${BLUE}→ Lệnh: openclaw agents list${NC}"
    echo -e "5. Danh sách các Skills đã cài (Skills)"
    echo -e "   ${BLUE}→ Lệnh: openclaw skills list${NC}"
    echo -e "6. Xem thông tin Dashboard (URL/Token)"
    echo -e "   ${BLUE}→ Lệnh: openclaw dashboard${NC}"
    echo -e "7. Xem nội dung cấu hình (Config View)"
    echo -e "   ${BLUE}→ Lệnh: openclaw config view${NC}"
    echo -e "8. Chạy kiểm tra hệ thống (Onboarding Check)"
    echo -e "   ${BLUE}→ Lệnh: openclaw onboard --check${NC}"
    echo -e "9. Khởi động lại dịch vụ OpenClaw (Restart)"
    echo -e "   ${BLUE}→ Lệnh: systemctl restart openclaw${NC}"
    echo -e "10. Cập nhật OpenClaw Core lên bản mới nhất"
    echo -e "    ${BLUE}→ Lệnh: curl ... | bash${NC}"
    echo -e "11. Kiểm tra trạng thái TẤT CẢ (Status All)"
    echo -e "    ${BLUE}→ Lệnh: openclaw status --all${NC}"
    echo -e "12. Kiểm tra kết nối Kênh Chat (Probe Channels)"
    echo -e "    ${BLUE}→ Lệnh: openclaw channels status --probe${NC}"
    echo -e "13. Xem Log thời gian thực (Follow Logs)"
    echo -e "    ${BLUE}→ Lệnh: openclaw logs --follow${NC}"
    echo -e "14. Kiểm tra sức khỏe Model (Models Status)"
    echo -e "    ${BLUE}→ Lệnh: openclaw models status${NC}"
    echo -e "15. Kiểm tra Port 18789 (Check Port Conflict)"
    echo -e "    ${BLUE}→ Lệnh: lsof -i :18789${NC}"
    echo -e "0. Quay lại Menu chính"
    echo -e "${BLUE}================================================${NC}"
    echo -n "Chọn lệnh để chạy [0-15]: "
}

while true; do
    show_commands
    read choice
    echo -e "${BLUE}------------------------------------------------${NC}"
    case $choice in
        1) 
            echo -e "${YELLOW}Lệnh: openclaw gateway status${NC}"
            openclaw gateway status ;;
        2) 
            echo -e "${YELLOW}Lệnh: openclaw logs --limit 20${NC}"
            openclaw logs --limit 20 ;;
        3) 
            echo -e "${YELLOW}Lệnh: openclaw devices list${NC}"
            openclaw devices list ;;
        4) 
            echo -e "${YELLOW}Lệnh: openclaw agents list${NC}"
            openclaw agents list ;;
        5) 
            echo -e "${YELLOW}Lệnh: openclaw skills list${NC}"
            openclaw skills list ;;
        6) 
            echo -e "${YELLOW}Lệnh: openclaw dashboard${NC}"
            openclaw dashboard ;;
        7) 
            echo -e "${YELLOW}Lệnh: openclaw config view${NC}"
            openclaw config view ;;
        8) 
            echo -e "${YELLOW}Lệnh: openclaw onboard --check${NC}"
            openclaw onboard --check ;;
        9) 
            echo -e "${YELLOW}Lệnh: systemctl restart openclaw${NC}"
            systemctl restart openclaw && echo -e "${GREEN}Đã gửi lệnh Restart dịch vụ.${NC}" ;;
        10) 
            echo -e "${YELLOW}Lệnh: curl -fsSL https://openclaw.ai/install.sh | bash${NC}"
            curl -fsSL https://openclaw.ai/install.sh | bash ;;
        11) 
            echo -e "${YELLOW}Lệnh: openclaw status --all${NC}"
            openclaw status --all ;;
        12) 
            echo -e "${YELLOW}Lệnh: openclaw channels status --probe${NC}"
            openclaw channels status --probe ;;
        13) 
            echo -e "${YELLOW}Lệnh: openclaw logs --follow${NC}"
            echo -e "${BLUE}(Nhấn Ctrl+C để dừng theo dõi log)${NC}"
            openclaw logs --follow ;;
        14) 
            echo -e "${YELLOW}Lệnh: openclaw models status${NC}"
            openclaw models status ;;
        15) 
            echo -e "${YELLOW}Lệnh: lsof -i :18789${NC}"
            if command -v lsof &> /dev/null; then
                lsof -i :18789
            else
                netstat -tuln | grep 18789
            fi ;;
        0) exit 0 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ!${NC}" ;;
    esac
    echo -e "${BLUE}------------------------------------------------${NC}"
    read -p "Nhấn Enter để tiếp tục..."
done
