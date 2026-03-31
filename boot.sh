#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - BOOT WRAPPER (Legacy Support)
# Chuyển hướng các VPS cũ vẫn đang gọi boot.sh sang SetupWizard.sh
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )" &> /dev/null && pwd )"

# Chạy cập nhật silent trước
if [ -f "$MANAGER_DIR/scripts/check_update_silent.sh" ]; then
    bash "$MANAGER_DIR/scripts/check_update_silent.sh"
fi

# LOAD MÀU SẮC
YELLOW='\033[1;33m'
NC='\033[0m'

# BẮT BUỘC CHỜ CÀI ĐẶT HOÀN TẤT (KHÔNG CHO CTRL+C THOÁT)
LOG_FILE="/var/log/ocm_first_boot.log"

if [ -f "$LOG_FILE" ] && ! grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE"; then
    # Chặn Ctrl+C
    trap "echo -e '\n${RED}⚠️ CHÚ Ý: Vui lòng chờ cài đặt hoàn tất, tuyệt đối không quay lại Shell!${NC}'" SIGINT SIGTERM
    
    while ! grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE" 2>/dev/null; do
        clear
        echo -e "${YELLOW}================================================${NC}"
        echo -e "${RED}         ⚠️ HỆ THỐNG ĐANG ĐƯỢC CÀI ĐẶT           ${NC}"
        echo -e "${YELLOW}================================================${NC}"
        echo -e "${CYAN}Vui lòng chờ. Quá trình này đang diễn ra tự động.${NC}"
        echo -e "${CYAN}OpenClaw Manager sẽ tự động mở Menu ngay sau khi hoàn tất.${NC}"
        echo -e "${BLUE}------------------------------------------------${NC}"
        echo ""
        
        # Touch để đảm bảo file tồn tại
        touch "$LOG_FILE"
        # Xem log (nếu Ctrl+C thì chỉ thoát tail, vòng lặp while sẽ chạy lại)
        tail -f --retry "$LOG_FILE" | grep --line-buffered -v "FIRST BOOT SETUP HOÀN TẤT" # Hiển thị mọi thứ trừ dòng kết thúc để while tự ngắt
        
        # Kiểm tra lại ngay sau khi tail bị ngắt
        if grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    
    # Giải phóng trap để Ctrl+C hoạt động lại bình thường trong Menu
    trap - SIGINT SIGTERM
    echo -e "\n${GREEN}✅ CÀI ĐẶT ĐÃ HOÀN TẤT! Đang chuẩn bị vào hệ thống...${NC}"
    sleep 2
fi

# CHUYỂN HƯỚNG THÔNG MINH
# Nếu là lần đầu (chưa có tệp đánh dấu) -> Chạy SetupWizard
# Nếu đã xong -> Chạy Menu chính
WIZARD_DONE="$HOME/.openclaw/.wizard_done"

if [ ! -f "$WIZARD_DONE" ] && [ -f "$MANAGER_DIR/SetupWizard.sh" ]; then
    exec bash "$MANAGER_DIR/SetupWizard.sh"
else
    # Fallback/Default: Mở thẳng menu quản lý
    exec bash "$MANAGER_DIR/menu.sh"
fi
