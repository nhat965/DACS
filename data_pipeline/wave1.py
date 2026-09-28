from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from data_pipeline.crawler.brands.cosrx import CosrxCrawler
from data_pipeline.crawler.brands.configs import BRAND_CONFIGS
from data_pipeline.crawler.brands.generic_official import GenericOfficialCrawler
from data_pipeline.exporter.csv_exporter import write_csv
from data_pipeline.exporter.json_exporter import write_json
from data_pipeline.exporter.reports import build_quality_report
from data_pipeline.importer.mysql_importer import ensure_database_schema, import_records
from data_pipeline.pipeline import load_raw_products, process_brand

WAVE1_BRANDS = ('cosrx', 'cerave', 'the-ordinary', 'laroche-posay', 'paulas-choice')
WAVE2_BRANDS = (
    'bioderma',
    'eucerin',
    'neutrogena',
    'vichy',
    'kiehls',
    'laneige',
    'innisfree',
    'first-aid-beauty',
)
ALL_REVIEWED_BRANDS = WAVE1_BRANDS + WAVE2_BRANDS


def crawl_brand(repo_root: Path, brand: str) -> dict[str, Any]:
    if brand == 'cosrx':
        return CosrxCrawler(repo_root).crawl()
    config = BRAND_CONFIGS.get(brand)
    if not config:
        raise ValueError(f'Unsupported reviewed brand: {brand}')
    return GenericOfficialCrawler(repo_root, config).crawl()


def _collect(repo_root: Path, layer: str, brands: tuple[str, ...] = ALL_REVIEWED_BRANDS) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for brand in brands:
        path = repo_root / 'datasets' / layer / brand / 'products.json'
        if not path.exists():
            continue
        try:
            payload = json.loads(path.read_text(encoding='utf-8'))
            batch = payload if isinstance(payload, list) else payload.get('products', [])
            for row in batch:
                if isinstance(row, dict):
                    item = dict(row)
                    item.setdefault('_brand_slug', brand)
                    records.append(item)
        except Exception:
            continue
    return records


def _semantic_coverage_report(records: list[dict[str, Any]]) -> dict[str, Any]:
    fields = (
        'description', 'benefits', 'inci_ingredients', 'key_ingredients',
        'skin_types', 'skin_concerns', 'care_goals', 'texture',
        'usage_instruction', 'warnings',
    )
    def present(value: Any) -> bool:
        return value not in (None, '', [], {})
    total = len(records)
    coverage = {}
    for field in fields:
        count = sum(1 for row in records if present(row.get(field)))
        coverage[field] = {
            'present': count,
            'missing': total - count,
            'coverage_rate': round(count / total, 4) if total else 0,
        }
    extracted_benefits = 0
    for row in records:
        provenance = row.get('_processing', {}).get('field_provenance', {}) or {}
        if row.get('benefits') and provenance.get('benefits'):
            extracted_benefits += 1
    return {
        'total_processed': total,
        'coverage': coverage,
        'production_ready': sum(bool(row.get('_processing', {}).get('production_candidate')) for row in records),
        'ai_ready': sum(bool(row.get('_processing', {}).get('ai_ready')) for row in records),
    }


def export_combined(repo_root: Path, brands: tuple[str, ...] = ALL_REVIEWED_BRANDS) -> dict[str, Any]:
    outputs: dict[str, Any] = {}
    for layer in ('raw', 'processed', 'product-catalog'):
        records = _collect(repo_root, layer, brands)
        out_dir = repo_root / 'datasets' / layer
        json_path = out_dir / 'all_brands_products.json'
        csv_path = out_dir / 'all_brands_products.csv'
        write_json(json_path, records)
        write_csv(csv_path, records)
        outputs[layer] = {
            'records': len(records),
            'json': str(json_path.relative_to(repo_root)),
            'csv': str(csv_path.relative_to(repo_root)),
        }
    ai_records: list[dict[str, Any]] = []
    for brand in brands:
        path = repo_root / 'datasets' / 'product-catalog' / brand / 'ai_ready_products.json'
        if not path.exists():
            continue
        try:
            payload = json.loads(path.read_text(encoding='utf-8'))
            for row in payload if isinstance(payload, list) else []:
                if isinstance(row, dict):
                    item = dict(row)
                    item.setdefault('_brand_slug', brand)
                    ai_records.append(item)
        except Exception:
            continue
    ai_json = repo_root / 'datasets' / 'product-catalog' / 'all_brands_ai_ready_products.json'
    ai_csv = repo_root / 'datasets' / 'product-catalog' / 'all_brands_ai_ready_products.csv'
    write_json(ai_json, ai_records)
    write_csv(ai_csv, ai_records)
    outputs['ai-ready'] = {'records': len(ai_records), 'json': str(ai_json.relative_to(repo_root)), 'csv': str(ai_csv.relative_to(repo_root))}

    processed_records = _collect(repo_root, 'processed', brands)
    if processed_records:
        semantic_report = repo_root / 'datasets' / 'reports' / 'semantic_coverage_report.json'
        write_json(semantic_report, _semantic_coverage_report(processed_records))
        outputs['semantic-coverage'] = {'json': str(semantic_report.relative_to(repo_root))}
        duplicate_count = 0
        for brand in brands:
            duplicate_path = repo_root / 'datasets' / 'reports' / f'{brand}_duplicate_report.json'
            if duplicate_path.exists():
                try:
                    duplicate_count += len(json.loads(duplicate_path.read_text(encoding='utf-8')))
                except (OSError, ValueError, TypeError):
                    pass
        quality_report = repo_root / 'datasets' / 'reports' / 'all_brands_quality_report.json'
        write_json(
            quality_report,
            build_quality_report(processed_records, duplicate_count=duplicate_count),
        )
        outputs['data-quality'] = {'json': str(quality_report.relative_to(repo_root))}
    return outputs


def run_brands(repo_root: Path, brands: tuple[str, ...] = ALL_REVIEWED_BRANDS,
               import_mysql: bool = True, dry_run_mysql: bool = False,
               report_filename: str = 'all_brands_run_report.json') -> dict[str, Any]:
    crawl_reports: dict[str, Any] = {}
    process_reports: dict[str, Any] = {}
    errors: dict[str, str] = {}

    for brand in brands:
        try:
            crawl_reports[brand] = crawl_brand(repo_root, brand)
        except Exception as exc:
            errors[f'crawl:{brand}'] = f'{type(exc).__name__}: {exc}'

    # Export raw overview immediately, even when one source failed.
    raw_overview = export_combined(repo_root, brands)['raw']

    for brand in brands:
        raw_path = repo_root / 'datasets' / 'raw' / brand / 'products.json'
        if not raw_path.exists():
            continue
        try:
            process_reports[brand] = process_brand(repo_root, brand)
        except Exception as exc:
            errors[f'process:{brand}'] = f'{type(exc).__name__}: {exc}'

    combined = export_combined(repo_root, brands)
    mysql_report = None
    schema_report = None
    if import_mysql:
        try:
            schema_report = (
                {'skipped': True, 'reason': 'dry_run_does_not_modify_schema'}
                if dry_run_mysql
                else ensure_database_schema(repo_root)
            )
            processed = _collect(repo_root, 'processed', brands)
            mysql_report = import_records(repo_root, processed, dry_run=dry_run_mysql, sync_existing=True)
        except Exception as exc:
            errors['mysql'] = f'{type(exc).__name__}: {exc}'

    report = {
        'brands': list(brands),
        'crawl': crawl_reports,
        'processing': process_reports,
        'combined_outputs': combined,
        'raw_overview_after_crawl': raw_overview,
        'mysql_schema': schema_report,
        'mysql_import': mysql_report,
        'errors': errors,
    }
    write_json(repo_root / 'datasets' / 'reports' / report_filename, report)
    return report


def run_wave1(repo_root: Path, import_mysql: bool = True, dry_run_mysql: bool = False) -> dict[str, Any]:
    return run_brands(
        repo_root,
        WAVE1_BRANDS,
        import_mysql=import_mysql,
        dry_run_mysql=dry_run_mysql,
        report_filename='wave1_run_report.json',
    )


def run_all_reviewed(repo_root: Path, import_mysql: bool = True, dry_run_mysql: bool = False) -> dict[str, Any]:
    return run_brands(
        repo_root,
        ALL_REVIEWED_BRANDS,
        import_mysql=import_mysql,
        dry_run_mysql=dry_run_mysql,
        report_filename='all_brands_run_report.json',
    )
