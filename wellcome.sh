
# OpenClaw Manager Welcome Script
# Để chạy menu này nhanh, bạn có thể thêm alias vào .bashrc:
# alias ocm='bash /root/openclaw-manager/menu.sh'

if [ -f "/root/openclaw-manager/menu.sh" ]; then
    bash "/root/openclaw-manager/menu.sh"
else
    echo "Lỗi: Không tìm thấy menu.sh trong /root/openclaw-manager/"
fi