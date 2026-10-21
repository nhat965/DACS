# Triển khai Lumi Beauty: Vercel Web/API + Railway MySQL

Mô hình này tách đúng vai trò của từng nền tảng:

```text
https://<lumi-web>.vercel.app
  └─ Flutter Web (static CDN)
          │ gọi HTTPS qua API_BASE_URL
          ▼
https://<lumi-api>.vercel.app
  └─ FastAPI Vercel Function + Lumi AI
          │ TLS public MySQL connection
          ▼
Railway MySQL
  └─ catalog, tài khoản, đơn hàng, review, tồn kho, hành vi
```

Không commit `.env.local`, MySQL dump, Gemini API key hay JWT secret. Một link
Vercel là đủ cho người dùng cuối; API và database không phụ thuộc máy local.

## 1. Tạo Railway MySQL

1. Vào Railway, tạo **New Project**.
2. Chọn **Add Service → Database → MySQL** và giữ database ở private network.
3. Vì FastAPI chạy trên Vercel (một network khác Railway), trong MySQL chọn
   **Connect → Public Network → Add Public Access**. Railway sẽ tạo biến
   `MYSQL_PUBLIC_URL`. Không đưa chuỗi này vào GitHub hay Flutter.

Kết nối public là yêu cầu của kiến trúc này. Chỉ server-side Vercel Function
nhận chuỗi kết nối; browser không có quyền hay thông tin để truy cập MySQL.

## 2. Chuyển database local lên Railway

Để giữ sản phẩm, tài khoản, đơn hàng và review hiện có, export database local
rồi import vào MySQL Railway. File dump có thể chứa password hashes và dữ liệu
người dùng, nên chỉ lưu private, không đẩy lên GitHub.

1. Sao chép `MYSQL_PUBLIC_URL` từ tab **Variables** của MySQL Railway.
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
6. Giữ Public Access vì Vercel Function sử dụng nó khi website hoạt động. Không
   chia sẻ URL này và chỉ lưu nó trong Vercel Environment Variables.

Nếu không cần giữ data cũ, chạy các migration `database/migrations/001` đến
`008` theo thứ tự rồi import catalog đã được duyệt. Không dùng database fallback
CSV cho demo có đăng nhập/order/review vì CSV không lưu các nghiệp vụ đó.

## 3. Tạo Vercel API project

1. Trong Vercel, tạo project mới từ `nhat965/DACS`, đặt tên gợi ý `lumi-api`.
2. Giữ **Root Directory** là repository root. Vercel sẽ nhận `api/index.py` là
   FastAPI Function và dùng `requirements.txt` tại root.
3. Đặt Production Environment Variables:

```dotenv
RECOMMENDATION_DB_ENABLED=true
MYSQL_URL=<giá trị MYSQL_PUBLIC_URL từ Railway>

JWT_SECRET=<chuỗi-ngẫu-nhiên-dài-không-dùng-lại>
JWT_TTL_SECONDS=28800
ADMIN_EMAIL=<email-admin>
ADMIN_PASSWORD=<mật-khẩu-admin-mạnh>
ADMIN_NAME=Admin

GEMINI_API_KEY=<Gemini-key>
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_TIMEOUT_SECONDS=15
```

4. Deploy và mở `https://<lumi-api>.vercel.app/health`. Endpoint phải trả `ok`.

## 4. Tạo/cập nhật Vercel project cho Flutter Web

1. Trên Vercel, **Add New → Project → Import** repository `nhat965/DACS`.
2. Trong **Build and Deployment**, đặt **Root Directory** là `apps/web`.
3. Chọn Framework Preset **Other**. File `apps/web/vercel.json` đã chỉ định build
   script và output `build/web`; không dùng Vercel Services.
4. Trong **Environment Variables**, thêm cho Production (và Preview nếu muốn):

```dotenv
API_BASE_URL=https://<lumi-api>.vercel.app
```

Đây là URL công khai của API, không phải secret. Không đặt Gemini key, MySQL URL
hay JWT secret trên Vercel.

5. Deploy từ `main`. Vercel clone Flutter SDK lúc build và phục vụ `build/web`.

Sau khi có URL frontend, thêm vào Environment Variables của Vercel API project:

```dotenv
CORS_ALLOW_ORIGINS=https://<lumi-web>.vercel.app
```

Rồi redeploy API project. `API_BASE_URL` là giá trị build-time; mỗi lần đổi API
URL, cần redeploy Flutter Web project.

## 4. Kiểm tra production

- Mở URL Vercel trên máy hoặc điện thoại khác.
- Đăng ký, refresh trang, đăng nhập lại và chỉnh sửa hồ sơ.
- Tìm sản phẩm, thêm vào giỏ, tạo đơn, rồi kiểm tra trạng thái đơn.
- Đăng nhập admin và đổi trạng thái đơn; tài khoản khách phải nhận đúng trạng thái.
- Gửi câu hỏi Lumi AI. Khi Gemini không khả dụng, UI phải báo lỗi rõ ràng nhưng
  catalog và shopping vẫn hoạt động.
- Mở `https://<lumi-api>.vercel.app/health` và `/ready` để kiểm tra API/DB.

## Lưu ý vận hành

- Railway MySQL cần public TCP access cho Vercel Function. Bảo vệ connection URL
  như password: chỉ lưu tại Vercel Environment Variables, không log/chia sẻ nó.
- Vercel build nhúng `API_BASE_URL` vào Flutter JavaScript. Mỗi lần đổi API URL,
  cần Redeploy Vercel để build lại.
- Khi đổi Vercel domain, cập nhật `CORS_ALLOW_ORIGINS` ở Railway rồi redeploy API.
- Free tier có thể sleep hoặc giới hạn quota tùy thời điểm/gói dịch vụ. Theo dõi
  logs và usage của cả hai nền tảng trước buổi demo.
