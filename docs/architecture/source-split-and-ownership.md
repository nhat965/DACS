# Chia tách source và phân công phát triển

## Mục tiêu

Dự án được chia theo ranh giới trách nhiệm để hai thành viên có thể làm song song:

- Website phụ trách giao diện, luồng mua hàng và trải nghiệm người dùng.
- Hệ thống bên trong phụ trách dữ liệu, recommendation, chatbot, analytics, stream analytics và dashboard metrics.

Hai phần liên kết bằng API contract, event contract và database schema đã thống nhất.

## Phân vùng source

| Khu vực | Người phụ trách chính | Nội dung |
|---|---|---|
| `apps/web` | Thành viên làm website | Frontend, trang khách hàng, trang admin, gọi API, gửi behavior event |
| `services/recommendation-service` | Thành viên làm hệ thống | KB, CB, CF, Hybrid Scoring, giải thích lý do gợi ý |
| `services/chatbot-service` | Thành viên làm hệ thống | Chatbot tư vấn dựa trên dữ liệu sản phẩm |
| `services/analytics-service` | Thành viên làm hệ thống | Tổng hợp số liệu cho dashboard |
| `services/stream-analytics-service` | Thành viên làm hệ thống | Nền tảng xử lý event gần thời gian thực |
| `database` | Thành viên làm hệ thống | Schema, migration, seed data, data dictionary |
| `datasets` | Thành viên làm hệ thống | Product dataset thô và đã làm sạch |
| `contracts` | Cả nhóm thống nhất | API và event contract giữa website và hệ thống |

## Luồng tích hợp tổng thể

```text
User
  |
  v
apps/web
  |
  | REST API
  v
Backend/API Gateway
  |
  +--> Product, Cart, Order, User modules
  |
  +--> recommendation-service
  |
  +--> chatbot-service
  |
  +--> analytics-service
  |
  +--> database

apps/web
  |
  | behavior event
  v
user_behavior_events
  |
  +--> recommendation-service
  +--> analytics-service
  +--> stream-analytics-service
```

## Nguyên tắc làm việc nhóm

1. Website không tự tính logic AI phức tạp. Website gọi API trong `contracts/openapi/system-api.yaml`.
2. Hệ thống recommendation/chatbot không phụ thuộc vào giao diện cụ thể của website.
3. Mọi event người dùng cần tuân thủ `contracts/events/behavior-events.md`.
4. Mọi thay đổi lớn về schema database cần cập nhật migration và data dictionary.
5. Product dataset cần có nguồn dữ liệu và ngày xác minh.
6. Chưa push lên GitHub cho đến khi nhóm kiểm tra ổn định.

## Điểm nối giữa website và hệ thống

| Nhu cầu của website | API/Event |
|---|---|
| Hiển thị gợi ý cá nhân hóa | `POST /recommendations/personalized` |
| Hiển thị sản phẩm tương tự | `GET /recommendations/similar-products/{productId}` |
| Chatbot tư vấn | `POST /chatbot/messages` |
| Dashboard admin | `GET /analytics/dashboard-summary` |
| Ghi nhận hành vi người dùng | `POST /behavior-events` |

## Lộ trình triển khai theo nhánh việc

### Nhánh website

1. Dựng layout và routing.
2. Dựng trang danh mục, chi tiết sản phẩm, tìm kiếm, bộ lọc.
3. Dựng giỏ hàng, đặt hàng, tài khoản.
4. Dựng admin dashboard UI.
5. Tích hợp API gợi ý, chatbot và behavior tracking.

### Nhánh hệ thống

1. Hoàn thiện schema database và seed data.
2. Chuẩn hóa product dataset.
3. Xây API behavior tracking.
4. Xây user profile từ hành vi và quiz.
5. Xây recommendation-service.
6. Xây chatbot-service.
7. Xây analytics-service cho dashboard.
8. Bổ sung stream analytics nếu còn thời gian.
