# Data Dictionary

## Nhóm dữ liệu thương mại điện tử

| Bảng | Mục đích |
|---|---|
| `users` | Tài khoản khách hàng và quản trị viên |
| `brands` | Thương hiệu mỹ phẩm |
| `categories` | Danh mục sản phẩm |
| `products` | Sản phẩm mỹ phẩm và thuộc tính phục vụ gợi ý/chatbot |
| `ingredients` | Ingredient master theo normalized identity/INCI, vẫn giữ nguồn |
| `product_ingredients` | Liên kết product-ingredient, position và raw_name |
| `product_field_provenance` | Provenance theo field, FACTUAL/DERIVED/USER_GENERATED |
| `ingredient_regulatory_status` | Trạng thái theo jurisdiction/condition/source; không phải safe boolean |
| `orders` | Đơn hàng |
| `order_items` | Chi tiết sản phẩm trong đơn hàng |

## Nhóm dữ liệu hệ thống bên trong

| Bảng | Mục đích |
|---|---|
| `user_behavior_events` | Lưu hành vi người dùng để phân tích và gợi ý |
| `user_profiles` | Hồ sơ sở thích và nhu cầu chăm sóc da |
| `recommendation_logs` | Lưu request/result của hệ thống gợi ý để đánh giá |
| `chatbot_conversations` | Lưu hội thoại chatbot phục vụ phân tích và cải tiến |

## Trường sản phẩm quan trọng cho AI

| Trường | Ý nghĩa |
|---|---|
| `skin_types` | Loại da phù hợp: oily, dry, combination, sensitive, normal |
| `skin_concerns` | Vấn đề da: acne, dark_spot, dryness, aging, redness |
| `care_goals` | Mục tiêu: hydrate, brighten, anti_acne, repair, sunscreen |
| `inci_ingredients` | Thành phần INCI đầy đủ |
| `key_ingredients` | Thành phần nổi bật và công dụng chính |
| `warnings` | Cảnh báo hoặc lưu ý khi sử dụng |
| `source_url` | Nguồn dữ liệu để kiểm chứng |
| `verified_at` | Ngày dữ liệu được xác minh |
| `currency` | ISO 4217 currency của giá; không suy đoán khi nguồn thiếu |

`verified_at` chỉ được ghi bởi workflow xác minh rõ ràng, không tự động lấy ngày crawl hoặc ngày validation.
