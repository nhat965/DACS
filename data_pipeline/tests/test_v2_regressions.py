from __future__ import annotations

import unittest

from data_pipeline.parser.source_enrichment import enrich_raw_record
from data_pipeline.deduplicator.product_deduplicator import merge_duplicates


class V2RegressionTests(unittest.TestCase):
    def test_embedded_ingredient_sections_are_recovered(self):
        raw = {
            'description_raw': 'Hydrating serum for dry skin. How to use: Apply nightly. INGREDIENTS Water, Glycerin',
            'ingredients_raw': 'KEY INGREDIENTS • Glycerin: hydrates Full Ingredients × Full Ingredients Water, Glycerin, Panthenol',
        }
        out = enrich_raw_record(raw)
        self.assertIn('Glycerin', out['key_ingredients_raw'])
        self.assertEqual(out['ingredients_raw'], 'Water, Glycerin, Panthenol')
        self.assertIn('dry', out['skin_types_raw'])
        self.assertIn('hydrate', out['care_goals_raw'])

    def test_benefits_are_extracted_from_source_claim_sentences_without_copying_full_description(self):
        raw = {
            'description_raw': (
                'A lightweight daily gel moisturizer formulated for sensitive skin. '
                'It helps soothe visible redness and provides lasting hydration without heaviness. '
                'Size: 50ml'
            )
        }
        out = enrich_raw_record(raw)
        self.assertIsNotNone(out.get('benefits_raw'))
        self.assertIn('helps soothe visible redness', out['benefits_raw'])
        self.assertIn('provides lasting hydration', out['benefits_raw'])
        self.assertNotEqual(out['benefits_raw'], raw['description_raw'])
        self.assertIn('hydrate', out.get('care_goals_raw', ''))
        self.assertIn('soothe', out.get('care_goals_raw', ''))
        self.assertEqual(
            out['extra_attributes']['semantic_extraction']['benefits_raw']['method'],
            'source_claim_sentences',
        )

    def test_cautions_are_split_from_usage_and_preserved_as_warnings(self):
        raw = {
            'usage_raw': 'Apply once daily. Cautions: For external use only. Avoid direct contact with eyes.'
        }
        out = enrich_raw_record(raw)
        self.assertEqual(out['usage_raw'], 'Apply once daily.')
        self.assertIn('For external use only', out['warnings_raw'])

    def test_duplicates_merge_complementary_fields(self):
        items = [
            {'raw': {}, 'processed': {'sku':'A1','name':'X','brand_normalized':'B','category_normalized':None,'volume':'30ml','source_url':'https://x/collections/acne/products/x','inci_ingredients':'Water','skin_types':['dry'],'_processing':{'unmapped_values':{}}}},
            {'raw': {}, 'processed': {'sku':'A1','name':'X','brand_normalized':'B','category_normalized':'serum','volume':'30ml','source_url':'https://x/products/x','benefits':'Hydrates skin','skin_types':['sensitive'],'_processing':{'unmapped_values':{}}}},
        ]
        merged, report = merge_duplicates(items)
        self.assertEqual(len(merged), 1)
        self.assertEqual(len(report), 1)
        p = merged[0]['processed']
        self.assertEqual(p['category_normalized'], 'serum')
        self.assertEqual(p['source_url'], 'https://x/products/x')
        self.assertEqual(p['skin_types'], ['dry','sensitive'])
        self.assertEqual(p['_processing']['merged_source_count'], 2)


if __name__ == '__main__':
    unittest.main()
