# chatbot-service

Service phụ trách chatbot tư vấn sản phẩm dựa trên dữ liệu đã kiểm duyệt trong hệ thống.

## Phạm vi

- Nhận câu hỏi hoặc lựa chọn của người dùng.
- Xác định nhu cầu: loại da, vấn đề da, danh mục, ngân sách, thành phần cần tránh.
- Truy vấn dữ liệu sản phẩm và recommendation-service khi cần.
- Sinh câu trả lời theo mẫu, có kiểm soát, không bịa thông tin ngoài dữ liệu.

## Nguyên tắc an toàn

- Không chẩn đoán bệnh da.
- Không cam kết hiệu quả điều trị.
- Không thay thế tư vấn của chuyên gia y tế.
- Luôn dựa trên thuộc tính sản phẩm, thành phần, công dụng và cảnh báo đã lưu trong database.
