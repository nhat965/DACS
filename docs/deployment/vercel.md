# Triển khai Lumi Beauty: Vercel Web/API + Aiven for MySQL

Kiến trúc production tách frontend, API và database để website vẫn hoạt động
khi máy local tắt:

```text
https://<lumi-web>.vercel.app
  └─ Flutter Web (static CDN)
          │ HTTPS qua API_BASE_URL
          ▼
https://<lumi-api>.vercel.app
  └─ FastAPI Vercel Function + Lumi AI
          │ MySQL qua TLS
          ▼
Aiven for MySQL
  └─ catalog, tài khoản, đơn hàng, review, tồn kho, hành vi
```

Không commit `.env.local`, MySQL dump, Gemini API key, JWT secret hay chuỗi
kết nối Aiven. Browser chỉ gọi FastAPI; không bao giờ kết nối thẳng MySQL.

## 1. Tạo Aiven for MySQL

1. Vào Aiven Console → **Create service** → chọn **MySQL**.
2. Chọn cloud/region gần nhất và gói phù hợp, đặt tên ví dụ `lumi-mysql`, rồi
   tạo service. Nếu gói hiện tại không cho chọn region, dùng region Aiven gán.
3. Khi service có trạng thái `Running`, vào **Connect → Databases** và tạo
   database `cosmetic_ecommerce` (hoặc dùng `defaultdb`).
4. Tại **Overview → Connection information**, ghi lại host, port, user,
   password và database. Tải **CA certificate** từ Connect. Aiven yêu cầu kết
   nối TLS; giữ certificate này private cùng connection information.

## 2. Chuyển database local lên Aiven

Để giữ sản phẩm, tài khoản, đơn hàng và review hiện có, export database local
rồi import vào Aiven. File dump có thể chứa password hash và dữ liệu người
dùng, nên chỉ lưu private, không đẩy GitHub.

1. Export database local (điều chỉnh host/user/database theo `.env.local`):

```powershell
mysqldump -h 127.0.0.1 -u root -p --single-transaction --routines --triggers --no-create-db cosmetic_ecommerce > lumi_backup.sql
```

2. Import bằng thông tin Connection information của Aiven. Lệnh sau cần CA
   certificate đã tải ở bước 1:

```powershell
mysql -h <aiven-host> -P <aiven-port> -u <aiven-user> -p `
  --ssl-mode=VERIFY_CA --ssl-ca <duong-dan-ca.pem> cosmetic_ecommerce < .\lumi_backup.sql
```

3. Kiểm tra `products`, `users`, `orders` đã có bản ghi trên Aiven trước khi
   cấu hình API. Nếu không giữ data cũ, chạy migrations `001` đến `008` rồi
   import catalog đã duyệt bằng data pipeline.

## 3. Tạo Vercel API project

1. Trong Vercel, tạo project mới từ `nhat965/DACS`, đặt tên gợi ý `lumi-api`.
2. Giữ **Root Directory** ở repository root. Vercel nhận `api/index.py` là
   FastAPI Function và dùng `requirements.txt` tại root.
3. Tại Production Environment Variables, thêm:

```dotenv
RECOMMENDATION_DB_ENABLED=true
MYSQL_URL=mysql://<aiven-user>:<url-encoded-password>@<aiven-host>:<port>/cosmetic_ecommerce
MYSQL_SSL_MODE=VERIFY_CA
MYSQL_SSL_CA_PEM=<toan-bo-noi-dung-ca-certificate-aiven>

JWT_SECRET=<chuoi-ngau-nhien-dai-khong-dung-lai>
JWT_TTL_SECONDS=28800
ADMIN_EMAIL=<email-admin>
ADMIN_PASSWORD=<mat-khau-admin-manh>
ADMIN_NAME=Admin

GEMINI_API_KEY=<Gemini-key>
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_TIMEOUT_SECONDS=15
```

`MYSQL_SSL_CA_PEM` có thể dán nhiều dòng hoặc dùng `\n` giữa các dòng. Đây là
CA certificate, còn `MYSQL_URL` chứa password; cả hai chỉ nằm ở Vercel API,
không đặt vào Flutter hay GitHub.

4. Deploy và mở `https://<lumi-api>.vercel.app/health`. Endpoint phải trả
`ok`; `/ready` phải báo database sẵn sàng.

## 4. Tạo/cập nhật Vercel project cho Flutter Web

1. Trên Vercel, **Add New → Project → Import** repository `nhat965/DACS`.
2. Trong **Build and Deployment**, đặt **Root Directory** là `apps/web`.
3. Chọn Framework Preset **Other**. File `apps/web/vercel.json` đã chỉ định
build script và output `build/web`.
4. Thêm Production Environment Variable:

```dotenv
API_BASE_URL=https://<lumi-api>.vercel.app
```

Đây là URL công khai của API, không phải secret. Không đặt Gemini key, MySQL
URL, CA certificate hay JWT secret ở frontend.

5. Deploy từ `main`. Sau khi có URL frontend, cập nhật Vercel API variables:

```dotenv
CORS_ALLOW_ORIGINS=https://<lumi-web>.vercel.app
```

Rồi redeploy API. `API_BASE_URL` là build-time, nên đổi API URL thì redeploy
Flutter Web.

## 5. Kiểm tra production

- Mở URL Vercel bằng máy hoặc điện thoại khác.
- Đăng ký, refresh, đăng nhập, cập nhật hồ sơ.
- Tìm sản phẩm, thêm giỏ, tạo đơn, theo dõi đơn; admin đổi trạng thái đơn.
- Gửi câu hỏi Lumi AI. Khi Gemini lỗi, shopping/catalog vẫn phải hoạt động.
- Mở `https://<lumi-api>.vercel.app/health` và `/ready` để kiểm tra API/DB.

## Lưu ý vận hành

- Aiven MySQL dùng TLS. Không bỏ CA/`MYSQL_SSL_MODE` khi FastAPI chạy trên
  Vercel; kết nối internet công khai cần certificate verification.
- Vercel build nhúng `API_BASE_URL` vào Flutter JavaScript. Mỗi lần đổi URL API
  cần Redeploy frontend.
- Tùy gói Aiven, quota/trial có thể giới hạn service. Kiểm tra billing/usage
  trước buổi demo.
