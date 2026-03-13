# 🤖 OpenClaw Manager (OCM)

**OpenClaw Manager** là một bộ công cụ dòng lệnh (CLI) mạnh mẽ được thiết kế để quản lý và vận hành hệ thống [OpenClaw](https://openclaw.ai) một cách chuyên nghiệp và tối giản. Với giao diện menu trực quan (theo phong cách VPSSIM/HOCVPS), OCM giúp bạn làm chủ quy trình cài đặt, cấu hình Domain/SSL và quản lý các agent AI chỉ với vài phím bấm.

---

## ✨ Tính năng nổi bật

- 🚀 **Giao diện Menu trực quan**: Thao tác nhanh với các phím số, không cần nhớ lệnh phức tạp.
- 🌐 **Quản lý Domain & SSL**: Tự động hóa cấu hình Nginx Reverse Proxy và cấp chứng chỉ Let's Encrypt.
- 🤖 **Quản lý AI & Channels**: Điều chỉnh cấu hình LLMs và các kênh kết nối (Telegram, WhatsApp, Discord...).
- 🛠️ **Hệ thống điều khiển**: Quản lý dịch vụ (Start/Stop/Restart) và theo dõi log thời gian thực.
- ⚡ **Truy cập cực nhanh**: Tích hợp phím tắt `ocm` và tự động hiển thị menu khi đăng nhập (SSH Welcome).

---

## 📥 Hướng dẫn cài đặt

Bạn có thể cài đặt OpenClaw Manager lên VPS bằng cách sử dụng script tự động hóa:

### Bước 1: Tải về và chuẩn bị
```bash
git clone https://github.com/tuend-work/openclaw-manager.git
cd /root/openclaw-manager
```

### Bước 2: Chạy Script cài đặt
```bash
chmod +x install.sh
./install.sh
```

### Bước 3: Áp dụng thay đổi
```bash
source ~/.bashrc
```

---

## 🎮 Cách sử dụng

Sau khi cài đặt thành công, bạn có hai cách để truy cập OpenClaw Manager:

1.  **Tự động**: Menu sẽ hiển thị ngay khi bạn thực hiện kết nối SSH vào máy chủ.
2.  **Lệnh gõ nhanh**: Nhập lệnh sau từ bất cứ đâu trong Terminal:
    ```bash
    ocm
    ```

### 📋 Menu Chức năng:
1.  **Quản lý Domain & SSL**: Cài đặt domain mới, cấu hình Proxy và Certbot.
2.  **Quản lý AI**: Cấu hình các mô hình ngôn ngữ và API Keys.
3.  **Quản lý Kênh Chat**: Kết nối các nền tảng tin nhắn.
4.  **Quản lý phiên bản**: Cập nhật hoặc hạ cấp OpenClaw.
5.  **Nhật ký hệ thống**: Xem logs hoạt động để xử lý lỗi.
6.  **Điều khiển dịch vụ**: Bật/Tắt các services của OpenClaw.

---

## 📂 Cấu trúc thư mục

Tất cả các thành phần được lưu trữ tập trung tại: `/root/openclaw-manager/`

- `menu.sh`: Script điều khiển chính.
- `install.sh`: Bộ cài đặt và cấu hình hệ thống.
- `manage_*.sh`: Các module chức năng riêng biệt.
- `wellcome.sh`: Script chào mừng khi login SSH.

---

## ⚠️ Lưu ý
Hệ thống này yêu cầu quyền **root**. Hãy đảm bảo vps của bạn chạy trên nền tảng Ubuntu/Debian để có sự tương thích tốt nhất với `apt` và `nginx`.

---
*Phát triển bởi OpenClaw Community - Tối ưu hóa cho sự đơn giản và hiệu quả.*