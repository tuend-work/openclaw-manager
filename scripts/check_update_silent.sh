#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - AUTOMATIC UPDATE (SILENT)
# Khởi chạy từ .bashrc khi root login / sudo -i
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )/.." &> /dev/null && pwd )"

# Kiểm tra git repo
if [ ! -d "$MANAGER_DIR/.git" ]; then
    exit 0
fi

cd "$MANAGER_DIR" || exit 0

# Fetch nhanh (Chạy ngầm với timeout 3s)
(git fetch --quiet origin main > /dev/null 2>&1) &
FETCH_PID=$!
sleep 3 
if kill -0 $FETCH_PID 2>/dev/null; then
    kill $FETCH_PID 2>/dev/null
    exit 0
fi

LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null)
REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null)

# Nếu có bản cập nhật mới -> Tự động update không cần hỏi
if [ -n "$REMOTE_HASH" ] && [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    YELLOW='\033[0;93m'
    GREEN='\033[0;92m'
    CYAN='\033[0;96m'
    NC='\033[0m'

    echo -ne "${CYAN}[OCM]${NC} ${YELLOW}Phát hiện bản cập nhật mới. Đang tự động nâng cấp...${NC}"
    
    # Thực hiện update cứng
    git reset --hard origin/main > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        # Cấp lại quyền thực thi
        chmod +x "$MANAGER_DIR"/*.sh 2>/dev/null
        chmod +x "$MANAGER_DIR"/scripts/*.sh 2>/dev/null
        chmod +x "$MANAGER_DIR"/cronjob/*.sh 2>/dev/null
        echo -e " ${GREEN}✅ Xong!${NC}"
    else
        echo -e " ${RED}❌ Lỗi update.${NC}"
    fi
fi
