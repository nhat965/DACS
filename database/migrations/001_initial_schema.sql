CREATE DATABASE IF NOT EXISTS cosmetic_ecommerce
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE cosmetic_ecommerce;

CREATE TABLE users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('CUSTOMER', 'ADMIN') NOT NULL DEFAULT 'CUSTOMER',
  skin_type VARCHAR(50),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE brands (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL UNIQUE,
  country VARCHAR(80),
  official_url VARCHAR(255),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL UNIQUE,
  parent_id BIGINT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id) REFERENCES categories(id)
);

CREATE TABLE products (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  sku VARCHAR(80) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  brand_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  price DECIMAL(12, 2) NOT NULL,
  volume VARCHAR(80),
  stock_quantity INT NOT NULL DEFAULT 0,
  description TEXT,
  benefits TEXT,
  inci_ingredients TEXT,
  key_ingredients TEXT,
  skin_types VARCHAR(255),
  skin_concerns VARCHAR(255),
  care_goals VARCHAR(255),
  texture VARCHAR(80),
  usage_instruction TEXT,
  warnings TEXT,
  image_url VARCHAR(500),
  source_url VARCHAR(500),
  verified_at DATE,
  status ENUM('ACTIVE', 'INACTIVE', 'DRAFT') NOT NULL DEFAULT 'DRAFT',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_products_brand
    FOREIGN KEY (brand_id) REFERENCES brands(id),
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE user_behavior_events (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT,
  session_id VARCHAR(120),
  product_id BIGINT,
  event_type VARCHAR(80) NOT NULL,
  event_value DECIMAL(8, 3),
  metadata JSON,
  occurred_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_behavior_user_time (user_id, occurred_at),
  INDEX idx_behavior_product_time (product_id, occurred_at),
  INDEX idx_behavior_type_time (event_type, occurred_at),
  CONSTRAINT fk_behavior_user
    FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_behavior_product
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE user_profiles (
  user_id BIGINT PRIMARY KEY,
  skin_type VARCHAR(50),
  skin_concerns VARCHAR(255),
  care_goals VARCHAR(255),
  preferred_categories VARCHAR(255),
  preferred_brands VARCHAR(255),
  avoid_ingredients VARCHAR(255),
  budget_min DECIMAL(12, 2),
  budget_max DECIMAL(12, 2),
  profile_confidence DECIMAL(5, 4) NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_profiles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE recommendation_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT,
  session_id VARCHAR(120),
  algorithm VARCHAR(80) NOT NULL,
  request_context JSON,
  result_items JSON NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_recommendation_user_time (user_id, created_at),
  CONSTRAINT fk_recommendation_user
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE chatbot_conversations (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT,
  session_id VARCHAR(120),
  user_message TEXT NOT NULL,
  bot_reply TEXT NOT NULL,
  suggested_product_ids JSON,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_chatbot_user_time (user_id, created_at),
  CONSTRAINT fk_chatbot_user
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  status ENUM('PENDING', 'CONFIRMED', 'SHIPPING', 'COMPLETED', 'CANCELED') NOT NULL DEFAULT 'PENDING',
  total_amount DECIMAL(12, 2) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE order_items (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(12, 2) NOT NULL,
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(id),
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(id)
);
