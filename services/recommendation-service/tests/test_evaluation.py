import unittest

from recommendation_service.evaluation import (
    catalog_coverage,
    hit_rate_at_k,
    intra_list_diversity,
    precision_at_k,
    recall_at_k,
)
from recommendation_service.models import Product


class EvaluationMetricTests(unittest.TestCase):
    def test_precision_at_k(self):
        self.assertAlmostEqual(precision_at_k([1, 2, 3], {1, 3}, 3), 2 / 3)

    def test_recall_at_k(self):
        self.assertAlmostEqual(recall_at_k([1, 2, 3], {1, 3, 4, 5}, 3), 0.5)

    def test_hit_rate_at_k(self):
        self.assertEqual(hit_rate_at_k([1, 2], {3}, 2), 0.0)
        self.assertEqual(hit_rate_at_k([1, 2], {2}, 2), 1.0)

    def test_catalog_coverage(self):
        self.assertAlmostEqual(catalog_coverage([[1, 2], [2, 3]], 6), 0.5)

    def test_intra_list_diversity(self):
        products = {
            1: Product(1, "A", "A", "B1", "serum", 10, skin_types=("dry",)),
            2: Product(2, "B", "B", "B2", "cleanser", 10, skin_types=("oily",)),
        }
        self.assertAlmostEqual(intra_list_diversity([[1, 2]], products), 1.0)

    def test_empty_ground_truth_does_not_claim_recall(self):
        self.assertEqual(recall_at_k([1], set(), 5), 0.0)

    def test_non_positive_k_is_rejected(self):
        with self.assertRaises(ValueError):
            precision_at_k([1], {1}, 0)


if __name__ == "__main__":
    unittest.main()
