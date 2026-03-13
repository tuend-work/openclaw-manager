Tôi muốn viết một số script quản lý nhanh Openclaw. vừa login thì script sẽ chạy ra 1 menu cho phép user chọn số trong menu (giống WPTangToc, VPSSIM, HOCVPS Script)
Menu chức năng gồm: 
1. Quản lý Domain & SSL (Chọn chức năng này thì nó sẽ hiện ô nhập domain mới. User nhập xong thì tool sẽ check valid và thực hiện đổi hostname, cài SSL, sửa config proxy cho hostname đến port của openclaw)
2. Quản lý AI
3. Quản lý Kênh Chat
4. Quản lý phiên bản
5. Nhật ký hệ thống
6. Điều khiển dịch vụ

Mỗi file nằm trong thư mục /root/openclaw-manager/ là một chức năng. Giúp tôi tạo file trước.