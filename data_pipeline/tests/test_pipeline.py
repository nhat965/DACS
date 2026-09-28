from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from data_pipeline.importer.contract_guard import whitelist_production_payload
from data_pipeline.importer.mysql_importer import _build_payload, _sync_product_metadata
from data_pipeline.normalizer.product_normalizer import normalize_price, normalize_volume
from data_pipeline.pipeline import process_brand


class PipelineTests(unittest.TestCase):
    def test_price_and_volume_normalization(self):
        self.assertEqual(float(normalize_price("350.000 ₫")), 350000.0)
        self.assertEqual(normalize_volume("Net 30 ml"), "30ml")

    def test_end_to_end_quality_gate_and_duplicate(self):
        fixture = Path(__file__).parent / "fixtures" / "sample_raw_products.json"
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            raw_dir = root / "datasets" / "raw" / "example-brand"
            raw_dir.mkdir(parents=True)
            (raw_dir / "products.json").write_text(fixture.read_text(encoding="utf-8"), encoding="utf-8")

            report = process_brand(root, "example-brand")
            self.assertEqual(report["raw_records"], 3)
            self.assertEqual(report["duplicate_records"], 1)
            self.assertEqual(report["ai_ready_records"], 1)

            processed = json.loads((root / "datasets" / "processed" / "example-brand" / "products.json").read_text(encoding="utf-8"))
            self.assertEqual(len(processed), 2)
            self.assertTrue(processed[0]["_processing"]["ai_ready"])
            self.assertEqual(processed[0]["_processing"]["merged_source_count"], 2)
            self.assertIn("mystery lotion", processed[1]["_processing"]["unmapped_values"]["category"])

    def test_import_whitelist_drops_processing_metadata(self):
        payload = whitelist_production_payload({"name": "x", "_processing": {"quality_score": 99}, "raw_extra": "x"})
        self.assertNotIn("_processing", payload)
        self.assertNotIn("raw_extra", payload)

    def test_mysql_payload_persists_ai_ready_gate(self):
        record = {
            "sku": "SKU-1",
            "name": "Serum",
            "brand_normalized": "Example",
            "category_normalized": "serum",
            "price": 10,
            "currency": "USD",
            "_processing": {"production_candidate": True, "ai_ready": False},
        }

        payload, errors = _build_payload(record, {"example": 1}, {"serum": 2})

        self.assertEqual(errors, [])
        self.assertFalse(payload["ai_ready"])

    def test_import_mysql_dry_run_does_not_apply_schema(self):
        from data_pipeline.cli import main

        argv = ["data-pipeline", "import-mysql", "--repo-root", ".", "--dry-run"]
        with (
            patch.object(sys, "argv", argv),
            patch("data_pipeline.cli.ensure_database_schema") as ensure_schema,
            patch("data_pipeline.cli._load_processed", return_value=[]),
            patch("data_pipeline.cli.import_records", return_value={"dry_run": True}),
            patch("builtins.print"),
        ):
            exit_code = main()

        self.assertEqual(exit_code, 0)
        ensure_schema.assert_not_called()

    def test_metadata_sync_skips_oversized_ingredient_mapping(self):
        class Cursor:
            def __init__(self):
                self.queries = []

            def execute(self, query, params=None):
                self.queries.append((query, params))

        cursor = Cursor()
        record = {
            "_processing": {
                "ingredient_mappings": [
                    {
                        "inci_name": "x" * 256,
                        "normalized_name": "oversized",
                        "raw_name": "raw",
                    }
                ]
            }
        }

        _sync_product_metadata(cursor, 1, record)

        self.assertEqual(len(cursor.queries), 1)
        self.assertIn("DELETE FROM product_ingredients", cursor.queries[0][0])


if __name__ == "__main__":
    unittest.main()
