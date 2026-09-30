ALTER TABLE products
  MODIFY COLUMN status ENUM('ACTIVE', 'INACTIVE', 'DRAFT', 'ARCHIVED')
  NOT NULL DEFAULT 'DRAFT';

ALTER TABLE orders
  MODIFY COLUMN status ENUM(
    'PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPING', 'COMPLETED', 'CANCELED'
  ) NOT NULL DEFAULT 'PENDING';

CREATE INDEX idx_products_admin_status_updated
  ON products (status, updated_at);

CREATE INDEX idx_orders_admin_status_updated
  ON orders (status, updated_at);
