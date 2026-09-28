from __future__ import annotations

import csv
import tempfile
import unittest
from pathlib import Path

from data_pipeline.crawler.brands.configs import BRAND_CONFIGS
from data_pipeline.crawler.brands.generic_official import parse_official_product_html
from data_pipeline.exporter.csv_exporter import write_csv
from data_pipeline.wave1 import ALL_REVIEWED_BRANDS, WAVE2_BRANDS


HTML = '''<!doctype html><html><head>
<meta property="og:image" content="/images/p.jpg">
<script type="application/ld+json">{"@type":"Product","name":"Test Serum","sku":"SKU-1","description":"Hydrating serum","image":"/images/p.jpg","offers":{"price":"19.90","priceCurrency":"USD","availability":"https://schema.org/InStock"}}</script>
</head><body><h1>Test Serum</h1>
<h2>Ingredients</h2><div><p>Water, Glycerin, Niacinamide</p></div>
<h2>Key Ingredients</h2><div><p>Niacinamide</p></div>
<h2>How to Use</h2><div><p>Apply once daily.</p></div>
<h2>Skin Type</h2><div><p>Normal to Dry Skin; Sensitive Skin</p></div>
<p>30ml</p></body></html>'''


class Wave1ExtensionTests(unittest.TestCase):
    def test_wave2_brands_are_configured(self):
        self.assertGreaterEqual(len(WAVE2_BRANDS), 5)
        self.assertGreaterEqual(len(ALL_REVIEWED_BRANDS), 10)
        for brand in WAVE2_BRANDS:
            self.assertIn(brand, BRAND_CONFIGS)
            self.assertTrue(BRAND_CONFIGS[brand].listing_urls)
            self.assertTrue(BRAND_CONFIGS[brand].product_path_patterns)

    def test_generic_official_parser_preserves_source_fields(self):
        config = BRAND_CONFIGS['the-ordinary']
        row = parse_official_product_html(config, 'https://theordinary.com/en-us/test-serum-100001.html', HTML)
        self.assertEqual(row['product_name_raw'], 'Test Serum')
        self.assertEqual(row['sku_raw'], 'SKU-1')
        self.assertEqual(row['currency_raw'], 'USD')
        self.assertEqual(row['volume_raw'], '30ml')
        self.assertIn('Water', row['ingredients_raw'])
        self.assertEqual(row['source_type'], 'official_brand')

    def test_csv_export(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / 'products.csv'
            write_csv(path, [{'name':'A','skin_types':['dry','sensitive'],'_processing':{'quality_score':90,'ai_ready':True}}])
            with path.open('r', encoding='utf-8-sig', newline='') as fh:
                rows = list(csv.DictReader(fh))
            self.assertEqual(rows[0]['name'], 'A')
            self.assertIn('dry', rows[0]['skin_types'])
            self.assertEqual(rows[0]['_processing.quality_score'], '90')


if __name__ == '__main__':
    unittest.main()
