from __future__ import annotations

import unittest
from copy import deepcopy
from decimal import Decimal

from data_pipeline.exporter.reports import build_quality_report
from data_pipeline.normalizer.ingredient_normalizer import normalize_ingredient_name, parse_ingredient_list
from data_pipeline.normalizer.product_normalizer import normalize_product
from data_pipeline.validator.product_validator import validate_processed


def _valid_record() -> dict:
    return {
        "sku": "SKU-1",
        "name": "Test Serum",
        "brand_normalized": "Example",
        "category_normalized": "serum",
        "price": Decimal("10.00"),
        "currency": "USD",
        "description": "Hydrating serum",
        "benefits": "Hydrates",
        "inci_ingredients": "Water, Niacinamide",
        "key_ingredients": "Niacinamide",
        "skin_types": ["dry"],
        "skin_concerns": ["dryness"],
        "care_goals": ["hydrate"],
        "source_url": "https://example.com/product",
        "_processing": {"unmapped_values": {}},
    }


class DataQualityTests(unittest.TestCase):
    def test_missing_name_and_brand_have_stable_reason_codes(self):
        record = _valid_record()
        record["name"] = None
        record["brand_normalized"] = None
        result = validate_processed(record)
        self.assertIn("MISSING_NAME", result["_processing"]["rejection_reasons"])
        self.assertIn("MISSING_BRAND", result["_processing"]["rejection_reasons"])

    def test_zero_price_is_invalid(self):
        record = _valid_record()
        record["price"] = Decimal("0")
        result = validate_processed(record)
        self.assertFalse(result["_processing"]["production_candidate"])
        self.assertIn("INVALID_PRICE", result["_processing"]["rejection_reasons"])

    def test_missing_or_invalid_currency_is_rejected(self):
        for currency in (None, "usd", "US"):
            with self.subTest(currency=currency):
                record = _valid_record()
                record["currency"] = currency
                result = validate_processed(record)
                self.assertIn("INVALID_CURRENCY", result["_processing"]["rejection_reasons"])

    def test_malformed_source_url_is_rejected(self):
        normalized = normalize_product({
            "product_name_raw": "Test",
            "brand_raw": "Example",
            "category_raw": "serum",
            "sku_raw": "S1",
            "price_raw": "10",
            "currency_raw": "USD",
            "product_url": "not-a-url",
        })
        result = validate_processed(normalized)
        self.assertIn("INVALID_SOURCE", result["_processing"]["rejection_reasons"])

    def test_duplicate_reason_code(self):
        record = _valid_record()
        record["_processing"]["is_duplicate"] = True
        result = validate_processed(record)
        self.assertIn("DUPLICATE_PRODUCT", result["_processing"]["rejection_reasons"])

    def test_missing_ingredient_can_remain_valid_but_not_ai_ready(self):
        record = _valid_record()
        record["inci_ingredients"] = None
        record["key_ingredients"] = None
        result = validate_processed(record)
        self.assertTrue(result["_processing"]["production_candidate"])
        self.assertFalse(result["_processing"]["ai_ready"])
        self.assertIn("INSUFFICIENT_AI_FEATURES", result["_processing"]["rejection_reasons"])

    def test_quality_report_contains_required_counts(self):
        valid = validate_processed(_valid_record())
        invalid_input = deepcopy(_valid_record())
        invalid_input["price"] = Decimal("0")
        invalid = validate_processed(invalid_input)
        report = build_quality_report([valid, invalid], duplicate_count=3)
        self.assertEqual(report["total_records"], 2)
        self.assertEqual(report["valid_records"], 1)
        self.assertEqual(report["invalid_records"], 1)
        self.assertEqual(report["duplicate_count"], 3)
        self.assertIn("currency", report["missing_rate_by_field"])
        self.assertIn("missing_percentage_by_field", report["statistics_by_brand"]["Example"])

    def test_ingredient_aliases_keep_raw_names(self):
        self.assertEqual(normalize_ingredient_name("Vitamin B3"), "niacinamide")
        self.assertEqual(normalize_ingredient_name("Parfum (Fragrance)"), "fragrance")
        mappings = parse_ingredient_list("Water, Vitamin B3")
        self.assertEqual(mappings[1]["raw_name"], "Vitamin B3")
        self.assertEqual(mappings[1]["normalized_name"], "niacinamide")

    def test_derived_semantics_are_not_marked_factual(self):
        normalized = normalize_product({
            "product_name_raw": "Acne Serum",
            "brand_raw": "Example",
            "category_raw": "serum",
            "price_raw": "10",
            "currency_raw": "USD",
            "product_url": "https://example.com/p",
            "skin_concerns_raw": "acne",
            "source_type": "official_brand",
            "crawled_at": "2026-01-01T00:00:00Z",
            "extra_attributes": {
                "semantic_extraction": {
                    "skin_concerns_raw": {"method": "explicit_phrase_mapping"}
                }
            },
        })
        provenance = normalized["_processing"]["field_provenance"]["skin_concerns"]
        self.assertEqual(provenance["data_class"], "DERIVED")
        self.assertEqual(provenance["evidence_type"], "inferred")
        self.assertIsNone(provenance["last_verified_at"])


if __name__ == "__main__":
    unittest.main()
