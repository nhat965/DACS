# Giai đoạn 1 - Phân tích, thiết kế và chuẩn bị dữ liệu

## 1. Phân tích yêu cầu

### Yêu cầu chức năng

| Nhóm | Chức năng |
|---|---|
| Khách hàng | Đăng ký, đăng nhập, quản lý tài khoản |
| Khách hàng | Xem danh mục, chi tiết sản phẩm, tìm kiếm và lọc |
| Khách hàng | Yêu thích, giỏ hàng, đặt hàng, thanh toán mô phỏng |
| Khách hàng | Đánh giá sản phẩm sau khi mua |
| Khách hàng | Nhận gợi ý sản phẩm cá nhân hóa |
| Khách hàng | Chatbot tư vấn sản phẩm |
| Quản trị | Quản lý sản phẩm, danh mục, thương hiệu |
| Quản trị | Quản lý đơn hàng, người dùng, đánh giá |
| Quản trị | Xem dashboard phân tích |
| Hệ thống | Ghi nhận hành vi người dùng |
| Hệ thống | Xây hồ sơ sở thích người dùng |
| Hệ thống | Tính recommendation bằng KB, CB, CF và Hybrid |
| Hệ thống | Tổng hợp dữ liệu phục vụ dashboard |

### Yêu cầu phi chức năng

| Nhóm | Yêu cầu |
|---|---|
| Hiệu năng | API danh sách sản phẩm và gợi ý cần phản hồi đủ nhanh cho demo local |
| Bảo mật | Không lưu mật khẩu thô, phân quyền CUSTOMER/ADMIN |
| Dữ liệu | Dữ liệu sản phẩm có nguồn, ngày xác minh và quy tắc chuẩn hóa |
| Khả mở rộng | Tách website, recommendation, chatbot, analytics theo module/service |
| Khả bảo trì | API contract và event contract được thống nhất trước khi tích hợp |
| An toàn tư vấn | Chatbot không chẩn đoán bệnh, không cam kết điều trị |

### Đối tượng sử dụng

| Đối tượng | Nhu cầu |
|---|---|
| Khách hàng mới | Tìm sản phẩm phù hợp khi chưa có lịch sử mua hàng |
| Khách hàng quay lại | Nhận gợi ý dựa trên hành vi và sở thích |
| Quản trị viên | Quản lý sản phẩm, đơn hàng, người dùng và xem dashboard |
| Nhóm phát triển | Có ranh giới source rõ ràng để làm việc song song |

## 2. Kiến trúc tổng thể

Kiến trúc chia thành 4 lớp chính:

1. `apps/web`: giao diện website và admin.
2. Backend/API Gateway: nhận request từ website, điều phối tới module/service.
3. Internal System Services: recommendation, chatbot, analytics, stream analytics.
4. Data Layer: MySQL database, product dataset, behavior events.

Chi tiết chia source nằm ở `docs/architecture/source-split-and-ownership.md`.

## 3. Use Case chính

| Actor | Use Case |
|---|---|
| Khách hàng | Đăng ký/đăng nhập |
| Khách hàng | Tìm kiếm và lọc sản phẩm |
| Khách hàng | Xem chi tiết sản phẩm |
| Khách hàng | Nhận gợi ý cá nhân hóa |
| Khách hàng | Chat với chatbot tư vấn |
| Khách hàng | Thêm vào giỏ hàng và đặt hàng |
| Khách hàng | Đánh giá sản phẩm |
| Admin | Quản lý danh mục, thương hiệu, sản phẩm |
| Admin | Quản lý đơn hàng và người dùng |
| Admin | Xem dashboard phân tích |
| Hệ thống | Ghi nhận behavior event |
| Hệ thống | Cập nhật user profile |
| Hệ thống | Tính toán điểm gợi ý |

## 4. Thiết kế cơ sở dữ liệu

Migration ban đầu nằm ở `database/migrations/001_initial_schema.sql`.

Các nhóm bảng chính:

- Ecommerce: `users`, `brands`, `categories`, `products`, `orders`, `order_items`.
- AI/Data: `user_behavior_events`, `user_profiles`, `recommendation_logs`, `chatbot_conversations`.

Data dictionary nằm ở `database/docs/data-dictionary.md`.

## 5. Product Dataset

Schema dataset mẫu nằm ở `datasets/product-catalog/product_dataset_schema.csv`.

### Thông tin cần thu thập

- SKU, tên sản phẩm, thương hiệu, danh mục.
- Giá, dung tích, hình ảnh.
- Mô tả, công dụng, hướng dẫn sử dụng.
- Thành phần INCI, thành phần chính.
- Loại da phù hợp, vấn đề da, mục tiêu chăm sóc.
- Kết cấu, cảnh báo, nguồn dữ liệu, ngày xác minh.

### Làm sạch và chuẩn hóa

1. Chuẩn hóa tên thương hiệu và danh mục.
2. Chuẩn hóa đơn vị giá và dung tích.
3. Tách danh sách thành phần bằng dấu phân tách thống nhất.
4. Map loại da, vấn đề da và mục tiêu chăm sóc về enum nội bộ.
5. Loại bỏ sản phẩm trùng SKU hoặc trùng URL nguồn.
6. Kiểm tra thiếu dữ liệu ở các trường quan trọng.
7. Lưu dữ liệu thô vào `datasets/raw` và dữ liệu sạch vào `datasets/processed`.

## 6. Kết quả cần hoàn thành ở cuối Giai đoạn 1

- Repo đã tách source rõ ràng cho website và hệ thống.
- Có API contract giữa website và hệ thống.
- Có event contract cho behavior tracking.
- Có schema database ban đầu.
- Có schema product dataset.
- Có tài liệu phân công và lộ trình triển khai.
