-- Chuẩn hóa catalog bán cho khách Việt.
-- Tỷ giá hiển thị cố định cho dữ liệu catalog hiện tại: 1 USD = 25.000 VND.
-- Chỉ chuyển các dòng còn USD; dữ liệu đã ở VND không bị thay đổi.
UPDATE products
SET price = ROUND(price * 25000, 0),
    currency = 'VND'
WHERE currency = 'USD';

UPDATE user_profiles
SET budget_min = ROUND(budget_min * 25000, 0),
    budget_max = ROUND(budget_max * 25000, 0),
    budget_currency = 'VND'
WHERE budget_currency = 'USD';
