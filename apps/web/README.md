# apps/web

Khu vực phát triển website thương mại điện tử mỹ phẩm.

## Người phụ trách chính

Bạn trong nhóm phụ trách chủ đạo phần website.

## Phạm vi

- Giao diện khách hàng: trang chủ, danh mục, chi tiết sản phẩm, tìm kiếm, bộ lọc, giỏ hàng, đặt hàng, tài khoản.
- Giao diện quản trị: quản lý sản phẩm, danh mục, thương hiệu, đơn hàng, người dùng, đánh giá.
- Gọi API từ backend/system services để lấy gợi ý sản phẩm, phản hồi chatbot và dữ liệu dashboard.
- Gửi behavior event khi người dùng xem sản phẩm, tìm kiếm, lọc, thêm giỏ hàng, mua hàng, đánh giá hoặc click sản phẩm gợi ý.

## Ranh giới tích hợp

Website không tự tính recommendation, chatbot reasoning hoặc analytics nâng cao. Website chỉ gọi API được định nghĩa trong `contracts/openapi/system-api.yaml` và gửi event theo `contracts/events/behavior-events.md`.
