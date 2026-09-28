# Hệ thống gợi ý mỹ phẩm

Đồ án cơ sở tập trung vào độ tin cậy dữ liệu, khả năng truy vết nguồn, gợi ý an toàn và giải thích được. Flutter frontend nằm tại `apps/web` và đang được tích hợp theo API contract.

## Current Scope

- Data crawling và lưu raw data bất biến.
- Cleaning, normalization, deduplication, validation và quality gate.
- Production-candidate catalog và AI-ready catalog là hai lớp riêng.
- MySQL schema/importer, behavior events và recommendation logs.
- Backend FastAPI cho health, readiness, behavior tracking và recommendation.
- JWT auth với mật khẩu PBKDF2-SHA256 và phân quyền CUSTOMER/ADMIN.
- Cart/checkout dùng giá phía server, kiểm tra tồn kho và lưu đơn hàng vào MySQL.
- Knowledge-Based Recommendation.
- Content-Based Recommendation bằng deterministic feature/Jaccard baseline.
- Hybrid ranking: Knowledge-Based + Content-Based.
- Cold start, similar products và recommendation explanation.
- Hard constraints tách khỏi ranking: ngân sách, currency, product exclusion và ingredient exclusion.
- Offline evaluation: Precision@K, Recall@K, HitRate@K, Coverage và Diversity.

## Intentional Architecture Decision

Collaborative Filtering hiện không có trọng số trong production scoring vì chưa có đủ interaction data thật để tạo user-item matrix đáng tin cậy. Hệ thống hiện dùng:

```text
FinalScore = alpha * KnowledgeBasedScore + beta * ContentBasedScore
CollaborativeFilteringWeight = 0
```

Đây là quyết định có chủ đích, không phải bug hay feature bị bỏ dở. Không dùng behavior giả, interaction random hoặc CF weight tùy ý.

## Future Extensions

- Collaborative Filtering khi có đủ view/click/favorite/cart/purchase/rating/feedback thật.
- Chatbot dựa trên dữ liệu đã kiểm duyệt.
- Stream analytics/Kafka khi traffic và nhu cầu nghiệp vụ đủ lớn.
- Real-time evaluation, online learning và production A/B testing.

Các thư mục placeholder cho chatbot/analytics/stream chỉ là future-ready boundary; endpoint tương ứng trong OpenAPI được gắn `PLANNED`.

## Data Pipeline

```text
crawl
  → raw data
  → source-preserving enrichment/clean
  → normalization
  → deduplication
  → validation
  → production candidate
  → AI-ready dataset
  → database
```

`Crawled successfully` không đồng nghĩa với `AI-ready`. Record thiếu dữ liệu được giữ cùng reason code; pipeline không tự bịa warning, contraindication, safety claim hoặc medical suitability.

Reason code chính:

- `MISSING_NAME`, `MISSING_BRAND`, `MISSING_CATEGORY`, `MISSING_SKU`
- `INVALID_PRICE`, `INVALID_CURRENCY`, `INVALID_SOURCE`
- `INSUFFICIENT_AI_FEATURES`, `DUPLICATE_PRODUCT`, `MALFORMED_PRODUCT`

Provenance phân biệt `FACTUAL`, `DERIVED`, `USER_GENERATED`; field suy ra từ phrase mapping được ghi `evidence_type=inferred` và confidence riêng. Validation time không được dùng giả làm verification time.

## Recommendation Flow

```text
User Profile
  → Candidate Generation
  → Hard Constraints / Safety Filter
  → Knowledge-Based Score
  → Content-Based Score
  → Hybrid Ranking
  → Explanation
```

Hard constraint trả `FILTERED_OUT` cùng reason code như `USER_EXCLUDED_INGREDIENT`, `OUTSIDE_BUDGET` hoặc `CURRENCY_MISMATCH`. Preferred brand/category vẫn là soft preference.

## API hiện đã triển khai

- `GET /health`
- `GET /ready`
- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/profile`
- `GET /products`
- `GET /products/{productId}`
- `POST /orders`
- `GET /orders`
- `GET /admin/orders` (ADMIN)
- `POST /behavior-events`
- `POST /recommendations/personalized`
- `GET /recommendations/similar-products/{productId}`
- `POST /recommendations/explain`

Contract: `contracts/openapi/system-api.yaml`.

## Chạy test

Python 3.12+, Flutter và dependencies trong `requirements-data-pipeline.txt` cùng `services/recommendation-service/requirements.txt`. Có thể đặt `PYTHON_BIN` và `FLUTTER_BIN` nếu hai executable chưa nằm trong `PATH`.

```powershell
./scripts/test.ps1
```

Lệnh trên chạy data-pipeline tests, backend tests, `flutter analyze` và Flutter widget/unit tests.

MySQL integration test là tùy chọn và không được chạy vào production DB. Integration flow mặc định dùng in-memory database deterministic.

## Offline evaluation

```powershell
Set-Location services/recommendation-service
python -m recommendation_service.evaluation_cli
```

Output:

- `datasets/reports/recommendation_evaluation_report.json`
- `datasets/reports/recommendation_evaluation_report.csv`

Fixture hiện tại là expert/developer-defined offline set, không phải production user ground truth và không chứng minh hiệu quả trên người dùng thật.

## Configuration

Copy `.env.example` thành `.env.local` cho môi trường local. Không commit credential. Khi có budget, API yêu cầu `budgetCurrency`; importer chỉ nhận record có currency hợp lệ.
