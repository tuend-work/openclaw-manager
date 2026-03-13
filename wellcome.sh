
# OpenClaw Manager Welcome Banner
# Showed upon SSH login

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}       WELCOME TO OPEN-CLAW MANAGER (OCM)       ${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Trạng thái hệ thống: ${GREEN}Đang hoạt động${NC}"
echo -e "Phiên bản OCM: ${YELLOW}v1.0.0${NC}"
echo -e "Địa chỉ IP: ${BLUE}$(hostname -I | awk '{print $1}')${NC}"
echo -e ""
echo -e "Gõ lệnh ${YELLOW}ocm${NC} để mở Menu quản trị hệ thống."
echo -e "${BLUE}================================================${NC}"