from __future__ import annotations

import csv
import json
from itertools import combinations
from pathlib import Path
from typing import Any, Iterable

from .catalog import CatalogRepository
from .engine import RecommendationEngine
from .models import Product, RecommendationContext, RecommendationRequest


EVALUATION_NOTE = (
    "This is an offline expert/developer-defined evaluation set, "
    "not production user ground truth."
)


def precision_at_k(recommended: Iterable[int], relevant: set[int], k: int) -> float:
    if k <= 0:
        raise ValueError("k must be positive")
    top_k = list(recommended)[:k]
    return len(set(top_k) & relevant) / k


def recall_at_k(recommended: Iterable[int], relevant: set[int], k: int) -> float:
    if k <= 0:
        raise ValueError("k must be positive")
    if not relevant:
        return 0.0
    return len(set(list(recommended)[:k]) & relevant) / len(relevant)


def hit_rate_at_k(recommended: Iterable[int], relevant: set[int], k: int) -> float:
    if k <= 0:
        raise ValueError("k must be positive")
    return float(bool(set(list(recommended)[:k]) & relevant))


def catalog_coverage(recommendation_lists: Iterable[Iterable[int]], catalog_size: int) -> float:
    if catalog_size <= 0:
        return 0.0
    recommended = {product_id for items in recommendation_lists for product_id in items}
    return len(recommended) / catalog_size


def intra_list_diversity(
    recommendation_lists: Iterable[Iterable[int]],
    products_by_id: dict[int, Product],
) -> float:
    list_scores: list[float] = []
    for items in recommendation_lists:
        products = [products_by_id[item] for item in items if item in products_by_id]
        pairs = list(combinations(products, 2))
        if not pairs:
            list_scores.append(0.0)
            continue
        distances = [1.0 - _jaccard(_features(left), _features(right)) for left, right in pairs]
        list_scores.append(sum(distances) / len(distances))
    return sum(list_scores) / len(list_scores) if list_scores else 0.0


def evaluate_fixture(
    engine: RecommendationEngine,
    catalog: CatalogRepository,
    cases: list[dict[str, Any]],
    top_k: int = 5,
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    recommendation_lists: list[list[int]] = []
    for index, case in enumerate(cases, start=1):
        profile = case.get("profile") or {}
        context = RecommendationContext(
            skin_type=profile.get("skin_type"),
            skin_concerns=tuple(profile.get("concerns") or []),
            care_goals=tuple(profile.get("care_goals") or []),
            avoid_ingredients=tuple(profile.get("avoid_ingredients") or []),
            budget_min=profile.get("budget_min"),
            budget_max=profile.get("budget_max"),
            budget_currency=profile.get("budget_currency"),
            preferred_categories=tuple(profile.get("preferred_categories") or []),
            preferred_brands=tuple(profile.get("preferred_brands") or []),
        )
        response = engine.recommend(RecommendationRequest(context=context, limit=top_k))
        recommended = [item.product_id for item in response.items]
        relevant = {int(item) for item in case.get("relevant_product_ids") or []}
        recommendation_lists.append(recommended)
        rows.append({
            "case_id": case.get("id") or f"case-{index}",
            "recommended_product_ids": recommended,
            "relevant_product_ids": sorted(relevant),
            "precision_at_1": precision_at_k(recommended, relevant, 1),
            "precision_at_3": precision_at_k(recommended, relevant, 3),
            "precision_at_5": precision_at_k(recommended, relevant, 5),
            "recall_at_5": recall_at_k(recommended, relevant, 5),
            "hit_rate_at_5": hit_rate_at_k(recommended, relevant, 5),
        })

    def mean(field: str) -> float:
        return sum(float(row[field]) for row in rows) / len(rows) if rows else 0.0

    summary = {
        "precision_at_1": mean("precision_at_1"),
        "precision_at_3": mean("precision_at_3"),
        "precision_at_5": mean("precision_at_5"),
        "recall_at_5": mean("recall_at_5"),
        "hit_rate_at_5": mean("hit_rate_at_5"),
        "catalog_coverage": catalog_coverage(recommendation_lists, len(catalog.all())),
        "intra_list_diversity": intra_list_diversity(
            recommendation_lists, {product.product_id: product for product in catalog.all()}
        ),
    }
    return {"note": EVALUATION_NOTE, "case_count": len(rows), "summary": summary, "cases": rows}


def export_evaluation_report(report: dict[str, Any], json_path: Path, csv_path: Path) -> None:
    json_path.parent.mkdir(parents=True, exist_ok=True)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    fieldnames = [
        "case_id", "recommended_product_ids", "relevant_product_ids",
        "precision_at_1", "precision_at_3", "precision_at_5", "recall_at_5", "hit_rate_at_5",
    ]
    with csv_path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in report.get("cases", []):
            writer.writerow({
                **row,
                "recommended_product_ids": json.dumps(row["recommended_product_ids"]),
                "relevant_product_ids": json.dumps(row["relevant_product_ids"]),
            })


def load_fixture(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get("cases"), list):
        raise ValueError("Evaluation fixture must be an object containing a cases array")
    return payload["cases"]


def _features(product: Product) -> set[str]:
    features = {
        f"brand:{product.brand.casefold()}",
        f"category:{product.category.casefold()}",
    }
    for prefix, values in (
        ("skin", product.skin_types),
        ("concern", product.skin_concerns),
        ("goal", product.care_goals),
    ):
        features.update(f"{prefix}:{value.casefold()}" for value in values)
    return {feature for feature in features if not feature.endswith(":")}


def _jaccard(left: set[str], right: set[str]) -> float:
    if not left and not right:
        return 1.0
    return len(left & right) / len(left | right)
