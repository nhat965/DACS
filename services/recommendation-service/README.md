# recommendation-service

Service phụ trách hệ thống gợi ý sản phẩm mỹ phẩm.

## Phạm vi

- Knowledge-Based Recommendation dựa trên loại da, vấn đề da, mục tiêu chăm sóc, ngân sách, thành phần quan tâm và thành phần cần tránh.
- Content-Based Recommendation dựa trên thuộc tính sản phẩm và lịch sử tương tác của người dùng.
- Item-Based Collaborative Filtering ở mức cơ bản khi đủ dữ liệu hành vi.
- Hybrid Scoring để kết hợp nhiều nguồn điểm.
- Trả về danh sách sản phẩm được gợi ý kèm lý do gợi ý.

## API liên quan

- `POST /recommendations/personalized`
- `GET /recommendations/similar-products/{productId}`
- `POST /recommendations/explain`

Chi tiết contract nằm ở `contracts/openapi/system-api.yaml`.
