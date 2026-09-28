import importlib.util
import json
import os
import unittest
import uuid
from datetime import datetime


MYSQL_INTEGRATION_ENABLED = (
    os.getenv("RUN_RECOMMENDATION_MYSQL_INTEGRATION", "").lower()
    in {"1", "true", "yes", "on"}
)
FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None
try:
    MYSQL_CONNECTOR_AVAILABLE = importlib.util.find_spec("mysql.connector") is not None
except ModuleNotFoundError:
    MYSQL_CONNECTOR_AVAILABLE = False


@unittest.skipUnless(
    MYSQL_INTEGRATION_ENABLED and FASTAPI_AVAILABLE and MYSQL_CONNECTOR_AVAILABLE,
    "set RUN_RECOMMENDATION_MYSQL_INTEGRATION=true with FastAPI and mysql-connector installed",
)
class RecommendationMySQLIntegrationTest(unittest.TestCase):
    def setUp(self):
        os.environ["RECOMMENDATION_DB_ENABLED"] = "true"
        import mysql.connector  # type: ignore

        self.conn = mysql.connector.connect(
            host=os.getenv("MYSQL_HOST", "127.0.0.1"),
            port=int(os.getenv("MYSQL_PORT", "3306")),
            user=os.getenv("MYSQL_USER", "root"),
            password=os.getenv("MYSQL_PASSWORD", ""),
            database=os.getenv("MYSQL_DATABASE", "cosmetic_ecommerce"),
            charset="utf8mb4",
            autocommit=False,
        )
        self.cursor = self.conn.cursor()
        self.suffix = uuid.uuid4().hex[:10]
        self.ids: dict[str, int] = {}
        self.session_id = f"it-session-{self.suffix}"

    def tearDown(self):
        try:
            product_ids = [
                self.ids.get("product_a"),
                self.ids.get("product_b"),
                self.ids.get("product_c"),
                self.ids.get("product_d"),
            ]
            product_ids = [pid for pid in product_ids if pid]
            if self.ids.get("user"):
                self.cursor.execute(
                    "DELETE FROM recommendation_logs WHERE user_id=%s OR session_id=%s",
                    (self.ids["user"], self.session_id),
                )
                self.cursor.execute(
                    "DELETE FROM user_behavior_events WHERE user_id=%s OR session_id=%s",
                    (self.ids["user"], self.session_id),
                )
            if product_ids:
                placeholders = ",".join(["%s"] * len(product_ids))
                self.cursor.execute(f"DELETE FROM user_behavior_events WHERE product_id IN ({placeholders})", product_ids)
                self.cursor.execute(f"DELETE FROM order_items WHERE product_id IN ({placeholders})", product_ids)
                self.cursor.execute(f"DELETE FROM products WHERE id IN ({placeholders})", product_ids)
            if self.ids.get("user"):
                self.cursor.execute("DELETE FROM user_profiles WHERE user_id=%s", (self.ids["user"],))
                self.cursor.execute("DELETE FROM users WHERE id=%s", (self.ids["user"],))
            for key in ("brand_a", "brand_b"):
                if self.ids.get(key):
                    self.cursor.execute("DELETE FROM brands WHERE id=%s", (self.ids[key],))
            if self.ids.get("category"):
                self.cursor.execute("DELETE FROM categories WHERE id=%s", (self.ids["category"],))
            self.conn.commit()
        finally:
            self.cursor.close()
            self.conn.close()

    def test_behavior_to_recommendation_end_to_end(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        self._insert_fixture_data()

        client = TestClient(create_app())
        behavior_response = client.post(
            "/behavior-events",
            json={
                "userId": self.ids["user"],
                "sessionId": self.session_id,
                "eventType": "view_product",
                "productId": self.ids["product_a"],
                "occurredAt": "2026-09-22T10:00:00+07:00",
            },
        )
        self.assertEqual(behavior_response.status_code, 202, behavior_response.text)

        self.cursor.execute(
            "SELECT occurred_at FROM user_behavior_events WHERE user_id=%s AND product_id=%s",
            (self.ids["user"], self.ids["product_a"]),
        )
        self.assertEqual(self.cursor.fetchone()[0], datetime(2026, 9, 22, 3, 0, 0))

        recommendation_response = client.post(
            "/recommendations/personalized",
            json={"userId": self.ids["user"], "sessionId": self.session_id, "limit": 10},
        )
        self.assertEqual(recommendation_response.status_code, 200, recommendation_response.text)
        payload = recommendation_response.json()
        product_ids = [item["productId"] for item in payload["items"]]

        self.assertIn(self.ids["product_a"], product_ids)
        self.assertNotIn(self.ids["product_c"], product_ids)
        self.assertNotIn(self.ids["product_d"], product_ids)
        self.assertTrue(all(pid in {self.ids["product_a"], self.ids["product_b"]} for pid in product_ids))

        first_item = payload["items"][0]
        self.assertEqual(first_item["productId"], self.ids["product_a"])
        self.assertTrue(any("thương hiệu" in reason.lower() for reason in first_item["reasons"]))

        self.cursor.execute(
            """
            SELECT algorithm, session_id, result_items
            FROM recommendation_logs
            WHERE user_id=%s AND session_id=%s
            ORDER BY id DESC
            LIMIT 1
            """,
            (self.ids["user"], self.session_id),
        )
        log_row = self.cursor.fetchone()
        self.assertIsNotNone(log_row)
        algorithm, session_id, result_items = log_row
        self.assertEqual(algorithm, payload["algorithm"])
        self.assertEqual(session_id, self.session_id)
        if isinstance(result_items, (bytes, bytearray)):
            result_items = result_items.decode("utf-8")
        logged_items = json.loads(result_items) if isinstance(result_items, str) else result_items
        self.assertGreaterEqual(len(logged_items), 1)
        self.assertEqual(logged_items[0]["productId"], self.ids["product_a"])
        self.assertNotIn(self.ids["product_c"], [item["productId"] for item in logged_items])
        self.assertNotIn(self.ids["product_d"], [item["productId"] for item in logged_items])

    def _insert_fixture_data(self):
        brand_a = f"IT COSRX {self.suffix}"
        brand_b = f"IT Other {self.suffix}"
        category = f"IT Serum {self.suffix}"
        email = f"it-{self.suffix}@example.test"

        self.cursor.execute(
            "INSERT INTO brands (name, country, official_url) VALUES (%s, %s, %s)",
            (brand_a, "KR", "https://example.test/a"),
        )
        self.ids["brand_a"] = self.cursor.lastrowid
        self.cursor.execute(
            "INSERT INTO brands (name, country, official_url) VALUES (%s, %s, %s)",
            (brand_b, "US", "https://example.test/b"),
        )
        self.ids["brand_b"] = self.cursor.lastrowid
        self.cursor.execute("INSERT INTO categories (name, parent_id) VALUES (%s, NULL)", (category,))
        self.ids["category"] = self.cursor.lastrowid
        self.cursor.execute(
            "INSERT INTO users (full_name, email, password_hash, role, skin_type) VALUES (%s, %s, %s, %s, %s)",
            ("Integration User", email, "test-hash", "CUSTOMER", "oily"),
        )
        self.ids["user"] = self.cursor.lastrowid
        self.cursor.execute(
            """
            INSERT INTO user_profiles
                (user_id, skin_type, skin_concerns, care_goals, preferred_categories,
                 preferred_brands, avoid_ingredients, budget_min, budget_max, profile_confidence)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                self.ids["user"],
                "oily",
                "acne",
                "anti_acne",
                "",
                brand_a.lower(),
                "",
                None,
                None,
                1.0,
            ),
        )
        self.ids["product_a"] = self._insert_product("A", self.ids["brand_a"], "ACTIVE", 10)
        self.ids["product_b"] = self._insert_product("B", self.ids["brand_b"], "ACTIVE", 10)
        self.ids["product_c"] = self._insert_product("C", self.ids["brand_a"], "DRAFT", 10)
        self.ids["product_d"] = self._insert_product("D", self.ids["brand_a"], "ACTIVE", 0)
        self.conn.commit()

    def _insert_product(self, label: str, brand_id: int, status: str, stock: int) -> int:
        sku = f"IT-{self.suffix}-{label}"
        self.cursor.execute(
            """
            INSERT INTO products
                (sku, name, brand_id, category_id, price, volume, stock_quantity,
                 description, benefits, inci_ingredients, key_ingredients,
                 skin_types, skin_concerns, care_goals, texture, usage_instruction,
                 warnings, image_url, source_url, verified_at, status, ai_ready)
            VALUES
                (%s, %s, %s, %s, %s, %s, %s,
                 %s, %s, %s, %s,
                 %s, %s, %s, %s, %s,
                 %s, %s, %s, CURRENT_DATE, %s, TRUE)
            """,
            (
                sku,
                f"Integration Product {label}",
                brand_id,
                self.ids["category"],
                19.99,
                "30ml",
                stock,
                "Acne care serum",
                "Helps acne-prone skin",
                "Water, Tea Tree",
                "Tea Tree",
                "oily,sensitive",
                "acne",
                "anti_acne,soothe",
                "serum",
                "Use once daily",
                "",
                "https://example.test/image.jpg",
                f"https://example.test/{sku}",
                status,
            ),
        )
        return self.cursor.lastrowid


if __name__ == "__main__":
    unittest.main()
