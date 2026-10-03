CREATE TABLE IF NOT EXISTS promotions (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(160) NOT NULL,
  type VARCHAR(40) NOT NULL DEFAULT 'FLASH_SALE',
  start_at DATETIME NOT NULL,
  end_at DATETIME NOT NULL,
  status ENUM('DRAFT', 'ACTIVE', 'ENDED', 'CANCELED') NOT NULL DEFAULT 'DRAFT',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_promotions_active_window (status, start_at, end_at)
);

CREATE TABLE IF NOT EXISTS promotion_products (
  promotion_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  sale_price DECIMAL(12, 2) NOT NULL,
  PRIMARY KEY (promotion_id, product_id),
  CONSTRAINT fk_promotion_products_promotion
    FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE CASCADE,
  CONSTRAINT fk_promotion_products_product
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT chk_promotion_sale_price CHECK (sale_price >= 0)
);
