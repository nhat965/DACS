from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from data_pipeline.config.version import PIPELINE_VERSION
from data_pipeline.config.contracts import (
    AI_FIELD_WEIGHTS,
    AI_READY_SCORE_THRESHOLD,
    AI_SEMANTIC_MINIMUM_GROUPS,
    CARE_GOALS,
    CATEGORY_CODES,
    CORE_PRODUCT_KNOWLEDGE_FIELDS,
    SKIN_CONCERNS,
    SKIN_TYPES,
)


def _present(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, tuple, dict, set)):
        return bool(value)
    return True


def _all_allowed(values: Any, allowed: set[str] | frozenset[str]) -> bool:
    if values is None:
        return True
    return isinstance(values, list) and all(v in allowed for v in values)


def validate_processed(record: dict[str, Any]) -> dict[str, Any]:
    meta = record.setdefault("_processing", {})
    errors: list[str] = []
    warnings: list[str] = []

    if not _present(record.get("name")):
        errors.append("MISSING_NAME")
    if not _present(record.get("brand_normalized")):
        errors.append("MISSING_BRAND")
    if not _present(record.get("category_normalized")):
        errors.append("MISSING_CATEGORY")
    if not _present(record.get("sku")):
        errors.append("MISSING_SKU")

    if record.get("category_normalized") is not None and record["category_normalized"] not in CATEGORY_CODES:
        errors.append("MALFORMED_PRODUCT")
    if not _all_allowed(record.get("skin_types"), SKIN_TYPES):
        errors.append("MALFORMED_PRODUCT")
    if not _all_allowed(record.get("skin_concerns"), SKIN_CONCERNS):
        errors.append("MALFORMED_PRODUCT")
    if not _all_allowed(record.get("care_goals"), CARE_GOALS):
        errors.append("MALFORMED_PRODUCT")

    price = record.get("price")
    if price is None or not isinstance(price, Decimal) or price <= 0:
        errors.append("INVALID_PRICE")
    currency = record.get("currency")
    if not isinstance(currency, str) or len(currency) != 3 or not currency.isalpha() or currency != currency.upper():
        errors.append("INVALID_CURRENCY")
    if record.get("source_url") is None:
        errors.append("INVALID_SOURCE")
    if record.get("image_url") is None:
        warnings.append("missing:image_url")

    unmapped = meta.get("unmapped_values", {})
    for field, values in unmapped.items():
        if values:
            warnings.append(f"unmapped:{field}")

    if meta.get("is_duplicate"):
        errors.append("DUPLICATE_PRODUCT")

    missing_ai_fields = [field for field in AI_FIELD_WEIGHTS if not _present(record.get(field))]
    missing_reasons: dict[str, str] = {}
    unmapped_fields = {field for field, values in unmapped.items() if values}
    for field in missing_ai_fields:
        # Missing semantic enum output can be caused by an explicit but unmappable raw value.
        if field in unmapped_fields:
            missing_reasons[field] = "unmapped_raw_value"
        else:
            missing_reasons[field] = "source_missing_or_not_extracted"
    max_score = sum(AI_FIELD_WEIGHTS.values())
    gained = sum(weight for field, weight in AI_FIELD_WEIGHTS.items() if _present(record.get(field)))
    score = round((gained / max_score) * 100) if max_score else 0

    semantic_groups_ok = all(any(_present(record.get(f)) for f in group) for group in AI_SEMANTIC_MINIMUM_GROUPS)
    ai_ready = not errors and semantic_groups_ok and score >= AI_READY_SCORE_THRESHOLD
    production_candidate = not errors
    rejection_reasons = list(dict.fromkeys(errors))
    if production_candidate and not ai_ready:
        rejection_reasons.append("INSUFFICIENT_AI_FEATURES")

    core_present = [f for f in CORE_PRODUCT_KNOWLEDGE_FIELDS if _present(record.get(f))]
    core_missing = [f for f in CORE_PRODUCT_KNOWLEDGE_FIELDS if not _present(record.get(f))]
    core_score = round((len(core_present) / len(CORE_PRODUCT_KNOWLEDGE_FIELDS)) * 100) if CORE_PRODUCT_KNOWLEDGE_FIELDS else 0

    meta.update({
        "production_candidate": production_candidate,
        "ai_ready": ai_ready,
        "quality_score": score,
        "core_knowledge_score": core_score,
        "core_knowledge_present": core_present,
        "core_knowledge_missing": core_missing,
        "missing_fields": missing_ai_fields,
        "missing_reasons": missing_reasons,
        "validation_errors": errors,
        "rejection_reasons": rejection_reasons,
        "validation_warnings": warnings,
        # Validation is not source verification. Only preserve a timestamp produced
        # by an explicit verification workflow.
        "verified_at_candidate": meta.get("last_verified_at") if production_candidate else None,
        "pipeline_version": PIPELINE_VERSION,
        "processed_at": datetime.now(timezone.utc).isoformat(),
    })
    return record
