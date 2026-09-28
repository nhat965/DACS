from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path
from typing import Any

from data_pipeline.cleaner.product_cleaner import clean_raw_record
from data_pipeline.parser.source_enrichment import enrich_raw_record
from data_pipeline.deduplicator.product_deduplicator import merge_duplicates
from data_pipeline.exporter.json_exporter import write_json
from data_pipeline.exporter.csv_exporter import write_csv
from data_pipeline.exporter.reports import build_quality_report, collect_unmapped_values
from data_pipeline.normalizer.product_normalizer import normalize_product
from data_pipeline.validator.product_validator import validate_processed


def load_raw_products(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    if isinstance(payload, dict) and isinstance(payload.get("products"), list):
        payload = payload["products"]
    if not isinstance(payload, list):
        raise ValueError("Raw products file must be a JSON array or {'products': [...]} object")
    return payload


def process_brand(repo_root: Path, brand_slug: str) -> dict[str, Any]:
    raw_path = repo_root / "datasets" / "raw" / brand_slug / "products.json"
    if not raw_path.exists():
        raise FileNotFoundError(f"Raw dataset not found: {raw_path}")

    raw_records = load_raw_products(raw_path)
    working: list[dict[str, Any]] = []
    for raw in raw_records:
        enriched = enrich_raw_record(raw, repo_root)
        cleaned = clean_raw_record(enriched)
        processed = normalize_product(cleaned)
        working.append({"raw": raw, "processed": processed})

    working, duplicate_report = merge_duplicates(working)
    processed_records = [validate_processed(item["processed"]) for item in working]

    # Product catalog is the validated production-ready set. AI readiness is a
    # separate gate used by recommendation/RAG, not a prerequisite for website/DB rows.
    catalog = []
    ai_catalog = []
    for record in processed_records:
        meta = record.get("_processing", {})
        if meta.get("production_candidate"):
            item = deepcopy(record)
            item["verified_at"] = meta.get("verified_at_candidate")
            catalog.append(item)
        if meta.get("ai_ready"):
            item = deepcopy(record)
            item["verified_at"] = meta.get("verified_at_candidate")
            ai_catalog.append(item)

    processed_path = repo_root / "datasets" / "processed" / brand_slug / "products.json"
    catalog_path = repo_root / "datasets" / "product-catalog" / brand_slug / "products.json"
    reports_dir = repo_root / "datasets" / "reports"

    write_json(processed_path, processed_records)
    write_csv(processed_path.with_suffix(".csv"), processed_records)
    write_json(catalog_path, catalog)
    write_csv(catalog_path.with_suffix(".csv"), catalog)
    write_json(catalog_path.parent / "ai_ready_products.json", ai_catalog)
    write_csv(catalog_path.parent / "ai_ready_products.csv", ai_catalog)
    write_json(
        reports_dir / f"{brand_slug}_quality_report.json",
        build_quality_report(processed_records, duplicate_count=len(duplicate_report)),
    )
    write_json(reports_dir / f"{brand_slug}_duplicate_report.json", duplicate_report)
    write_json(reports_dir / f"{brand_slug}_unmapped_values.json", collect_unmapped_values(processed_records))

    error_records = [
        {
            "source_url": r.get("source_url"),
            "name": r.get("name"),
            "errors": r.get("_processing", {}).get("validation_errors", []),
            "rejection_reasons": r.get("_processing", {}).get("rejection_reasons", []),
        }
        for r in processed_records
        if r.get("_processing", {}).get("validation_errors")
    ]
    write_json(reports_dir / f"{brand_slug}_error_report.json", error_records)

    crawl_report = {
        "brand": brand_slug,
        "raw_records": len(raw_records),
        "processed_records": len(processed_records),
        "duplicate_records": len(duplicate_report),
        "production_candidates": sum(bool(r.get("_processing", {}).get("production_candidate")) for r in processed_records),
        "ai_ready_records": len(ai_catalog),
        "invalid_records": len(processed_records) - sum(
            bool(r.get("_processing", {}).get("production_candidate")) for r in processed_records
        ),
        "note": "Listing-page and crawl-success metrics are populated by brand crawler adapters when implemented.",
    }
    write_json(reports_dir / f"{brand_slug}_crawl_report.json", crawl_report)
    return crawl_report
