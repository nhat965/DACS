from __future__ import annotations

import argparse
import json
from pathlib import Path

from data_pipeline.importer.mysql_importer import ensure_database_schema, import_records
from data_pipeline.pipeline import process_brand
from data_pipeline.wave1 import ALL_REVIEWED_BRANDS, WAVE1_BRANDS, crawl_brand, export_combined, run_all_reviewed, run_wave1


def _load_processed(repo_root: Path, brands: tuple[str, ...]) -> list[dict]:
    import json as _json
    rows: list[dict] = []
    for brand in brands:
        path = repo_root / 'datasets' / 'processed' / brand / 'products.json'
        if not path.exists():
            continue
        payload = _json.loads(path.read_text(encoding='utf-8'))
        batch = payload if isinstance(payload, list) else payload.get('products', [])
        rows.extend(x for x in batch if isinstance(x, dict))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description='DACS cosmetic data pipeline')
    sub = parser.add_subparsers(dest='command', required=True)

    crawl_cmd = sub.add_parser('crawl-brand', help='Crawl one reviewed official brand into datasets/raw')
    crawl_cmd.add_argument('brand', choices=list(ALL_REVIEWED_BRANDS))
    crawl_cmd.add_argument('--repo-root', default='.')

    crawl_all = sub.add_parser('crawl-wave1', help='Crawl all five Wave-1 brands')
    crawl_all.add_argument('--repo-root', default='.')

    crawl_all_reviewed = sub.add_parser('crawl-all', help='Crawl all reviewed official brands, including Wave 2')
    crawl_all_reviewed.add_argument('--repo-root', default='.')

    process_cmd = sub.add_parser('process-brand', help='Process an existing raw brand dataset')
    process_cmd.add_argument('brand', choices=list(ALL_REVIEWED_BRANDS))
    process_cmd.add_argument('--repo-root', default='.')

    process_all = sub.add_parser('process-wave1', help='Process all available Wave-1 raw datasets')
    process_all.add_argument('--repo-root', default='.')

    process_all_reviewed = sub.add_parser('process-all', help='Process all available reviewed-brand raw datasets')
    process_all_reviewed.add_argument('--repo-root', default='.')

    import_cmd = sub.add_parser('import-mysql', help='Import AI-ready/production-valid processed records into MySQL as DRAFT')
    import_cmd.add_argument('--repo-root', default='.')
    import_cmd.add_argument('--dry-run', action='store_true')
    import_cmd.add_argument('--sync-existing', action='store_true', help='Refresh existing products matched by SKU/source_url using non-empty reprocessed fields')

    run_cmd = sub.add_parser('run-wave1', help='Crawl 5 brands -> CSV/JSON -> process -> CSV/JSON -> MySQL')
    run_cmd.add_argument('--repo-root', default='.')
    run_cmd.add_argument('--dry-run-mysql', action='store_true')
    run_cmd.add_argument('--no-mysql', action='store_true')

    run_all_cmd = sub.add_parser('run-all', help='Crawl all reviewed brands -> CSV/JSON -> process -> CSV/JSON -> MySQL')
    run_all_cmd.add_argument('--repo-root', default='.')
    run_all_cmd.add_argument('--dry-run-mysql', action='store_true')
    run_all_cmd.add_argument('--no-mysql', action='store_true')

    args = parser.parse_args()
    repo_root = Path(getattr(args, 'repo_root', '.')).resolve()

    if args.command == 'crawl-brand':
        result = crawl_brand(repo_root, args.brand)
    elif args.command == 'crawl-wave1':
        result = {}
        for brand in WAVE1_BRANDS:
            try:
                result[brand] = crawl_brand(repo_root, brand)
            except Exception as exc:
                result[brand] = {'error': f'{type(exc).__name__}: {exc}'}
        result['combined'] = export_combined(repo_root, WAVE1_BRANDS)['raw']
    elif args.command == 'crawl-all':
        result = {}
        for brand in ALL_REVIEWED_BRANDS:
            try:
                result[brand] = crawl_brand(repo_root, brand)
            except Exception as exc:
                result[brand] = {'error': f'{type(exc).__name__}: {exc}'}
        result['combined'] = export_combined(repo_root, ALL_REVIEWED_BRANDS)['raw']
    elif args.command == 'process-brand':
        result = process_brand(repo_root, args.brand)
        result['combined'] = export_combined(repo_root)
    elif args.command == 'process-wave1':
        result = {}
        for brand in WAVE1_BRANDS:
            if (repo_root / 'datasets' / 'raw' / brand / 'products.json').exists():
                result[brand] = process_brand(repo_root, brand)
        result['combined'] = export_combined(repo_root, WAVE1_BRANDS)
    elif args.command == 'process-all':
        result = {}
        for brand in ALL_REVIEWED_BRANDS:
            if (repo_root / 'datasets' / 'raw' / brand / 'products.json').exists():
                result[brand] = process_brand(repo_root, brand)
        result['combined'] = export_combined(repo_root, ALL_REVIEWED_BRANDS)
    elif args.command == 'import-mysql':
        schema = (
            {'skipped': True, 'reason': 'dry_run_does_not_modify_schema'}
            if args.dry_run
            else ensure_database_schema(repo_root)
        )
        rows = _load_processed(repo_root, ALL_REVIEWED_BRANDS)
        result = {'schema': schema, 'import': import_records(repo_root, rows, dry_run=args.dry_run, sync_existing=args.sync_existing)}
    elif args.command == 'run-wave1':
        result = run_wave1(repo_root, import_mysql=not args.no_mysql, dry_run_mysql=args.dry_run_mysql)
    elif args.command == 'run-all':
        result = run_all_reviewed(repo_root, import_mysql=not args.no_mysql, dry_run_mysql=args.dry_run_mysql)
    else:
        return 2

    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
