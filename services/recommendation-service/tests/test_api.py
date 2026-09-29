import importlib.util
import os
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from recommendation_service.catalog import CatalogRepository
from recommendation_service.models import Product


FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None


@unittest.skipUnless(FASTAPI_AVAILABLE, "fastapi is not installed in this Python environment")
class ApiPayloadTest(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        products = [
            Product(
                product_id=1,
                sku="SKU-1",
                name="Acne Cleanser",
                brand="COSRX",
                category="cleanser",
                price=15,
                skin_types=("oily",),
                skin_concerns=("acne",),
                care_goals=("anti_acne",),
            ),
            Product(
                product_id=2,
                sku="SKU-2",
                name="Hydrating Serum",
                brand="LANEIGE",
                category="serum",
                price=30,
                skin_types=("dry",),
                skin_concerns=("dryness",),
                care_goals=("hydrate",),
            ),
        ]
        self.client = TestClient(
            create_app(
                catalog_repository=CatalogRepository(products),
                database_override=None,
            )
        )

    def test_payload_to_request_preserves_datetime_occurred_at(self):
        from recommendation_service.api import (
            EventType,
            RecommendationBehaviorPayload,
            RecommendationPayload,
            _payload_to_request,
        )

        occurred_at = datetime(2026, 9, 22, 8, 30, tzinfo=timezone.utc)
        payload = RecommendationPayload(
            userId=1,
            behaviors=[
                RecommendationBehaviorPayload(
                    eventType=EventType.VIEW_PRODUCT,
                    productId=7,
                    occurredAt=occurred_at,
                )
            ],
        )

        request = _payload_to_request(payload)

        self.assertEqual(request.behaviors[0].occurred_at, occurred_at)

    def test_health_reports_liveness_identity(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")
        self.assertEqual(response.json()["service"], "recommendation-service")

    def test_product_catalog_supports_listing_filtering_and_detail(self):
        listing = self.client.get("/products?category=serum&limit=10")

        self.assertEqual(listing.status_code, 200)
        self.assertEqual(listing.json()["total"], 1)
        self.assertEqual(listing.json()["items"][0]["productId"], 2)
        self.assertEqual(listing.json()["items"][0]["currency"], None)

        detail = self.client.get("/products/1")
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.json()["name"], "Acne Cleanser")

        missing = self.client.get("/products/999")
        self.assertEqual(missing.status_code, 404)

    def test_product_catalog_supports_price_filter_sort_and_pagination(self):
        response = self.client.get(
            "/products?priceMin=10&priceMax=30&sort=price_desc&limit=1&offset=0"
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["total"], 2)
        self.assertEqual(response.json()["items"][0]["productId"], 2)
        self.assertEqual(response.json()["limit"], 1)
        self.assertEqual(response.json()["offset"], 0)

        next_page = self.client.get(
            "/products?priceMin=10&priceMax=30&sort=price_desc&limit=1&offset=1"
        )
        self.assertEqual(next_page.json()["items"][0]["productId"], 1)

    def test_product_catalog_filters_by_concern_and_care_goal(self):
        acne = self.client.get("/products?concern=acne")
        hydration = self.client.get("/products?goal=hydrate")

        self.assertEqual(acne.status_code, 200)
        self.assertEqual(acne.json()["total"], 1)
        self.assertEqual(acne.json()["items"][0]["productId"], 1)
        self.assertEqual(hydration.status_code, 200)
        self.assertEqual(hydration.json()["total"], 1)
        self.assertEqual(hydration.json()["items"][0]["productId"], 2)

    def test_local_flutter_web_origin_is_allowed_by_cors(self):
        response = self.client.options(
            "/products",
            headers={
                "Origin": "http://localhost:52143",
                "Access-Control-Request-Method": "GET",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:52143",
        )

    def test_ready_requires_non_empty_catalog(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        client = TestClient(create_app(catalog_repository=CatalogRepository([]), database_override=None))
        response = client.get("/ready")

        self.assertEqual(response.status_code, 503)
        self.assertFalse(response.json()["detail"]["checks"]["catalogAvailable"])

    def test_ready_succeeds_with_catalog_and_no_required_database(self):
        response = self.client.get("/ready")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ready")

    def test_ready_fails_when_required_database_is_unavailable(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        class UnavailableDatabase:
            def is_available(self):
                return False

        product = Product(
            product_id=9, sku="S9", name="X", brand="B", category="serum", price=10
        )
        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository([product]),
                database_override=UnavailableDatabase(),
            )
        )
        response = client.get("/ready")

        self.assertEqual(response.status_code, 503)
        self.assertFalse(response.json()["detail"]["checks"]["databaseAvailable"])

    def test_http_rejects_unknown_skin_type(self):
        response = self.client.post(
            "/recommendations/personalized",
            json={"context": {"skinType": "very_oily"}},
        )

        self.assertEqual(response.status_code, 422)

    def test_inline_behavior_does_not_require_identity(self):
        from recommendation_service.api import EventType, RecommendationBehaviorPayload

        payload = RecommendationBehaviorPayload(
            eventType=EventType.VIEW_PRODUCT,
            productId=1,
        )

        self.assertEqual(payload.productId, 1)

    def test_invalid_budget_range_is_pydantic_validation_error(self):
        from pydantic import ValidationError
        from recommendation_service.api import RecommendationContextPayload

        with self.assertRaises(ValidationError):
            RecommendationContextPayload(budgetMin=100, budgetMax=10)

    def test_valid_budget_range_allows_equal_and_ascending_values(self):
        from recommendation_service.api import RecommendationContextPayload

        ascending = RecommendationContextPayload(budgetMin=10, budgetMax=20, budgetCurrency="USD")
        equal = RecommendationContextPayload(budgetMin=10, budgetMax=10, budgetCurrency="USD")

        self.assertEqual(ascending.budgetMin, 10)
        self.assertEqual(equal.budgetMax, 10)

    def test_budget_requires_currency(self):
        from pydantic import ValidationError
        from recommendation_service.api import RecommendationContextPayload

        with self.assertRaises(ValidationError):
            RecommendationContextPayload(budgetMax=20)

    def test_limit_validation_rejects_values_above_50(self):
        from pydantic import ValidationError
        from recommendation_service.api import RecommendationPayload

        with self.assertRaises(ValidationError):
            RecommendationPayload(limit=51)

    def test_http_personalized_rejects_limit_above_50(self):
        response = self.client.post("/recommendations/personalized", json={"limit": 51})

        self.assertEqual(response.status_code, 422)

    def test_http_personalized_rejects_limit_zero(self):
        response = self.client.post("/recommendations/personalized", json={"limit": 0})

        self.assertEqual(response.status_code, 422)

    def test_http_similar_rejects_limit_above_50(self):
        response = self.client.get("/recommendations/similar-products/1?limit=51")

        self.assertEqual(response.status_code, 422)

    def test_http_similar_rejects_non_positive_product_id(self):
        response = self.client.get("/recommendations/similar-products/0")

        self.assertEqual(response.status_code, 422)

    def test_http_behavior_rejects_invalid_event_type(self):
        response = self.client.post(
            "/behavior-events",
            json={"userId": 1, "eventType": "viewProduct", "productId": 1},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_behavior_rejects_invalid_occurred_at(self):
        response = self.client.post(
            "/behavior-events",
            json={"userId": 1, "eventType": "view_product", "productId": 1, "occurredAt": "not-a-date"},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_behavior_requires_user_or_session(self):
        response = self.client.post(
            "/behavior-events",
            json={"eventType": "view_product", "productId": 1},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_behavior_rejects_blank_session_without_user(self):
        response = self.client.post(
            "/behavior-events",
            json={"sessionId": "   ", "eventType": "search_keyword"},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_behavior_rejects_session_id_above_schema_limit(self):
        response = self.client.post(
            "/behavior-events",
            json={"sessionId": "s" * 121, "eventType": "search_keyword"},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_behavior_trims_session_id_before_save(self):
        from recommendation_service.api import create_app
        from fastapi.testclient import TestClient

        class CapturingDatabase:
            def __init__(self):
                self.session_id = None

            def save_behavior_event(self, *, user_id, session_id, event):
                self.session_id = session_id
                return {"eventId": 123}

        database = CapturingDatabase()
        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository([]),
                database_override=database,
            )
        )

        response = client.post(
            "/behavior-events",
            json={"sessionId": "  anon-1  ", "eventType": "search_keyword"},
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(database.session_id, "anon-1")

    def test_http_personalized_rejects_session_id_above_schema_limit(self):
        response = self.client.post(
            "/recommendations/personalized",
            json={"sessionId": "s" * 121},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_personalized_trims_session_id(self):
        from recommendation_service.api import create_app
        from recommendation_service.models import RecommendationContext
        from fastapi.testclient import TestClient

        class CapturingDatabase:
            def __init__(self):
                self.session_id = None

            def load_user_context(self, user_id):
                return RecommendationContext()

            def load_behavior_events(self, *, user_id, session_id):
                self.session_id = session_id
                return ()

            def save_recommendation_log(self, **kwargs):
                return None

        database = CapturingDatabase()
        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository([]),
                database_override=database,
            )
        )

        response = client.post(
            "/recommendations/personalized",
            json={"sessionId": "  anon-1  "},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(database.session_id, "anon-1")

    def test_http_behavior_product_event_requires_product_id(self):
        response = self.client.post(
            "/behavior-events",
            json={"userId": 1, "eventType": "view_product"},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_behavior_rejects_non_positive_user_id(self):
        for invalid in (0, -1):
            response = self.client.post(
                "/behavior-events",
                json={"userId": invalid, "eventType": "search_keyword"},
            )
            self.assertEqual(response.status_code, 422)

    def test_http_behavior_rejects_non_positive_product_id(self):
        for invalid in (0, -1):
            response = self.client.post(
                "/behavior-events",
                json={"userId": 1, "eventType": "view_product", "productId": invalid},
            )
            self.assertEqual(response.status_code, 422)

    def test_http_search_behavior_can_omit_product_id(self):
        response = self.client.post(
            "/behavior-events",
            json={"sessionId": "anon-1", "eventType": "search_keyword"},
        )

        self.assertEqual(response.status_code, 503)

    def test_http_personalized_rejects_invalid_exclude_product_ids(self):
        for invalid in (0, -1):
            response = self.client.post(
                "/recommendations/personalized",
                json={"excludeProductIds": [invalid]},
            )
            self.assertEqual(response.status_code, 422)

        response = self.client.post(
            "/recommendations/personalized",
            json={"excludeProductIds": [1, 2]},
        )
        self.assertEqual(response.status_code, 200)

    def test_http_personalized_rejects_invalid_budget_range(self):
        response = self.client.post(
            "/recommendations/personalized",
            json={"context": {"budgetMin": 100, "budgetMax": 10}},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_personalized_rejects_negative_budget(self):
        response = self.client.post(
            "/recommendations/personalized",
            json={"context": {"budgetMin": -1}},
        )

        self.assertEqual(response.status_code, 422)

    def test_http_personalized_rejects_non_positive_user_id(self):
        for invalid in (0, -1):
            response = self.client.post(
                "/recommendations/personalized",
                json={"userId": invalid},
            )
            self.assertEqual(response.status_code, 422)

    def test_http_database_exception_response_hides_raw_error(self):
        from recommendation_service.api import create_app
        from fastapi.testclient import TestClient

        class FailingDatabase:
            def load_user_context(self, user_id):
                raise RuntimeError("mysql://root:secret@127.0.0.1/cosmetic_ecommerce is down")

            def load_behavior_events(self, *, user_id, session_id):
                return ()

            def save_recommendation_log(self, **kwargs):
                return None

        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository([]),
                database_override=FailingDatabase(),
            )
        )

        response = client.post("/recommendations/personalized", json={"userId": 1})

        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["detail"], "Recommendation database is temporarily unavailable")
        self.assertNotIn("secret", response.text)

    def test_recommendation_logging_failure_does_not_discard_response(self):
        from recommendation_service.api import create_app
        from recommendation_service.models import RecommendationContext
        from fastapi.testclient import TestClient

        class LoggingFailureDatabase:
            def load_user_context(self, user_id):
                return RecommendationContext()

            def load_behavior_events(self, *, user_id, session_id):
                return ()

            def save_recommendation_log(self, **kwargs):
                raise RuntimeError("logging database is unavailable")

        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository(
                    [
                        Product(
                            product_id=1,
                            sku="SKU-1",
                            name="Serum",
                            brand="Example",
                            category="serum",
                            price=10,
                            currency="USD",
                        )
                    ]
                ),
                database_override=LoggingFailureDatabase(),
            )
        )

        response = client.post("/recommendations/personalized", json={})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["items"][0]["productId"], 1)

    def test_unavailable_database_uses_csv_degraded_mode(self):
        from recommendation_service.api import create_app
        from fastapi.testclient import TestClient

        class UnavailableDatabase:
            def is_available(self):
                return False

        with tempfile.TemporaryDirectory() as directory:
            catalog_path = Path(directory) / "catalog.csv"
            catalog_path.write_text(
                "sku,name,brand_normalized,category_normalized,price,currency\n"
                "101,Offline Serum,Example,serum,10,USD\n",
                encoding="utf-8",
            )
            with patch.dict(os.environ, {"RECOMMENDATION_CATALOG_PATH": str(catalog_path)}):
                client = TestClient(create_app(database_override=UnavailableDatabase()))

            ready = client.get("/ready")
            recommendation = client.post("/recommendations/personalized", json={})

        self.assertEqual(ready.status_code, 200)
        self.assertEqual(ready.json()["status"], "ready_degraded")
        self.assertTrue(ready.json()["checks"]["degradedMode"])
        self.assertEqual(recommendation.status_code, 200)
        self.assertEqual(recommendation.json()["items"][0]["productId"], 101)

    def test_http_missing_db_product_returns_404(self):
        from recommendation_service.api import create_app
        from recommendation_service.database import ProductNotFoundError
        from fastapi.testclient import TestClient

        class MissingProductDatabase:
            def save_behavior_event(self, **kwargs):
                raise ProductNotFoundError(999)

        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository([]),
                database_override=MissingProductDatabase(),
            )
        )

        response = client.post(
            "/behavior-events",
            json={
                "sessionId": "guest-test",
                "eventType": "view_product",
                "productId": 999,
            },
        )

        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["detail"], "Product not found")


if __name__ == "__main__":
    unittest.main()
