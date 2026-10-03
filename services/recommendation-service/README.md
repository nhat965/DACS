# recommendation-service

Service phụ trách hệ thống gợi ý sản phẩm mỹ phẩm.

## Trạng thái triển khai

Service hỗ trợ hai chế độ:

1. Standalone: đọc catalog AI-ready CSV tại
   `datasets/product-catalog/all_brands_ai_ready_products.csv`.
2. Integrated: đọc catalog từ MySQL, dùng `products.id`, `user_profiles`,
   `user_behavior_events` và ghi `recommendation_logs`.

## Phạm vi

- Knowledge-Based Recommendation dựa trên loại da, vấn đề da, mục tiêu chăm sóc, ngân sách, thành phần quan tâm và thành phần cần tránh.
- Content-Based Recommendation dựa trên thuộc tính sản phẩm và lịch sử tương tác của người dùng.
- Hybrid Scoring hiện tại kết hợp Knowledge-Based và Content-Based.
- Collaborative Filtering chưa bật trong score vì service chưa có ma trận tương tác thật đủ tin cậy. Trọng số CF hiện bằng 0 theo chủ đích.

Pipeline runtime: candidate generation → hard-constraint/safety filter → KB score → CB score → hybrid ranking → explanation.

`avoidIngredients` là hard exclusion và dùng canonical ingredient aliases; preferred brand/category là soft preference. Budget phải đi cùng `budgetCurrency`.

Endpoints implemented: `/health`, `/ready`, `/products`, `/products/{productId}`, `/behavior-events`, `/recommendations/personalized`, `/recommendations/similar-products/{productId}`, `/recommendations/explain`.

Offline evaluation:

```powershell
python -m recommendation_service.evaluation_cli
```

Evaluation fixture là expert/developer-defined, không phải production user ground truth.
- Trả về danh sách sản phẩm được gợi ý kèm lý do gợi ý.

## Cấu trúc

```text
recommendation_service/
  api.py       # FastAPI endpoints
  catalog.py   # Load CSV catalog, map sang Product model
  engine.py    # KB + content-based + hybrid scoring
  models.py    # Dataclass request/response nội bộ
tests/
  test_engine.py
```

## API liên quan

- `POST /behavior-events`
- `POST /recommendations/personalized`
- `GET /recommendations/similar-products/{productId}`
- `POST /recommendations/explain`

Chi tiết contract nằm ở `contracts/openapi/system-api.yaml`.

## Chạy local

Từ thư mục `DACS-main`:

```powershell
python -m pip install -r services/recommendation-service/requirements.txt
python -m uvicorn recommendation_service.api:app --app-dir services/recommendation-service --reload --port 8001
```

Nếu chạy trực tiếp trong thư mục service:

```powershell
cd services/recommendation-service
python -m pip install -r requirements.txt
python -m uvicorn recommendation_service.api:app --reload --port 8001
```

Trên Windows, nên chạy từ thư mục gốc bằng script để tự nạp `.env.local` (bao gồm cấu hình MySQL và tài khoản bootstrap admin):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_backend.ps1
```

## Chạy test

Chạy recommendation test từ đúng thư mục service để Python import được package
`recommendation_service`:

```powershell
cd services/recommendation-service
python -m unittest discover -s tests -v
```

Nếu muốn chạy từ project root, cần thiết lập `PYTHONPATH`.

Linux/macOS:

```bash
PYTHONPATH=services/recommendation-service \
python -m unittest discover \
  -s services/recommendation-service/tests \
  -v
```

PowerShell:

```powershell
$env:PYTHONPATH="services/recommendation-service"

python -m unittest discover `
  -s services/recommendation-service/tests `
  -v
```

MySQL integration test là optional và cần database test riêng. Không chạy test
này trên production DB. Test tự tạo dữ liệu riêng và cleanup dữ liệu của chính nó.

Ví dụ PowerShell:

```powershell
$env:RUN_RECOMMENDATION_MYSQL_INTEGRATION="true"
$env:RECOMMENDATION_DB_ENABLED="true"

$env:MYSQL_HOST="127.0.0.1"
$env:MYSQL_PORT="3306"
$env:MYSQL_USER="YOUR_TEST_DB_USER"
$env:MYSQL_PASSWORD="YOUR_TEST_DB_PASSWORD"
$env:MYSQL_DATABASE="cosmetic_ecommerce_test"

cd services/recommendation-service
python -m unittest discover -s tests -v
```

## Bật tích hợp MySQL

Mặc định service vẫn chạy bằng catalog CSV và dữ liệu behavior truyền trực tiếp
trong request. Để lưu/đọc hành vi từ MySQL, cấu hình:

```powershell
$env:RECOMMENDATION_DB_ENABLED="true"
$env:MYSQL_HOST="127.0.0.1"
$env:MYSQL_PORT="3306"
$env:MYSQL_USER="root"
$env:MYSQL_PASSWORD="your_password"
$env:MYSQL_DATABASE="cosmetic_ecommerce"
```

Khi bật DB:

- Nếu MySQL không khả dụng lúc khởi động, service dùng AI-ready CSV ở chế độ
  degraded cho gợi ý; `/ready` trả `ready_degraded`, còn ghi behavior bị từ chối.
- Catalog MySQL chỉ đọc sản phẩm `ACTIVE`, còn hàng và `ai_ready = TRUE`.
  trong DB mode để tránh lệch `productId`.
- Catalog chỉ lấy sản phẩm `ACTIVE` và còn hàng (`stock_quantity > 0`).
- `POST /behavior-events` lưu hành vi vào `user_behavior_events`.
- `POST /recommendations/personalized` tự đọc `user_profiles` và
  `user_behavior_events` khi có `userId` hoặc `sessionId`.
- Kết quả recommendation được log vào `recommendation_logs`.
- Catalog recommendation được load từ bảng `products`, nên `productId` trong
  API là `products.id`.

Quy ước ID:

- Khi bật MySQL: `productId = products.id`, đây là khóa chính dùng bởi website,
  order, behavior và recommendation.
- `sku` chỉ là mã nghiệp vụ/nguồn crawl, dùng khi import hoặc map fallback.
- Khi không bật MySQL, service chạy độc lập bằng CSV và có thể dùng SKU số làm
  `productId` tạm thời cho demo service riêng lẻ.

Có thể đổi catalog bằng biến môi trường:

```powershell
$env:RECOMMENDATION_CATALOG_PATH="C:\path\to\all_brands_ai_ready_products.csv"
```

## Ví dụ request

```json
{
  "limit": 5,
  "context": {
    "skinType": "sensitive",
    "skinConcerns": ["acne"],
    "careGoals": ["anti_acne", "soothe"],
    "budgetMax": 30,
    "preferredCategories": ["serum", "cleanser"],
    "preferredBrands": ["COSRX"],
    "avoidIngredients": ["alcohol"]
  },
  "behaviors": [
    {"eventType": "view_product", "productId": 1},
    {"eventType": "add_to_cart", "productId": 3}
  ]
}
```

## Ví dụ lưu behavior

```json
{
  "userId": 1,
  "sessionId": "demo-session-1",
  "eventType": "view_product",
  "productId": 1,
  "occurredAt": "2026-09-21T10:00:00Z"
}
```
