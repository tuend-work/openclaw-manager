#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - SILENT UPDATE CHECKER
# =========================================================

REAL_PATH=$(readlink -f "${BASH_SOURCE[0]}")
MANAGER_DIR="$( cd "$( dirname "$REAL_PATH" )/.." &> /dev/null && pwd )"

# Check if git repo
if [ ! -d "$MANAGER_DIR/.git" ]; then
    exit 0
fi

cd "$MANAGER_DIR" || exit 0

# Fetch in background to avoid login lag
# We assume fetch was done by boot.sh or we do a quick one.
# To be truly silent and fast, we just compare if FETCH_HEAD exists and is recent.
(git fetch --quiet origin main > /dev/null 2>&1) &
FETCH_PID=$!

# Wait max 2 seconds for a quick check, if slower, we skip this login
sleep 2
if kill -0 $FETCH_PID 2>/dev/null; then
    # Still fetching, too slow, just exit
    kill $FETCH_PID 2>/dev/null
    exit 0
fi

LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null)
REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null)

if [ -n "$REMOTE_HASH" ] && [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    # Colors
    YELLOW='\033[0;93m'
    CYAN='\033[0;96m'
    WHITE='\033[0;97m'
    BOLD='\033[1m'
    GREEN='\033[0;92m'
    NC='\033[0m'

    echo -e "\n${CYAN}┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}${YELLOW}🔔 CẬP NHẬT MỚI: OPENCLAW MANAGER (OCM)${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
    echo -e " ${WHITE}●${NC} Đã có phiên bản mới trên GitHub."
    echo -e " ${WHITE}●${NC} Gõ ${BOLD}${GREEN}ocm update${NC} để cập nhật ngay."
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}\n"
fi
