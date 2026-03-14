#!/bin/sh
set -eu

STATUS_TMP=$(mktemp)
GATEWAY_TMP=$(mktemp)
cleanup() {
  rm -f "$STATUS_TMP" "$GATEWAY_TMP"
}
trap cleanup EXIT INT TERM

printf 'KIỂM TRA DỊCH VỤ OPENCLAW\n'
printf 'Thời gian (UTC): %s\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

if ! command -v openclaw >/dev/null 2>&1; then
  echo 'Lỗi: không tìm thấy lệnh openclaw.'
  exit 1
fi

if ! openclaw status >"$STATUS_TMP" 2>&1; then
  echo 'Không lấy được thông tin từ openclaw status.'
  echo
  cat "$STATUS_TMP"
  exit 1
fi

if ! openclaw gateway status >"$GATEWAY_TMP" 2>&1; then
  echo 'Không lấy được thông tin từ openclaw gateway status.'
  echo
  cat "$GATEWAY_TMP"
  exit 1
fi

extract_value() {
  label="$1"
  file="$2"
  grep -F "$label" "$file" | head -n 1 | sed "s/.*│ $label[[:space:]]*│ //" | sed 's/[[:space:]]*│[[:space:]]*$//' | sed 's/[[:space:]]*$//'
}

extract_after_colon() {
  label="$1"
  file="$2"
  grep -F "$label" "$file" | head -n 1 | sed "s/^.*$label[[:space:]]*//"
}

OVERVIEW_GATEWAY=$(extract_value 'Gateway service' "$STATUS_TMP" || true)
CHANNEL_TELEGRAM=$(grep -F '│ Telegram │' "$STATUS_TMP" | head -n 1 | sed 's/.*│ Telegram │ //' | sed 's/[[:space:]]*│.*//' || true)
SECURITY_SUMMARY=$(grep -F 'Summary:' "$STATUS_TMP" | head -n 1 | sed 's/^Summary:[[:space:]]*//' || true)
DASHBOARD=$(extract_after_colon 'Dashboard:' "$GATEWAY_TMP" || true)
RUNTIME=$(extract_after_colon 'Runtime:' "$GATEWAY_TMP" || true)
LISTENING=$(extract_after_colon 'Listening:' "$GATEWAY_TMP" || true)
RPC=$(extract_after_colon 'RPC probe:' "$GATEWAY_TMP" || true)
LOG_FILE=$(extract_after_colon 'File logs:' "$GATEWAY_TMP" || true)
CONFIG_FILE=$(extract_after_colon 'Config (service):' "$GATEWAY_TMP" || true)

printf 'TÓM TẮT CHÍNH\n'
printf '%s\n' '------------------------------'

if [ -n "$OVERVIEW_GATEWAY" ]; then
  printf '• Dịch vụ Gateway: %s\n' "$OVERVIEW_GATEWAY"
else
  printf '%s\n' '• Dịch vụ Gateway: không xác định'
fi

if [ -n "$RUNTIME" ]; then
  printf '• Trạng thái runtime: %s\n' "$RUNTIME"
fi

if [ -n "$RPC" ]; then
  printf '• Kết nối RPC: %s\n' "$RPC"
fi

if [ -n "$LISTENING" ]; then
  printf '• Cổng đang lắng nghe: %s\n' "$LISTENING"
fi

if [ -n "$DASHBOARD" ]; then
  printf '• Dashboard: %s\n' "$DASHBOARD"
fi

if [ -n "$CHANNEL_TELEGRAM" ]; then
  printf '• Telegram: %s\n' "$CHANNEL_TELEGRAM"
fi

if [ -n "$SECURITY_SUMMARY" ]; then
  printf '• Tóm tắt bảo mật: %s\n' "$SECURITY_SUMMARY"
fi

if [ -n "$CONFIG_FILE" ]; then
  printf '• File cấu hình: %s\n' "$CONFIG_FILE"
fi

if [ -n "$LOG_FILE" ]; then
  printf '• File log: %s\n' "$LOG_FILE"
fi

printf '\nCẢNH BÁO QUAN TRỌNG\n'
printf '%s\n' '------------------------------'
WARNINGS=$(awk '
  /^  CRITICAL / || /^  WARN / {
    line=$0
    sub(/^  (CRITICAL|WARN) /, "", line)
    print "- " line
    count++
    if (count >= 5) exit
  }
' "$STATUS_TMP")

if [ -n "$WARNINGS" ]; then
  printf '%s\n' "$WARNINGS"
else
  printf '%s\n' 'Không thấy cảnh báo quan trọng.'
fi

printf '\nGỢI Ý\n'
printf '%s\n' '------------------------------'
if [ -n "$SECURITY_SUMMARY" ]; then
  printf '%s\n' '- Nếu có CRITICAL/WARN, nên chạy: openclaw security audit'
fi
printf '%s\n' '- Xem đầy đủ trạng thái: openclaw status'
printf '%s\n' '- Xem log realtime: openclaw logs --follow'
printf '%s\n' '- Kiểm tra gateway chi tiết: openclaw gateway status'