# Behavior Event Contract

File này định nghĩa dữ liệu event mà website gửi sang hệ thống bên trong để phục vụ recommendation, chatbot context, analytics dashboard và stream analytics.

## Event chung

```json
{
  "eventType": "view_product",
  "userId": 1,
  "sessionId": "session-abc",
  "productId": 10,
  "eventValue": 1.0,
  "metadata": {},
  "occurredAt": "2026-09-10T00:00:00+07:00"
}
```

## Event types

| Event type | Khi nào gửi | Dùng cho |
|---|---|---|
| `view_product` | Người dùng mở trang chi tiết sản phẩm | Content-Based, analytics |
| `search_keyword` | Người dùng tìm kiếm | User profile, analytics |
| `filter_used` | Người dùng dùng bộ lọc | Knowledge-Based, analytics |
| `click_recommendation` | Người dùng click sản phẩm được gợi ý | Đánh giá recommendation |
| `add_favorite` | Thêm sản phẩm vào yêu thích | Content-Based |
| `add_to_cart` | Thêm sản phẩm vào giỏ hàng | Recommendation, conversion |
| `remove_from_cart` | Xóa sản phẩm khỏi giỏ | Analytics |
| `place_order` | Đặt hàng thành công | Collaborative Filtering |
| `review_product` | Đánh giá sản phẩm | Product quality, CF |
| `chatbot_message` | Gửi tin nhắn chatbot | Chatbot analytics |

## Gợi ý trọng số hành vi

| Event type | Weight |
|---|---:|
| `view_product` | 1 |
| `search_keyword` | 1 |
| `filter_used` | 1 |
| `click_recommendation` | 2 |
| `add_favorite` | 3 |
| `add_to_cart` | 4 |
| `place_order` | 5 |
| `review_product` | 5 |

Trọng số này là mặc định ban đầu, có thể điều chỉnh sau khi có dữ liệu thực nghiệm.
