from __future__ import annotations

import csv
import json
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterable


def _cell(value: Any) -> str | int | float | None:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return format(value, 'f')
    if isinstance(value, (list, dict, tuple, set)):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    return value


def _flatten(record: dict[str, Any]) -> dict[str, Any]:
    row: dict[str, Any] = {}
    for key, value in record.items():
        if key == '_processing' and isinstance(value, dict):
            for meta_key in (
                'production_candidate', 'ai_ready', 'db_ready', 'quality_score',
                'validation_errors', 'validation_warnings', 'missing_fields',
                'rejection_reasons', 'unmapped_values', 'source_currency',
                'retrieved_at', 'last_verified_at', 'verified_at_candidate', 'pipeline_version',
            ):
                if meta_key in value:
                    row[f'_processing.{meta_key}'] = _cell(value.get(meta_key))
        else:
            row[key] = _cell(value)
    return row


def write_csv(path: Path, records: Iterable[dict[str, Any]]) -> None:
    rows = [_flatten(r) for r in records if isinstance(r, dict)]
    path.parent.mkdir(parents=True, exist_ok=True)
    preferred = [
        'sku', 'name', 'product_name_raw', 'brand_normalized', 'brand_raw',
        'category_normalized', 'category_raw', 'price', 'currency', 'price_raw', 'currency_raw',
        'volume', 'volume_raw', 'description', 'benefits', 'inci_ingredients',
        'key_ingredients', 'skin_types', 'skin_concerns', 'care_goals', 'texture',
        'usage_instruction', 'warnings', 'image_url', 'image_urls_raw', 'source_url',
        'product_url', 'source_name', 'source_type', 'crawled_at', 'verified_at',
        '_processing.quality_score', '_processing.production_candidate',
        '_processing.ai_ready', '_processing.db_ready',
        '_processing.validation_errors', '_processing.validation_warnings',
        '_processing.rejection_reasons', '_processing.missing_fields',
        '_processing.unmapped_values', '_processing.source_currency',
    ]
    keys = set().union(*(row.keys() for row in rows)) if rows else set()
    fieldnames = [k for k in preferred if k in keys]
    fieldnames.extend(sorted(keys - set(fieldnames)))
    with path.open('w', encoding='utf-8-sig', newline='') as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
