# Triển khai Lumi Beauty: Vercel Web + Railway API và MySQL

Mô hình này tách đúng vai trò của từng nền tảng:

```text
https://<lumi-web>.vercel.app
  └─ Flutter Web (static CDN)
          │ gọi HTTPS qua API_BASE_URL
          ▼
https://<lumi-api>.up.railway.app
  └─ FastAPI + Lumi AI
          │ private Railway network
          ▼
Railway MySQL
  └─ catalog, tài khoản, đơn hàng, review, tồn kho, hành vi
```

Không commit `.env.local`, MySQL dump, Gemini API key hay JWT secret. Một link
Vercel là đủ cho người dùng cuối; API và database không phụ thuộc máy local.

## 1. Tạo Railway project

1. Vào Railway, tạo **New Project**.
2. Chọn **Add Service → Database → MySQL** và giữ database ở private network.
3. Chọn **Add Service → GitHub Repo**, chọn `nhat965/DACS`, nhánh `main`.
4. Với service FastAPI, để **Root Directory** trống (repository root) để service
   đọc được catalog trong `datasets/`. File `railway.toml` tại root đã định nghĩa
   build command, start command và `/health` health check.
5. Trong service FastAPI, vào **Settings → Networking → Generate Domain**. Lưu
   domain, ví dụ `https://lumi-api-production.up.railway.app`.

### Biến môi trường FastAPI trên Railway

Vào **Variables** của service FastAPI và đặt:

```dotenv
RECOMMENDATION_DB_ENABLED=true
# Thay MySQL bằng đúng tên service MySQL trong Railway.
MYSQL_URL=${{MySQL.MYSQL_URL}}

JWT_SECRET=<chuỗi-ngẫu-nhiên-dài-không-dùng-lại>
JWT_TTL_SECONDS=28800

ADMIN_EMAIL=<email-admin>
ADMIN_PASSWORD=<mat-khẩu-admin-mạnh>
ADMIN_NAME=Admin

GEMINI_API_KEY=<Gemini-key>
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_TIMEOUT_SECONDS=15

# Điền sau khi Vercel cấp domain ở bước 3.
CORS_ALLOW_ORIGINS=https://<lumi-web>.vercel.app
```

`MYSQL_URL` là private connection string chỉ dùng nội bộ giữa FastAPI và MySQL
trong cùng Railway project. Không bật Public Access cho MySQL trừ lúc cần import
dữ liệu từ máy local; API không cần database public.

Sau deploy, mở `https://<lumi-api>.up.railway.app/health`. Endpoint phải trả
trạng thái `ok` trước khi tiếp tục.

## 2. Chuyển database local lên Railway

Để giữ sản phẩm, tài khoản, đơn hàng và review hiện có, export database local
rồi import vào MySQL Railway. File dump có thể chứa password hashes và dữ liệu
người dùng, nên chỉ lưu private, không đẩy lên GitHub.

1. Tại MySQL Railway, vào **Settings → Networking** và tạm bật **Public Access**.
2. Sao chép `MYSQL_PUBLIC_URL` từ tab **Variables**.
3. Export từ máy local (điều chỉnh host/user/database theo `.env.local`):

```powershell
mysqldump -h 127.0.0.1 -u root -p --single-transaction --routines --triggers --no-create-db cosmetic_ecommerce > lumi_backup.sql
```

4. Import file vào Railway bằng public host/port/user/password/database hiển thị
   trong `MYSQL_PUBLIC_URL`. Có thể dùng MySQL Workbench hoặc `mysql` CLI:

```powershell
mysql -h <public-host> -P <public-port> -u <user> -p <database> < .\lumi_backup.sql
```

5. Kiểm tra lại API `/ready`, đăng nhập thử và xem `GET /products`.
6. Tắt MySQL **Public Access** ngay sau import.

Nếu không cần giữ data cũ, chạy các migration `database/migrations/001` đến
`008` theo thứ tự rồi import catalog đã được duyệt. Không dùng database fallback
CSV cho demo có đăng nhập/order/review vì CSV không lưu các nghiệp vụ đó.

## 3. Tạo Vercel project cho Flutter Web

1. Trên Vercel, **Add New → Project → Import** repository `nhat965/DACS`.
2. Trong **Build and Deployment**, đặt **Root Directory** là `apps/web`.
3. Chọn Framework Preset **Other**. File `apps/web/vercel.json` đã chỉ định build
   script và output `build/web`; không dùng Vercel Services.
4. Trong **Environment Variables**, thêm cho Production (và Preview nếu muốn):

```dotenv
API_BASE_URL=https://<lumi-api>.up.railway.app
```

Đây là URL công khai của API, không phải secret. Không đặt Gemini key, MySQL URL
hay JWT secret trên Vercel.

5. Deploy từ `main`. Vercel clone Flutter SDK lúc build và phục vụ `build/web`.
6. Sau khi có URL Vercel, quay lại Railway sửa `CORS_ALLOW_ORIGINS` thành chính
   URL này rồi Redeploy FastAPI.

## 4. Kiểm tra production

- Mở URL Vercel trên máy hoặc điện thoại khác.
- Đăng ký, refresh trang, đăng nhập lại và chỉnh sửa hồ sơ.
- Tìm sản phẩm, thêm vào giỏ, tạo đơn, rồi kiểm tra trạng thái đơn.
- Đăng nhập admin và đổi trạng thái đơn; tài khoản khách phải nhận đúng trạng thái.
- Gửi câu hỏi Lumi AI. Khi Gemini không khả dụng, UI phải báo lỗi rõ ràng nhưng
  catalog và shopping vẫn hoạt động.
- Mở `https://<lumi-api>.up.railway.app/health` và `/ready` để kiểm tra API/DB.

## Lưu ý vận hành

- Railway MySQL private mặc định; điều này tránh public database không cần thiết.
- Vercel build nhúng `API_BASE_URL` vào Flutter JavaScript. Mỗi lần đổi API URL,
  cần Redeploy Vercel để build lại.
- Khi đổi Vercel domain, cập nhật `CORS_ALLOW_ORIGINS` ở Railway rồi redeploy API.
- Free tier có thể sleep hoặc giới hạn quota tùy thời điểm/gói dịch vụ. Theo dõi
  logs và usage của cả hai nền tảng trước buổi demo.
