# Lumi Beauty frontend

Flutter frontend cho website thương mại điện tử mỹ phẩm và hệ thống gợi ý sản phẩm.

## Phạm vi đã kết nối

- Tải catalog thật từ `GET /products` và `GET /products/{productId}`.
- Đăng ký, đăng nhập JWT và phân quyền CUSTOMER/ADMIN qua backend.
- Giỏ hàng dùng state thật, kiểm tra tồn kho và không trộn currency.
- Checkout tạo đơn MySQL qua `POST /orders`; trang hồ sơ tải lịch sử đơn thật.
- Trang quản trị tải catalog và toàn bộ đơn thật, yêu cầu role ADMIN.
- Tải sản phẩm tương tự từ `GET /recommendations/similar-products/{productId}`.
- Có client cho `POST /recommendations/personalized`.
- Gửi `view_product`, `add_to_cart`, `remove_from_cart` và `place_order` đến luồng behavior.
- Hiển thị trạng thái loading, lỗi kết nối và thao tác thử lại.

Chatbot và analytics vẫn là giao diện định hướng vì các endpoint tương ứng đang được đánh dấu `PLANNED` trong OpenAPI.

## Chạy local

Khởi động recommendation service từ thư mục gốc repository:

```powershell
python -m uvicorn recommendation_service.api:app --app-dir services/recommendation-service --reload --port 8001
```

Chạy Flutter web:

```powershell
Set-Location apps/web
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001
```

`API_BASE_URL` mặc định là `http://localhost:8001`. Với Android emulator, dùng `http://10.0.2.2:8001`.

Đăng nhập và checkout yêu cầu backend bật kết nối MySQL và đã chạy đủ migration `001` đến `004`. Khi database bị tắt, API recommendation và catalog có thể hoạt động ở degraded mode; auth/checkout sẽ trả `503`. Lỗi behavior tracking không làm hỏng thao tác giỏ hàng hoặc đơn đã tạo.

## Cấu trúc tích hợp

- `lib/config`: cấu hình build-time.
- `lib/services`: HTTP client và mapping lỗi backend.
- `lib/providers`: trạng thái catalog và recommendation.
- `lib/models`: model khớp OpenAPI.
- `lib/screens`: giao diện khách hàng và quản trị.

Tài liệu phạm vi frontend ban đầu được giữ tại `FRONTEND_SCOPE.md`.
