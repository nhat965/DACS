# Triển khai Lumi Beauty trên Vercel

Tài liệu này triển khai một URL công khai duy nhất nhưng giữ frontend, API và
database ở đúng ranh giới:

```text
https://<project>.vercel.app
  ├─ Flutter Web (Vercel Service: lumi_web)
  ├─ /api/* → FastAPI (Vercel Service: lumi_api)
  └─ Managed MySQL (không public trực tiếp)
```

Không commit `.env.local`, file dump SQL hay Gemini key.

## 1. Chuẩn bị Managed MySQL

Tạo một MySQL instance có thể truy cập từ Vercel, sau đó tạo database riêng cho
Lumi Beauty. Chạy các migration theo đúng thứ tự từ
`database/migrations/001_initial_schema.sql` đến
`database/migrations/008_vietnamese_catalog_currency.sql`.

Để giữ nguyên tài khoản, đơn hàng, đánh giá, tồn kho và catalog đang có trên máy
local, export database local bằng công cụ MySQL rồi import file dump đó vào MySQL
cloud. File dump có thể chứa dữ liệu người dùng, nên chỉ lưu ở nơi riêng tư; không
đưa nó vào repository hay upload công khai.

Sau khi import, kiểm tra các sản phẩm cần hiển thị có `status = 'ACTIVE'`,
`stock_quantity > 0` và `ai_ready = TRUE`.

## 2. Tạo Vercel project

1. Import repository GitHub `nhat965/DACS` vào Vercel.
2. Trong **Project Settings → Build and Deployment**, chọn framework
   **Services**. Đây là điều kiện để Vercel đọc khối `services` trong
   `vercel.json`.
3. Deploy từ nhánh `main`. Vercel tự build Flutter Web và FastAPI thành hai
   service nội bộ, sau đó route `/api/*` đến FastAPI.

## 3. Biến môi trường Production

Thêm trong **Project Settings → Environment Variables** cho môi trường
Production (và Preview nếu cần):

```dotenv
RECOMMENDATION_DB_ENABLED=true
MYSQL_HOST=<cloud-mysql-host>
MYSQL_PORT=3306
MYSQL_USER=<cloud-mysql-user>
MYSQL_PASSWORD=<cloud-mysql-password>
MYSQL_DATABASE=<cloud-mysql-database>

JWT_SECRET=<long-random-secret>
JWT_TTL_SECONDS=28800

ADMIN_EMAIL=<admin-email>
ADMIN_PASSWORD=<strong-admin-password>
ADMIN_NAME=Admin

GEMINI_API_KEY=<gemini-api-key>
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_TIMEOUT_SECONDS=15

# Nếu frontend và API dùng cùng domain Vercel, có thể để trống.
CORS_ALLOW_ORIGINS=
```

Không đặt `API_BASE_URL` trên Vercel: build script đã cố định nó là `/api`, giúp
browser chỉ sử dụng một domain công khai.

## 4. Kiểm tra sau deploy

- Mở `https://<project>.vercel.app`.
- Kiểm tra `https://<project>.vercel.app/api/health` trả `ok`.
- Đăng ký tài khoản thử, đăng nhập lại sau khi refresh trang và kiểm tra profile.
- Tạo một đơn, duyệt trạng thái bằng admin rồi kiểm tra lại ở giao diện khách.
- Đặt một đánh giá và kiểm tra nó còn tồn tại sau khi refresh.
- Gửi một câu hỏi Lumi AI. Nếu không có Gemini key, UI phải báo rõ AI chưa được
  cấu hình; catalog, search và shopping không được hỏng.

## Lưu ý vận hành

- Vercel Service/Python runtime là serverless: không lưu file upload, SQLite hay
  session chỉ trong filesystem của function.
- MySQL cloud là nguồn dữ liệu bền vững duy nhất cho user, order, review,
  inventory và behavior events.
- Giới hạn thời gian function cho service FastAPI đặt 30 giây; chatbot đã có
  timeout Gemini 15 giây và fallback catalog khi Gemini tạm thời quá tải.
