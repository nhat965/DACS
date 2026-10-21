import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

from recommendation_service.database import (
    MySQLSettings,
    ProductNotFoundError,
    _row_to_behavior_event,
    _row_to_product,
    merge_context,
    to_utc_naive,
)
from recommendation_service.engine import _time_decay
from recommendation_service.models import RecommendationContext


class DatabaseMappingTest(unittest.TestCase):
    def test_mysql_settings_parses_url_and_decodes_credentials(self):
        with patch.dict(
            "os.environ",
            {
                "MYSQL_URL": "mysql://db%40user:p%40ss%3Aword@mysql.railway.internal:3307/railway",
                "RECOMMENDATION_DB_ENABLED": "true",
            },
            clear=True,
        ):
            settings = MySQLSettings.from_env(repo_root=Path("missing-env-root"))

        self.assertEqual(settings.host, "mysql.railway.internal")
        self.assertEqual(settings.port, 3307)
        self.assertEqual(settings.user, "db@user")
        self.assertEqual(settings.password, "p@ss:word")
        self.assertEqual(settings.database, "railway")
        self.assertTrue(settings.enabled)

    def test_mysql_settings_rejects_url_without_database(self):
        with patch.dict(
            "os.environ",
            {
                "MYSQL_URL": "mysql://user:password@mysql.railway.internal",
                "RECOMMENDATION_DB_ENABLED": "true",
            },
            clear=True,
        ):
            with self.assertRaisesRegex(ValueError, "host, username, and database"):
                MySQLSettings.from_env(repo_root=Path("missing-env-root"))

    def test_mysql_settings_accepts_aiven_ca_pem(self):
        with patch.dict(
            "os.environ",
            {
                "MYSQL_URL": "mysql://avnadmin:password@mysql-example.aivencloud.com:12345/defaultdb",
                "MYSQL_SSL_CA_PEM": "-----BEGIN CERTIFICATE-----\\nexample\\n-----END CERTIFICATE-----",
                "MYSQL_SSL_MODE": "VERIFY_CA",
                "RECOMMENDATION_DB_ENABLED": "true",
            },
            clear=True,
        ):
            settings = MySQLSettings.from_env(repo_root=Path("missing-env-root"))

        self.assertEqual(settings.host, "mysql-example.aivencloud.com")
        self.assertEqual(settings.port, 12345)
        self.assertIn("\nexample\n", settings.ssl_ca_pem or "")
        self.assertTrue(settings.ssl_verify_cert)
        self.assertFalse(settings.ssl_verify_identity)

    def test_merge_context_prefers_explicit_request_values(self):
        explicit = RecommendationContext(
            skin_type="oily",
            skin_concerns=("acne",),
        )
        stored = RecommendationContext(
            skin_type="dry",
            skin_concerns=("dryness",),
            care_goals=("hydrate",),
            budget_max=30,
        )

        merged = merge_context(explicit, stored)

        self.assertEqual(merged.skin_type, "oily")
        self.assertEqual(merged.skin_concerns, ("acne",))
        self.assertEqual(merged.care_goals, ("hydrate",))
        self.assertEqual(merged.budget_max, 30)

    def test_merge_context_carries_stored_preferred_brands(self):
        explicit = RecommendationContext()
        stored = RecommendationContext(preferred_brands=("cosrx",))

        merged = merge_context(explicit, stored)

        self.assertEqual(merged.preferred_brands, ("cosrx",))

    def test_merge_context_explicit_preferred_brands_override_stored(self):
        explicit = RecommendationContext(preferred_brands=("laneige",))
        stored = RecommendationContext(preferred_brands=("cosrx",))

        merged = merge_context(explicit, stored)

        self.assertEqual(merged.preferred_brands, ("laneige",))

    def test_behavior_row_uses_database_product_id(self):
        event = _row_to_behavior_event(
            {
                "db_product_id": 1,
                "event_type": "view_product",
                "event_value": None,
                "metadata": None,
                "occurred_at": None,
            }
        )

        self.assertEqual(event.product_id, 1)

    def test_product_row_uses_database_id_and_normalizes_category(self):
        product = _row_to_product(
            {
                "id": 7,
                "sku": "113021169",
                "name": "AC Collection Acne Patch",
                "brand": "COSRX",
                "category": "Eye Care",
                "price": "8.99",
                "description": "",
                "benefits": "",
                "inci_ingredients": "",
                "key_ingredients": "",
                "skin_types": "sensitive,dry",
                "skin_concerns": "acne",
                "care_goals": "anti_acne,soothe",
                "texture": "patch",
                "image_url": "",
                "source_url": "",
            }
        )

        self.assertEqual(product.product_id, 7)
        self.assertEqual(product.sku, "113021169")
        self.assertEqual(product.category, "eye_care")
        self.assertEqual(product.skin_types, ("sensitive", "dry"))

    def test_to_utc_naive_converts_utc_plus_7_to_utc(self):
        value = datetime(2026, 9, 22, 10, 0, tzinfo=timezone(timedelta(hours=7)))

        self.assertEqual(to_utc_naive(value), datetime(2026, 9, 22, 3, 0))

    def test_to_utc_naive_keeps_utc_datetime_clock(self):
        value = datetime(2026, 9, 22, 3, 0, tzinfo=timezone.utc)

        self.assertEqual(to_utc_naive(value), datetime(2026, 9, 22, 3, 0))

    def test_to_utc_naive_treats_naive_datetime_as_utc(self):
        value = datetime(2026, 9, 22, 3, 0)

        self.assertEqual(to_utc_naive(value), value)

    def test_to_utc_naive_none_uses_current_utc_naive_datetime(self):
        value = to_utc_naive(None)

        self.assertIsNone(value.tzinfo)
        now_utc_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        self.assertLess(abs((now_utc_naive - value).total_seconds()), 5)

    def test_time_decay_treats_mysql_naive_timestamp_as_utc(self):
        now_utc = datetime.now(timezone.utc)
        aware_plus_7 = now_utc.astimezone(timezone(timedelta(hours=7)))
        mysql_value = to_utc_naive(aware_plus_7)

        self.assertAlmostEqual(_time_decay(mysql_value), _time_decay(now_utc), delta=0.01)

    def test_product_not_found_error_carries_product_id(self):
        error = ProductNotFoundError(999)

        self.assertEqual(error.product_id, 999)


if __name__ == "__main__":
    unittest.main()
