from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

from recommendation_service.catalog import CatalogRepository
from recommendation_service.models import BehaviorEvent, Product, RecommendationContext


FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None


class InMemoryRecommendationDatabase:
    def __init__(self, products):
        self.products = {product.product_id: product for product in products}
        self.behaviors: list[BehaviorEvent] = []
        self.recommendation_logs: list[dict] = []

    def is_available(self):
        return True

    def load_products(self):
        return tuple(self.products.values())

    def load_user_context(self, user_id):
        return RecommendationContext()

    def load_behavior_events(self, *, user_id, session_id):
        return tuple(self.behaviors)

    def save_behavior_event(self, *, user_id, session_id, event):
        if event.product_id not in self.products:
            raise ValueError("unknown product")
        self.behaviors.append(event)
        return {"stored": True, "eventId": len(self.behaviors), "productId": event.product_id}

    def save_recommendation_log(self, **payload):
        self.recommendation_logs.append(payload)


def _load_ai_ready_products():
    path = Path(__file__).parent / "fixtures" / "ai_ready_catalog.json"
    rows = json.loads(path.read_text(encoding="utf-8"))
    return tuple(
        Product(
            product_id=row["product_id"],
            sku=row["sku"],
            name=row["name"],
            brand=row["brand"],
            category=row["category"],
            price=row["price"],
            currency=row["currency"],
            description=row["description"],
            benefits=row["benefits"],
            inci_ingredients=row["inci_ingredients"],
            skin_types=tuple(row["skin_types"]),
            skin_concerns=tuple(row["skin_concerns"]),
            care_goals=tuple(row["care_goals"]),
        )
        for row in rows
    )


@unittest.skipUnless(FASTAPI_AVAILABLE, "fastapi is not installed")
class RecommendationIntegrationFlowTest(unittest.TestCase):
    def test_ai_ready_database_to_recommendation_flow(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        products = _load_ai_ready_products()
        database = InMemoryRecommendationDatabase(products)
        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository(database.load_products()),
                database_override=database,
            )
        )
        payload = {
            "userId": 7,
            "limit": 3,
            "context": {
                "skinType": "oily",
                "skinConcerns": ["acne"],
                "careGoals": ["anti_acne"],
                "budgetMax": 25,
                "budgetCurrency": "USD",
                "avoidIngredients": ["fragrance"]
            }
        }

        first = client.post("/recommendations/personalized", json=payload)
        second = client.post("/recommendations/personalized", json=payload)

        self.assertEqual(first.status_code, 200)
        self.assertEqual(first.json(), second.json())
        self.assertEqual([item["productId"] for item in first.json()["items"]], [101])
        self.assertIn(first.json()["items"][0]["productId"], database.products)
        self.assertEqual(first.json()["filteredCandidateCount"], 2)
        self.assertTrue(first.json()["items"][0]["reasons"])

        excluded = client.post("/recommendations/explain", json={**payload, "productId": 102})
        self.assertEqual(excluded.status_code, 200)
        self.assertEqual(excluded.json()["status"], "FILTERED_OUT")
        self.assertIn("USER_EXCLUDED_INGREDIENT", excluded.json()["reasons"][0])

        similar = client.get("/recommendations/similar-products/101?limit=2")
        self.assertEqual(similar.status_code, 200)
        self.assertTrue(similar.json()["items"])

        behavior = client.post(
            "/behavior-events",
            json={
                "sessionId": "integration-guest",
                "eventType": "view_product",
                "productId": 101,
            },
        )
        self.assertEqual(behavior.status_code, 202)
        self.assertEqual(len(database.behaviors), 1)
        self.assertEqual(len(database.recommendation_logs), 2)


if __name__ == "__main__":
    unittest.main()
