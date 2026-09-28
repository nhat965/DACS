from __future__ import annotations

import ast
import csv
import json
import re
from pathlib import Path
from typing import Iterable

from .models import Product


DEFAULT_CATALOG_PATH = (
    Path(__file__).resolve().parents[3]
    / "datasets"
    / "product-catalog"
    / "all_brands_ai_ready_products.csv"
)


class CatalogRepository:
    """Loads the AI-ready product catalog without requiring a database."""

    def __init__(self, products: Iterable[Product]):
        self.products = tuple(products)
        self._by_id = {product.product_id: product for product in self.products}

    @classmethod
    def from_csv(cls, path: str | Path = DEFAULT_CATALOG_PATH) -> "CatalogRepository":
        catalog_path = Path(path)
        with catalog_path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))

        return cls(_row_to_product(index + 1, row) for index, row in enumerate(rows))

    def get(self, product_id: int) -> Product | None:
        return self._by_id.get(product_id)

    def all(self) -> tuple[Product, ...]:
        return self.products


def _row_to_product(row_number: int, row: dict[str, str]) -> Product:
    product_id = _parse_product_id(row, row_number)
    return Product(
        product_id=product_id,
        sku=_first(row, "sku", "id") or str(product_id),
        name=_first(row, "name", "product_name"),
        brand=_resolve_brand(row),
        category=_resolve_category(row),
        price=_parse_price(_first(row, "price")),
        currency=_first(row, "currency", "_processing.source_currency") or None,
        description=_first(row, "description"),
        benefits=_first(row, "benefits"),
        inci_ingredients=_first(row, "inci_ingredients", "inciIngredients"),
        key_ingredients=_first(row, "key_ingredients", "keyIngredients"),
        skin_types=_parse_terms(_first(row, "skin_types", "skinTypes")),
        skin_concerns=_parse_terms(_first(row, "skin_concerns", "skinConcerns")),
        care_goals=_parse_terms(_first(row, "care_goals", "careGoals")),
        texture=_first(row, "texture"),
        image_url=_first(row, "image_url", "imageUrl"),
        source_url=_first(row, "source_url", "sourceUrl"),
        usage_instruction=_first(row, "usage_instruction", "usageInstruction"),
        warnings=_first(row, "warnings"),
    )


def _first(row: dict[str, str], *keys: str) -> str:
    for key in keys:
        value = row.get(key)
        if value not in (None, ""):
            return str(value).strip()
    return ""


def _parse_price(value: str) -> float | None:
    if not value:
        return None
    try:
        return float(str(value).replace(",", "").strip())
    except ValueError:
        return None


def _parse_product_id(row: dict[str, str], fallback: int) -> int:
    for key in ("id", "product_id", "productId", "sku"):
        value = _first(row, key)
        if not value:
            continue
        try:
            return int(value)
        except ValueError:
            continue
    return fallback


def _parse_terms(value: str) -> tuple[str, ...]:
    if not value:
        return ()

    parsed: object = value
    stripped = value.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        for loader in (json.loads, ast.literal_eval):
            try:
                parsed = loader(stripped)
                break
            except (ValueError, SyntaxError, json.JSONDecodeError):
                parsed = value

    if isinstance(parsed, (list, tuple, set)):
        raw_terms = parsed
    else:
        raw_terms = re.split(r"[,;|]", str(parsed))

    return tuple(
        term.strip().lower()
        for term in raw_terms
        if str(term).strip()
    )


def _resolve_brand(row: dict[str, str]) -> str:
    brand = _first(row, "brand_normalized", "brand", "brandName")
    if brand:
        return brand
    brand_id = _first(row, "brand_id", "brandId")
    return f"brand_{brand_id}" if brand_id else ""


def _resolve_category(row: dict[str, str]) -> str:
    category = _first(row, "category_normalized", "category", "categoryName")
    if category:
        return category
    category_id = _first(row, "category_id", "categoryId")
    return f"category_{category_id}" if category_id else ""
