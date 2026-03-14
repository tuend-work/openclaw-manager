#!/bin/bash

# Thư mục quản lý
MANAGER_DIR="/root/openclaw-manager"
LAST_HOSTNAME_FILE="$MANAGER_DIR/cronjob/.last_hostname"
CURRENT_HOSTNAME=$(hostname)

# Bỏ qua kiểm tra nếu hostname là các giá trị mặc định của HĐH chưa chuyển giao xong
if [[ "$CURRENT_HOSTNAME" == "localhost" || "$CURRENT_HOSTNAME" == "ubuntu" || "$CURRENT_HOSTNAME" == "debian" ]]; then
    exit 0
fi

# Đợi vài giây để đảm bảo card mạng và các dịch vụ đã khởi động xong trước khi chạy ssl
sleep 15

if [ -f "$LAST_HOSTNAME_FILE" ]; then
    LAST_HOSTNAME=$(cat "$LAST_HOSTNAME_FILE")
    
    if [ "$CURRENT_HOSTNAME" != "$LAST_HOSTNAME" ] && [ -n "$CURRENT_HOSTNAME" ]; then
        # Hostname đã thay đổi sau khi reboot! Tiến hành tự động cập nhật Domain & SSL
        
        # Chạy script manage_domain ở chế độ AUTO (không cần bấm phím)
        bash "$MANAGER_DIR/manage_domain.sh" "$CURRENT_HOSTNAME" 18789 > /var/log/ocm_auto_domain.log 2>&1
        
        # Cập nhật lại hostname đã check
        echo "$CURRENT_HOSTNAME" > "$LAST_HOSTNAME_FILE"
    fi
else
    # Lần đầu tiên chạy hoặc vừa mới cài đặt script
    echo "$CURRENT_HOSTNAME" > "$LAST_HOSTNAME_FILE"
fi
