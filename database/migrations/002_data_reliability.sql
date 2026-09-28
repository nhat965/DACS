ALTER TABLE products ADD COLUMN currency CHAR(3) NULL AFTER price;
ALTER TABLE user_profiles ADD COLUMN budget_currency CHAR(3) NULL AFTER budget_max;

CREATE TABLE ingredients (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  inci_name VARCHAR(255) NOT NULL,
  normalized_name VARCHAR(255) NOT NULL UNIQUE,
  cas_number VARCHAR(80),
  ec_number VARCHAR(80),
  function_text VARCHAR(500),
  source_type VARCHAR(80),
  source_url VARCHAR(500),
  last_verified_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE product_ingredients (
  product_id BIGINT NOT NULL,
  ingredient_id BIGINT NOT NULL,
  position INT,
  raw_name VARCHAR(500) NOT NULL,
  PRIMARY KEY (product_id, ingredient_id),
  CONSTRAINT fk_product_ingredients_product FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT fk_product_ingredients_ingredient FOREIGN KEY (ingredient_id) REFERENCES ingredients(id)
);

CREATE TABLE product_field_provenance (
  product_id BIGINT NOT NULL,
  field_name VARCHAR(80) NOT NULL,
  data_class ENUM('FACTUAL', 'DERIVED', 'USER_GENERATED') NOT NULL,
  source_type VARCHAR(80),
  source_url VARCHAR(500),
  retrieved_at DATETIME,
  last_verified_at DATETIME,
  evidence_type VARCHAR(80) NOT NULL,
  confidence DECIMAL(5, 4),
  extraction_method VARCHAR(120),
  PRIMARY KEY (product_id, field_name),
  CONSTRAINT fk_product_field_provenance_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE ingredient_regulatory_status (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  ingredient_id BIGINT NOT NULL,
  jurisdiction VARCHAR(80) NOT NULL,
  status VARCHAR(80) NOT NULL,
  condition_text TEXT,
  max_concentration DECIMAL(8, 4),
  warning TEXT,
  source_type VARCHAR(80) NOT NULL,
  source_url VARCHAR(500) NOT NULL,
  source_version VARCHAR(120),
  verified_at DATETIME,
  CONSTRAINT fk_regulatory_ingredient FOREIGN KEY (ingredient_id) REFERENCES ingredients(id),
  INDEX idx_regulatory_ingredient_jurisdiction (ingredient_id, jurisdiction)
);
