ALTER TABLE products
  ADD COLUMN ai_ready BOOLEAN NOT NULL DEFAULT FALSE AFTER status;

CREATE INDEX idx_products_recommendation_ready
  ON products (status, ai_ready, stock_quantity);
