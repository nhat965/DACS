# shared-contracts

Khu vực đặt mã dùng chung nếu nhóm cần chia sẻ DTO, enum, validation schema hoặc type giữa nhiều service.

Ví dụ:

- `UserSkinType`
- `ProductCategory`
- `BehaviorEventType`
- `RecommendationReason`
- Request/response schema cho recommendation, chatbot và analytics.

Nếu website và service dùng công nghệ khác nhau, thư mục này có thể chỉ chứa tài liệu hoặc schema trung lập như JSON Schema/OpenAPI.
