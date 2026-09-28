ALTER TABLE orders
  ADD COLUMN currency CHAR(3) NOT NULL AFTER total_amount,
  ADD COLUMN shipping_name VARCHAR(120) NOT NULL AFTER currency,
  ADD COLUMN shipping_phone VARCHAR(30) NOT NULL AFTER shipping_name,
  ADD COLUMN shipping_address VARCHAR(500) NOT NULL AFTER shipping_phone,
  ADD COLUMN note TEXT NULL AFTER shipping_address,
  ADD COLUMN payment_method ENUM('COD', 'BANK_TRANSFER') NOT NULL DEFAULT 'COD' AFTER note;

CREATE INDEX idx_orders_user_created
  ON orders (user_id, created_at);
