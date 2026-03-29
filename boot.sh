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

# CHỜ FIRST BOOT SETUP NẾU ĐANG CHẠY BACKGROUND
LOG_FILE="/var/log/ocm_first_boot.log"
if [ -f "$LOG_FILE" ] && ! grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE"; then
    echo -e "${YELLOW}⏳ OpenClaw đang được cài đặt trong lần khởi động đầu tiên...${NC}"
    echo -e "${YELLOW}Vui lòng chờ giây lát hoặc xem log tại: $LOG_FILE${NC}"
    for i in {1..60}; do
        if grep -q "FIRST BOOT SETUP HOÀN TẤT" "$LOG_FILE" 2>/dev/null; then break; fi
        sleep 2
    done
fi

# CHUYỂN HƯỚNG SANG TRÌNH KHỞI TẠO NHANH (SETUP WIZARD) MỚI
if [ -f "$MANAGER_DIR/SetupWizard.sh" ]; then
    exec bash "$MANAGER_DIR/SetupWizard.sh"
else
    # Fallback nếu không thấy wizard
    exec bash "$MANAGER_DIR/menu.sh"
fi
