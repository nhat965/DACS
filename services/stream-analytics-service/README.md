# stream-analytics-service

Service dự phòng cho hướng mở rộng stream analytics.

## Mục tiêu

Xử lý behavior event gần thời gian thực để cập nhật dashboard nhanh hơn và hỗ trợ recommendation theo hành vi mới.

## Phạm vi phiên bản cơ sở

Trong giai đoạn đầu, event có thể ghi trực tiếp vào database qua backend API. Khi hệ thống ổn định, có thể bổ sung message broker như Kafka, RabbitMQ hoặc Redis Streams.

## Event đầu vào

Xem chi tiết trong `contracts/events/behavior-events.md`.
