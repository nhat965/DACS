from __future__ import annotations

from collections import Counter, defaultdict
from typing import Any

from data_pipeline.config.contracts import FIELD_CLASSIFICATION


QUALITY_REPORT_FIELDS = tuple(
    dict.fromkeys(
        field
        for group in ("required", "recommended", "optional")
        for field in FIELD_CLASSIFICATION[group]
    )
)


def _present(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, tuple, dict, set)):
        return bool(value)
    return True


def build_quality_report(processed: list[dict[str, Any]], duplicate_count: int = 0) -> dict[str, Any]:
    missing = Counter()
    validation_errors = Counter()
    validation_warnings = Counter()
    scores: list[int] = []
    core_scores: list[int] = []
    ai_ready = 0
    production_candidate = 0
    rejection_reasons = Counter()
    by_brand: dict[str, Counter] = defaultdict(Counter)

    for record in processed:
        meta = record.get("_processing", {})
        scores.append(int(meta.get("quality_score", 0)))
        core_scores.append(int(meta.get("core_knowledge_score", 0)))
        ai_ready += int(bool(meta.get("ai_ready")))
        production_candidate += int(bool(meta.get("production_candidate")))
        for field in QUALITY_REPORT_FIELDS:
            if not _present(record.get(field)):
                missing[field] += 1
        validation_errors.update(meta.get("validation_errors", []))
        validation_warnings.update(meta.get("validation_warnings", []))
        rejection_reasons.update(meta.get("rejection_reasons", []))
        brand = str(record.get("_brand_slug") or record.get("brand_normalized") or "<missing>")
        by_brand[brand]["total_records"] += 1
        by_brand[brand]["valid_records"] += int(bool(meta.get("production_candidate")))
        by_brand[brand]["invalid_records"] += int(not bool(meta.get("production_candidate")))
        by_brand[brand]["ai_ready_count"] += int(bool(meta.get("ai_ready")))
        for field in QUALITY_REPORT_FIELDS:
            if not _present(record.get(field)):
                by_brand[brand][f"missing::{field}"] += 1

    total = len(processed)
    return {
        "total_records": total,
        "total_processed": total,
        "valid_records": production_candidate,
        "invalid_records": total - production_candidate,
        "production_candidate_count": production_candidate,
        "production_candidates": production_candidate,
        "ai_ready_count": ai_ready,
        "ai_ready": ai_ready,
        "duplicate_count": duplicate_count,
        "ai_ready_rate": round(ai_ready / total, 4) if total else 0,
        "average_quality_score": round(sum(scores) / total, 2) if total else 0,
        "average_core_knowledge_score": round(sum(core_scores) / total, 2) if total else 0,
        "missing_rate_by_field": {
            field: round(missing[field] / total, 4) if total else 0
            for field in QUALITY_REPORT_FIELDS
        },
        "missing_percentage_by_field": {
            field: round((missing[field] / total) * 100, 2) if total else 0
            for field in QUALITY_REPORT_FIELDS
        },
        "validation_errors": dict(validation_errors),
        "validation_warnings": dict(validation_warnings),
        "rejection_reasons": dict(rejection_reasons),
        "field_classification": FIELD_CLASSIFICATION,
        "statistics_by_brand": {
            brand: {
                **{
                    key: value for key, value in counts.items()
                    if not key.startswith("missing::")
                },
                "missing_percentage_by_field": {
                    field: round(counts[f"missing::{field}"] / counts["total_records"] * 100, 2)
                    if counts["total_records"] else 0
                    for field in QUALITY_REPORT_FIELDS
                },
            }
            for brand, counts in sorted(by_brand.items())
        },
    }


def collect_unmapped_values(processed: list[dict[str, Any]]) -> dict[str, list[str]]:
    values: dict[str, set[str]] = defaultdict(set)
    for record in processed:
        for field, items in record.get("_processing", {}).get("unmapped_values", {}).items():
            for item in items or []:
                if item is not None:
                    values[field].add(str(item))
    return {field: sorted(items) for field, items in sorted(values.items())}
