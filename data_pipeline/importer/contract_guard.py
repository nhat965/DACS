from __future__ import annotations

from typing import Any

from data_pipeline.config.contracts import PRODUCT_STATUSES, PRODUCTION_IMPORT_REQUIRED, PRODUCTION_PRODUCT_FIELDS


def whitelist_production_payload(record: dict[str, Any]) -> dict[str, Any]:
    """Drop every processing/raw field before DB import."""
    return {field: record.get(field) for field in PRODUCTION_PRODUCT_FIELDS}


def validate_import_payload(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    extra = set(payload) - set(PRODUCTION_PRODUCT_FIELDS)
    if extra:
        errors.append(f"unexpected_fields:{','.join(sorted(extra))}")
    for field in PRODUCTION_IMPORT_REQUIRED:
        if payload.get(field) is None:
            errors.append(f"missing_required:{field}")
    if payload.get("status") is not None and payload["status"] not in PRODUCT_STATUSES:
        errors.append("invalid_enum:status")
    return errors
