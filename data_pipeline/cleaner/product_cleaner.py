from __future__ import annotations

from copy import deepcopy
from typing import Any

from data_pipeline.common.text import clean_text

# Raw fields we clean conservatively. Raw input is never overwritten on disk;
# this cleaner operates on an in-memory copy used to produce processed data.
_TEXT_FIELDS = {
    "product_name_raw",
    "sku_raw",
    "brand_raw",
    "category_raw",
    "subcategory_raw",
    "price_raw",
    "sale_price_raw",
    "volume_raw",
    "description_raw",
    "benefits_raw",
    "ingredients_raw",
    "key_ingredients_raw",
    "skin_types_raw",
    "skin_concerns_raw",
    "care_goals_raw",
    "texture_raw",
    "usage_raw",
    "warnings_raw",
    "availability_raw",
    "product_url",
    "source_name",
    "source_type",
}


def clean_raw_record(record: dict[str, Any]) -> dict[str, Any]:
    out = deepcopy(record)
    for key in _TEXT_FIELDS:
        if key in out and not isinstance(out[key], (list, dict)):
            out[key] = clean_text(out[key])
    if isinstance(out.get("image_urls_raw"), list):
        out["image_urls_raw"] = [u for u in (clean_text(x) for x in out["image_urls_raw"]) if u]
    return out
