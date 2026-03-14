#!/bin/bash

# =========================================================
# OPENCLAW MANAGER - GET FREE MODEL SCRIPT (BASH VERSION)
# =========================================================

# Configuration
CONFIG_PATH="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
API_URL="https://openrouter.ai/api/v1/models"
TIMEOUT=15

# Modern Colors
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
CYAN='\033[0;96m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}🚀 Bắt đầu đồng bộ và kiểm tra AI Miễn phí...${NC}"

# Đảm bảo jq được cài đặt
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Công cụ 'jq' chưa được cài đặt. Đang tiến hành cài đặt...${NC}"
    sudo apt-get update && sudo apt-get install -y jq >/dev/null 2>&1
fi

# 1. Fetch danh sách từ API
echo -e "${CYAN}1. Lấy danh sách model free từ OpenRouter API...${NC}"
FREE_MODELS_JSON=$(curl -s "$API_URL" | jq -c '[.data[] | select(.id | endswith(":free"))]')

if [ -z "$FREE_MODELS_JSON" ] || [ "$FREE_MODELS_JSON" == "[]" ]; then
    echo -e "${RED}Không tìm thấy model miễn phí nào từ API.${NC}"
    exit 1
fi

MODEL_IDS=$(echo "$FREE_MODELS_JSON" | jq -r '.[].id' | awk '{print "openrouter/"$0}')
MODEL_ARRAY=($MODEL_IDS)
TOTAL=${#MODEL_ARRAY[@]}
echo -e "   ➜ Tìm thấy ${GREEN}${TOTAL}${NC} models miễn phí."

# 2. Xóa các model free hiện tại (Dọn dẹp JSON theo yêu cầu)
if [ -f "$CONFIG_PATH" ]; then
    echo -e "${CYAN}2. Xóa danh sách model free cũ trong cấu hình...${NC}"
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"
    # Dùng jq để xóa các model cũ có catalog là "openrouter-free"
    jq '
      if .agents?.defaults?.models then
        .agents.defaults.models |= with_entries(select(.value.catalog != "openrouter-free"))
      else
        .
      end
    ' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp" && mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
fi

# Xoá fallback queue cũ 
openclaw models fallbacks clear > /dev/null 2>&1

# 3. Test Tool Call models
echo -e "${CYAN}3. Thử nghiệm khả năng Tool Call và đo tốc độ (Background Parallel)...${NC}"
echo -e "${GRAY}   - Quá trình sẽ call API gửi yêu cầu Tool Call tới ${TOTAL} AI cùng lúc.${NC}"

TMP_DIR=$(mktemp -d)

test_model() {
    local m=$1
    local out_file=$2
    local start_time=$(date +%s%N)
    
    # 1. Trích xuất API Key từ .env hoặc cấu hình openclaw
    local api_key=""
    if [ -f "$HOME/.openclaw/.env" ]; then
        api_key=$(grep "^OPENROUTER_API_KEY=" "$HOME/.openclaw/.env" | cut -d '=' -f 2- | tr -d '"' | tr -d "'")
    fi
    if [ -z "$api_key" ] && [ -f "$CONFIG_PATH" ]; then
        api_key=$(jq -r '.auth.profiles."openrouter:default".credentials.apiKey // empty' "$CONFIG_PATH")
    fi

    # 2. Xử lý tên model chuẩn cho API
    local api_model="${m#openrouter/}"
    
    # 3. Payload JSON yêu cầu Tool Call
    local payload=$(cat <<EOF
{
  "model": "${api_model}",
  "messages": [
    {"role": "user", "content": "What is the weather in Tokyo right now?"}
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get current weather in a location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {"type": "string", "description": "City name"}
          },
          "required": ["location"]
        }
      }
    }
  ],
  "tool_choice": "auto"
}
EOF
)

    # 4. Gọi OpenRouter API bằng curl
    local response=$(curl -s -w "\n%{http_code}" -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: https://github.com/openclaw/openclaw" \
        -H "X-Title: OpenClaw Manager" \
        -d "$payload" \
        --max-time "$TIMEOUT")
        
    # 5. Phân tích kết quả trả về
    local http_status=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | head -n -1)
    
    # Kiểm tra mã HTTP 200 và xác minh có property 'tool_calls' trong JSON
    if [ "$http_status" -eq 200 ] && echo "$body" | jq -e '.choices[0].message.tool_calls | length > 0' > /dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local delta=$(( (end_time - start_time) / 1000000 ))
        echo "$delta $m" > "$out_file"
    fi
}

# Chạy đa luồng tất cả các model
for i in "${!MODEL_ARRAY[@]}"; do
    test_model "${MODEL_ARRAY[$i]}" "$TMP_DIR/res_${i}" &
done

# Thanh tiến trình giả lập
echo -n "   ➜ Đang đợi hệ thống phản hồi: ["
for ((i=0; i<$((TIMEOUT * 2)); i++)); do
    echo -n "●"
    sleep 0.5
done
echo -e "] ${GREEN}Hoàn tất!${NC}"

# 4. Gom kết quả
declare -a AVAILABLE_MODELS=()
FASTEST_MODEL=""
MIN_TIME=999999

# Đọc kết quả từ các file tạm do process con ghi ra
for f in "$TMP_DIR"/res_*; do
    if [ -f "$f" ]; then
        t=$(awk '{print $1}' "$f")
        mod=$(awk '{print $2}' "$f")
        if [ -n "$t" ] && [ -n "$mod" ]; then
            AVAILABLE_MODELS+=("$mod")
            if [ "$t" -lt "$MIN_TIME" ]; then
                MIN_TIME=$t
                FASTEST_MODEL=$mod
            fi
        fi
    fi
done

# Dọn dẹp RAM/Disk
rm -rf "$TMP_DIR"

echo -e "\n${CYAN}4. KẾT QUẢ & CẤU HÌNH TỰ ĐỘNG:${NC}"

if [ ${#AVAILABLE_MODELS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Không có model nào vượt qua bài kiểm tra Tool Call. Đặt mặc định openrouter/auto.${NC}"
    openclaw models set "openrouter/auto" > /dev/null 2>&1
else
    echo -e "   🥇 ${BOLD}Nhanh nhất (Gán làm Primary Model):${NC} ${GREEN}$FASTEST_MODEL${NC} (${MIN_TIME}ms)"
    openclaw models set "$FASTEST_MODEL" > /dev/null 2>&1
    
    fb_count=0
    for m in "${AVAILABLE_MODELS[@]}"; do
        if [ "$m" != "$FASTEST_MODEL" ]; then
            openclaw models fallbacks add "$m" > /dev/null 2>&1
            fb_count=$((fb_count + 1))
        fi
    done
    echo -e "   ➜ Nạp thêm ${GREEN}${fb_count}${NC} models dự phòng vào Fallbacks."
fi

echo -e "\n${GREEN}✅ Quy trình tối ưu hóa thành công!${NC}"
