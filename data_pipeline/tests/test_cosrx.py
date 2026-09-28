from __future__ import annotations

import unittest
from pathlib import Path

from data_pipeline.crawler.brands.cosrx import parse_cosrx_product_html


class CosrxParserTests(unittest.TestCase):
    def test_detail_parser_preserves_source_values(self):
        fixture = Path(__file__).parent / "fixtures" / "cosrx" / "product_detail.html"
        record = parse_cosrx_product_html(
            "https://www.cosrx.com/products/advanced-snail-96-mucin-power-essence",
            fixture.read_text(encoding="utf-8"),
            category_hint="serum",
            concern_hints=["dryness", "dullness"],
        )
        self.assertEqual(record["product_name_raw"], "Advanced Snail 96 Mucin Power Essence")
        self.assertEqual(record["price_raw"], "25.00")
        self.assertEqual(record["currency_raw"], "USD")
        self.assertEqual(record["volume_raw"].lower(), "100ml")
        self.assertIn("Snail Secretion Filtrate", record["ingredients_raw"])
        self.assertIn("sensitive", record["skin_types_raw"])
        self.assertEqual(record["category_raw"], "serum")
        self.assertEqual(record["skin_concerns_raw"], "dryness;dullness")


if __name__ == "__main__":
    unittest.main()
