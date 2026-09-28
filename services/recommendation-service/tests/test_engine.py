import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from recommendation_service.catalog import CatalogRepository
from recommendation_service.engine import RecommendationEngine
from recommendation_service.models import BehaviorEvent, Product, RecommendationContext, RecommendationRequest


def _engine() -> RecommendationEngine:
    products = [
        Product(
            product_id=1,
            sku="A",
            name="Acne Cleanser",
            brand="COSRX",
            category="cleanser",
            price=15,
            currency="USD",
            description="Gentle acne foam with salicylic acid",
            benefits="cleanse acne skin",
            inci_ingredients="Water, Salicylic Acid",
            skin_types=("oily", "combination"),
            skin_concerns=("acne", "oiliness"),
            care_goals=("cleanse", "anti_acne", "oil_control"),
            texture="foam",
        ),
        Product(
            product_id=2,
            sku="B",
            name="Hydrating Serum",
            brand="Laneige",
            category="serum",
            price=30,
            currency="USD",
            description="Hydrating serum with hyaluronic acid",
            benefits="hydrate dry skin",
            inci_ingredients="Water, Hyaluronic Acid",
            skin_types=("dry", "normal"),
            skin_concerns=("dryness",),
            care_goals=("hydrate", "repair"),
            texture="serum",
        ),
        Product(
            product_id=3,
            sku="C",
            name="Acne Serum",
            brand="COSRX",
            category="serum",
            price=22,
            currency="USD",
            description="Acne serum with tea tree",
            benefits="soothe acne",
            inci_ingredients="Water, Tea Tree",
            skin_types=("oily", "sensitive"),
            skin_concerns=("acne",),
            care_goals=("anti_acne", "soothe"),
            texture="liquid",
        ),
    ]
    return RecommendationEngine(CatalogRepository(products))


class RecommendationEngineTest(unittest.TestCase):
    def test_personalized_recommendation_prioritizes_context_matches(self):
        response = _engine().recommend(
            RecommendationRequest(
                limit=2,
                context=RecommendationContext(
                    skin_type="oily",
                    skin_concerns=("acne",),
                    care_goals=("anti_acne",),
                    budget_max=20,
                ),
            )
        )

        self.assertEqual(response.algorithm, "knowledge_content_hybrid")
        self.assertEqual(response.items[0].product_id, 1)
        self.assertTrue(all(item.product_id != 3 for item in response.items))
        self.assertTrue(response.items[0].reasons)

    def test_content_history_excludes_seen_product_and_finds_similar_item(self):
        response = _engine().recommend(
            RecommendationRequest(
                limit=2,
                behaviors=(BehaviorEvent(event_type="add_to_cart", product_id=1),),
            )
        )

        self.assertTrue(all(item.product_id != 1 for item in response.items))
        self.assertEqual(response.items[0].product_id, 3)

    def test_similar_products_uses_content_overlap(self):
        response = _engine().similar_products(1, limit=2)

        self.assertEqual(response.algorithm, "content_based_similar")
        self.assertEqual(response.items[0].product_id, 3)
        self.assertIn("Cùng", response.items[0].reasons[0])

    def test_avoid_ingredients_filters_exact_inci_terms(self):
        response = _engine().recommend(
            RecommendationRequest(
                context=RecommendationContext(
                    skin_concerns=("acne",),
                    avoid_ingredients=("salicylic acid",),
                ),
            )
        )

        self.assertTrue(all(item.product_id != 1 for item in response.items))

    def test_avoid_ingredient_alias_is_a_hard_exclusion(self):
        product = Product(
            product_id=10,
            sku="F",
            name="Fragranced Serum",
            brand="Example",
            category="serum",
            price=10,
            currency="USD",
            inci_ingredients="Water, Parfum (Fragrance), Glycerin",
            skin_concerns=("dryness",),
        )
        engine = RecommendationEngine(CatalogRepository([product]))
        request = RecommendationRequest(
            context=RecommendationContext(
                skin_concerns=("dryness",),
                avoid_ingredients=("fragrance",),
            )
        )

        response = engine.recommend(request)
        explanation = engine.explain(10, request)

        self.assertEqual(response.items, ())
        self.assertEqual(response.filtered_candidate_count, 1)
        self.assertIsNotNone(explanation)
        self.assertEqual(explanation.status, "FILTERED_OUT")
        self.assertIn("USER_EXCLUDED_INGREDIENT", explanation.reasons[0])

    def test_preferred_brand_is_soft_ranking_preference(self):
        response = _engine().recommend(
            RecommendationRequest(
                context=RecommendationContext(
                    skin_concerns=("acne",),
                    preferred_brands=("Laneige",),
                )
            )
        )

        self.assertTrue(response.items)
        self.assertTrue(any(item.product_id == 1 for item in response.items))

    def test_explain_scores_product_even_when_catalog_has_more_than_fifty_items(self):
        products = [
            Product(
                product_id=index,
                sku=f"SKU-{index}",
                name=f"Product {index:03d}",
                brand="Example",
                category="serum",
                price=10,
                currency="USD",
                skin_concerns=("acne",),
            )
            for index in range(1, 62)
        ]
        engine = RecommendationEngine(CatalogRepository(products))

        explanation = engine.explain(
            61,
            RecommendationRequest(
                context=RecommendationContext(skin_concerns=("acne",)),
            ),
        )

        self.assertIsNotNone(explanation)
        self.assertEqual(explanation.product_id, 61)
        self.assertEqual(explanation.status, "RANKED")

    def test_explain_returns_not_ranked_instead_of_not_found(self):
        explanation = _engine().explain(
            2,
            RecommendationRequest(
                context=RecommendationContext(skin_concerns=("acne",)),
            ),
        )

        self.assertIsNotNone(explanation)
        self.assertEqual(explanation.status, "NOT_RANKED")

    def test_empty_context_uses_diverse_cold_start(self):
        response = _engine().recommend(RecommendationRequest(limit=2))

        self.assertEqual(response.algorithm, "cold_start_diverse")
        self.assertEqual(len(response.items), 2)

    def test_cold_start_prefers_more_complete_product_within_category(self):
        sparse = Product(
            product_id=20,
            sku="SPARSE",
            name="A Sparse Serum",
            brand="Example",
            category="serum",
            price=10,
            currency="USD",
        )
        complete = Product(
            product_id=21,
            sku="COMPLETE",
            name="Z Complete Serum",
            brand="Example",
            category="serum",
            price=10,
            currency="USD",
            description="Complete description",
            benefits="Hydrates",
            inci_ingredients="Water, Glycerin",
            skin_types=("dry",),
            skin_concerns=("dryness",),
            care_goals=("hydrate",),
            source_url="https://example.com/product",
        )

        response = RecommendationEngine(CatalogRepository([sparse, complete])).recommend(
            RecommendationRequest(limit=1)
        )

        self.assertEqual(response.items[0].product_id, 21)
        self.assertGreater(response.items[0].score, 0.5)

    def test_budget_only_returns_diverse_filtered_recommendations(self):
        response = _engine().recommend(
            RecommendationRequest(
                limit=3,
                context=RecommendationContext(budget_max=20),
            )
        )

        self.assertEqual(response.algorithm, "cold_start_diverse")
        self.assertEqual([item.product_id for item in response.items], [1])

    def test_budget_filter_rejects_product_without_currency(self):
        product = Product(
            product_id=11,
            sku="NO-CURRENCY",
            name="Unknown Currency Product",
            brand="Example",
            category="serum",
            price=10,
            currency=None,
        )
        engine = RecommendationEngine(CatalogRepository([product]))

        response = engine.recommend(
            RecommendationRequest(
                context=RecommendationContext(
                    budget_max=20,
                    budget_currency="USD",
                )
            )
        )

        self.assertEqual(response.items, ())
        self.assertEqual(response.filtered_candidate_count, 1)

    def test_avoid_only_returns_diverse_filtered_recommendations(self):
        response = _engine().recommend(
            RecommendationRequest(
                limit=3,
                context=RecommendationContext(avoid_ingredients=("salicylic acid",)),
            )
        )

        self.assertEqual(response.algorithm, "cold_start_diverse")
        self.assertTrue(response.items)
        self.assertTrue(all(item.product_id != 1 for item in response.items))

    def test_behavior_only_uses_content_weight_only(self):
        response = _engine().recommend(
            RecommendationRequest(
                limit=2,
                behaviors=(BehaviorEvent(event_type="view_product", product_id=1),),
            )
        )

        self.assertEqual(response.weights, {"knowledge_based": 0.0, "content_based": 1.0})
        self.assertEqual(response.items[0].product_id, 3)

    def test_context_and_behavior_use_mixed_weights(self):
        response = _engine().recommend(
            RecommendationRequest(
                limit=2,
                context=RecommendationContext(skin_concerns=("acne",)),
                behaviors=(BehaviorEvent(event_type="view_product", product_id=1),),
            )
        )

        self.assertEqual(response.weights, {"knowledge_based": 0.55, "content_based": 0.45})

    def test_recent_behavior_has_more_weight_than_old_behavior(self):
        engine = _engine()
        now = datetime.now(timezone.utc)
        profile = engine._behavior_profile(
            (
                BehaviorEvent(
                    event_type="view_product",
                    product_id=1,
                    occurred_at=now - timedelta(days=60),
                ),
                BehaviorEvent(
                    event_type="view_product",
                    product_id=3,
                    occurred_at=now,
                ),
            )
        )

        self.assertGreater(profile[3], profile[1])


class CatalogRepositoryTest(unittest.TestCase):
    def test_csv_loader_prefers_real_id_and_splits_comma_terms(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "products.csv"
            path.write_text(
                "\n".join(
                    [
                        "id,sku,name,brand_id,category_id,price,skin_types,skin_concerns,care_goals",
                        "92,SKU-92,Comma Product,7,12,19.5,\"sensitive,combination\",acne,\"cleanse,anti_acne\"",
                    ]
                ),
                encoding="utf-8",
            )

            product = CatalogRepository.from_csv(path).all()[0]

        self.assertEqual(product.product_id, 92)
        self.assertEqual(product.skin_types, ("sensitive", "combination"))
        self.assertEqual(product.care_goals, ("cleanse", "anti_acne"))
        self.assertEqual(product.brand, "brand_7")
        self.assertEqual(product.category, "category_12")


if __name__ == "__main__":
    unittest.main()
