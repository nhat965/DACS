from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path
from typing import Any

from data_pipeline.config.contracts import CATEGORY_CODES
from data_pipeline.importer.contract_guard import validate_import_payload, whitelist_production_payload


CATEGORY_NAMES = {
    'cleanser': 'Cleanser',
    'toner': 'Toner',
    'serum': 'Serum',
    'moisturizer': 'Moisturizer',
    'sunscreen': 'Sunscreen',
    'exfoliant': 'Exfoliant',
    'mask': 'Mask',
    'makeup_remover': 'Makeup Remover',
    'eye_care': 'Eye Care',
    'lip_care': 'Lip Care',
    'body_care': 'Body Care',
}

BRAND_REFERENCE = {
    'COSRX': ('South Korea', 'https://www.cosrx.com'),
    'CeraVe': ('United States', 'https://www.cerave.com'),
    'The Ordinary': ('Canada', 'https://theordinary.com'),
    'La Roche-Posay': ('France', 'https://www.laroche-posay.us'),
    "Paula's Choice": ('United States', 'https://www.paulaschoice.com'),
    'Bioderma': ('France', 'https://www.bioderma.us'),
    'Eucerin': ('Germany', 'https://www.eucerinus.com'),
    'Neutrogena': ('United States', 'https://www.neutrogena.com'),
    'Vichy': ('France', 'https://www.vichyusa.com'),
    "Kiehl's": ('United States', 'https://www.kiehls.com'),
    'LANEIGE': ('South Korea', 'https://us.laneige.com'),
    'innisfree': ('South Korea', 'https://us.innisfree.com'),
    'First Aid Beauty': ('United States', 'https://www.firstaidbeauty.com'),
}


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key, value = key.strip(), value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


@dataclass(frozen=True)
class MySQLSettings:
    host: str = '127.0.0.1'
    port: int = 3306
    user: str = 'root'
    password: str = ''
    database: str = 'cosmetic_ecommerce'
    expected_price_currency: str | None = None

    @classmethod
    def from_repo(cls, repo_root: Path) -> 'MySQLSettings':
        _load_env_file(repo_root / '.env.local')
        currency = os.getenv('MYSQL_EXPECTED_PRICE_CURRENCY', '').strip().upper() or None
        return cls(
            host=os.getenv('MYSQL_HOST', '127.0.0.1'),
            port=int(os.getenv('MYSQL_PORT', '3306')),
            user=os.getenv('MYSQL_USER', 'root'),
            password=os.getenv('MYSQL_PASSWORD', ''),
            database=os.getenv('MYSQL_DATABASE', 'cosmetic_ecommerce'),
            expected_price_currency=currency,
        )


def _as_db_list(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, list):
        return ','.join(str(x) for x in value)
    return str(value)


def _connect(settings: MySQLSettings):
    try:
        import mysql.connector  # type: ignore
    except ImportError as exc:
        raise RuntimeError('mysql-connector-python is required. Run: pip install -r requirements-data-pipeline.txt') from exc
    return mysql.connector.connect(
        host=settings.host,
        port=settings.port,
        user=settings.user,
        password=settings.password,
        database=settings.database,
        charset='utf8mb4',
        autocommit=False,
    )


def _ensure_reference_data(cursor, records: list[dict[str, Any]]) -> tuple[dict[str, int], dict[str, int]]:
    brand_names = sorted({str(r.get('brand_normalized')).strip() for r in records if r.get('brand_normalized')})
    for brand in brand_names:
        country, official_url = BRAND_REFERENCE.get(brand, (None, None))
        cursor.execute('SELECT id FROM brands WHERE LOWER(name)=LOWER(%s) LIMIT 1', (brand,))
        row = cursor.fetchone()
        if not row:
            cursor.execute('INSERT INTO brands (name, country, official_url) VALUES (%s, %s, %s)', (brand, country, official_url))

    used_categories = sorted({r.get('category_normalized') for r in records if r.get('category_normalized') in CATEGORY_CODES})
    for code in used_categories:
        display = CATEGORY_NAMES[code]
        cursor.execute('SELECT id FROM categories WHERE LOWER(name) IN (LOWER(%s), LOWER(%s)) LIMIT 1', (display, code))
        row = cursor.fetchone()
        if not row:
            cursor.execute('INSERT INTO categories (name, parent_id) VALUES (%s, NULL)', (display,))

    cursor.execute('SELECT id, name FROM brands')
    brands = {str(name).lower(): int(id_) for id_, name in cursor.fetchall()}
    cursor.execute('SELECT id, name FROM categories')
    categories_by_name = {str(name).lower(): int(id_) for id_, name in cursor.fetchall()}
    categories: dict[str, int] = {}
    for code, display in CATEGORY_NAMES.items():
        cid = categories_by_name.get(display.lower()) or categories_by_name.get(code.lower())
        if cid:
            categories[code] = cid
    return brands, categories


def _build_payload(record: dict[str, Any], brands: dict[str, int], categories: dict[str, int]) -> tuple[dict[str, Any] | None, list[str]]:
    meta = record.get('_processing', {}) if isinstance(record.get('_processing'), dict) else {}
    errors: list[str] = []
    if not meta.get('production_candidate'):
        errors.append('not_production_candidate')
    brand_name = str(record.get('brand_normalized') or '').strip()
    brand_id = brands.get(brand_name.lower())
    category_code = record.get('category_normalized')
    category_id = categories.get(category_code)
    if not brand_id:
        errors.append('brand_id_unresolved')
    if not category_id:
        errors.append('category_id_unresolved')
    if not record.get('sku'):
        errors.append('missing_sku')
    if record.get('price') is None:
        errors.append('missing_price')
    if errors:
        return None, errors

    prepared = dict(record)
    prepared.update({
        'brand_id': brand_id,
        'category_id': category_id,
        'stock_quantity': 0,
        'status': 'DRAFT',
        'ai_ready': bool(meta.get('ai_ready')),
        'verified_at': meta.get('verified_at_candidate'),
    })
    payload = whitelist_production_payload(prepared)
    payload['skin_types'] = _as_db_list(payload.get('skin_types'))
    payload['skin_concerns'] = _as_db_list(payload.get('skin_concerns'))
    payload['care_goals'] = _as_db_list(payload.get('care_goals'))
    validation = validate_import_payload(payload)
    return (payload if not validation else None), validation


def ensure_database_schema(repo_root: Path) -> dict[str, Any]:
    """Apply each SQL migration once and keep the migration files as source of truth."""
    settings = MySQLSettings.from_repo(repo_root)
    try:
        import mysql.connector  # type: ignore
    except ImportError as exc:
        raise RuntimeError('mysql-connector-python is required. Run: pip install -r requirements-data-pipeline.txt') from exc
    server = mysql.connector.connect(
        host=settings.host, port=settings.port, user=settings.user, password=settings.password,
        charset='utf8mb4', autocommit=True,
    )
    applied_now: list[str] = []
    try:
        cur = server.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS `{settings.database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        cur.execute(f"USE `{settings.database}`")
        cur.execute(
            "CREATE TABLE IF NOT EXISTS schema_migrations ("
            "name VARCHAR(255) PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)"
        )
        cur.execute("SELECT name FROM schema_migrations")
        applied = {str(row[0]) for row in cur.fetchall()}
        for migration_path in sorted((repo_root / 'database' / 'migrations').glob('*.sql')):
            if migration_path.name in applied:
                continue
            migration = migration_path.read_text(encoding='utf-8')
            statements = [x.strip() for x in migration.split(';') if x.strip()]
            for statement in statements:
                if statement.upper().startswith('CREATE DATABASE') or statement.upper().startswith('USE '):
                    continue
                add_column = re.match(
                    r'ALTER\s+TABLE\s+`?([A-Za-z0-9_]+)`?\s+ADD\s+COLUMN\s+`?([A-Za-z0-9_]+)`?',
                    statement,
                    flags=re.I,
                )
                if add_column:
                    table_name, column_name = add_column.groups()
                    cur.execute(
                        "SELECT 1 FROM information_schema.columns "
                        "WHERE table_schema=%s AND table_name=%s AND column_name=%s LIMIT 1",
                        (settings.database, table_name, column_name),
                    )
                    if cur.fetchone():
                        continue
                safe_statement = (
                    statement.replace('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS ', 1)
                    if statement.upper().startswith('CREATE TABLE ') else statement
                )
                cur.execute(safe_statement)
            cur.execute("INSERT INTO schema_migrations (name) VALUES (%s)", (migration_path.name,))
            applied_now.append(migration_path.name)
        return {
            'database': settings.database,
            'schema_created': bool(applied_now),
            'migrations_applied': applied_now,
        }
    finally:
        server.close()


def import_records(repo_root: Path, records: list[dict[str, Any]], dry_run: bool = False, sync_existing: bool = False) -> dict[str, Any]:
    settings = MySQLSettings.from_repo(repo_root)
    report: dict[str, Any] = {
        'database': settings.database,
        'host': settings.host,
        'expected_price_currency': settings.expected_price_currency,
        'total_input': len(records),
        'eligible': 0,
        'inserted': 0,
        'updated': 0,
        'would_update': 0,
        'unchanged_existing': 0,
        'skipped_existing': 0,
        'skipped_quality': 0,
        'skipped_currency': 0,
        'errors': [],
        'dry_run': dry_run,
        'sync_existing': sync_existing,
        'note': 'Imports production-valid records regardless of AI readiness. When sync_existing is enabled, existing rows matched by SKU/source_url are refreshed field-by-field from the newly processed official-source data without replacing non-empty DB values by null/empty values. stock_quantity and status are preserved for existing rows.',
    }

    conn = _connect(settings)
    try:
        cursor = conn.cursor()
        brands, categories = _ensure_reference_data(cursor, records)
        for record in records:
            meta = record.get('_processing', {}) if isinstance(record.get('_processing'), dict) else {}
            source_currency = str(meta.get('source_currency') or '').strip().upper() or None
            if settings.expected_price_currency and source_currency and source_currency != settings.expected_price_currency:
                report['skipped_currency'] += 1
                report['errors'].append({'source_url': record.get('source_url'), 'sku': record.get('sku'), 'reasons': [f'currency_mismatch:{source_currency}!={settings.expected_price_currency}']})
                continue
            payload, errors = _build_payload(record, brands, categories)
            if errors or not payload:
                report['skipped_quality'] += 1
                report['errors'].append({'source_url': record.get('source_url'), 'sku': record.get('sku'), 'reasons': errors})
                continue
            report['eligible'] += 1
            sync_fields = [
                'name', 'brand_id', 'category_id', 'price', 'currency', 'volume', 'description', 'benefits',
                'inci_ingredients', 'key_ingredients', 'skin_types', 'skin_concerns', 'care_goals',
                'texture', 'usage_instruction', 'warnings', 'image_url', 'source_url', 'verified_at',
                'ai_ready',
            ]
            cursor.execute(
                'SELECT id,' + ','.join(sync_fields) + ' FROM products WHERE sku=%s OR (source_url IS NOT NULL AND source_url=%s) LIMIT 1',
                (payload['sku'], payload.get('source_url'))
            )
            existing_row = cursor.fetchone()
            if existing_row:
                if not sync_existing:
                    report['skipped_existing'] += 1
                    continue
                existing = dict(zip(['id'] + sync_fields, existing_row))
                changes: dict[str, Any] = {}
                for field in sync_fields:
                    incoming = payload.get(field)
                    # Never degrade an existing product by replacing useful data with empty values.
                    if incoming is None or incoming == '' or incoming == []:
                        continue
                    current = existing.get(field)
                    # mysql-connector may return Decimal/date while payload can contain equivalent values.
                    if str(current) != str(incoming):
                        changes[field] = incoming
                if not changes:
                    if not dry_run:
                        _sync_product_metadata(cursor, int(existing['id']), record)
                    report['unchanged_existing'] += 1
                    continue
                if dry_run:
                    report['would_update'] += 1
                    continue
                assignments = ','.join(f'{field}=%s' for field in changes)
                cursor.execute(
                    f'UPDATE products SET {assignments} WHERE id=%s',
                    [changes[field] for field in changes] + [existing['id']],
                )
                _sync_product_metadata(cursor, int(existing['id']), record)
                report['updated'] += 1
                continue
            columns = list(payload.keys())
            values = [payload[c] for c in columns]
            placeholders = ','.join(['%s'] * len(columns))
            sql = f"INSERT INTO products ({','.join(columns)}) VALUES ({placeholders})"
            cursor.execute(sql, values)
            _sync_product_metadata(cursor, int(cursor.lastrowid), record)
            report['inserted'] += 1
        if dry_run:
            conn.rollback()
        else:
            conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    report_path = repo_root / 'datasets' / 'reports' / 'mysql_import_report.json'
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2, default=str) + '\n', encoding='utf-8')
    return report


def _sync_product_metadata(cursor, product_id: int, record: dict[str, Any]) -> None:
    meta = record.get('_processing', {}) if isinstance(record.get('_processing'), dict) else {}
    mappings = meta.get('ingredient_mappings') or []
    cursor.execute('DELETE FROM product_ingredients WHERE product_id=%s', (product_id,))
    for mapping in mappings:
        normalized_name = str(mapping.get('normalized_name') or '').strip()
        raw_name = str(mapping.get('raw_name') or '').strip()
        inci_name = str(mapping.get('inci_name') or raw_name).strip()
        if (
            not normalized_name
            or not raw_name
            or len(normalized_name) > 255
            or len(inci_name) > 255
            or len(raw_name) > 500
        ):
            continue
        cursor.execute(
            "INSERT INTO ingredients (inci_name, normalized_name, source_type, source_url, last_verified_at) "
            "VALUES (%s, %s, %s, %s, %s) "
            "ON DUPLICATE KEY UPDATE inci_name=VALUES(inci_name)",
            (
                inci_name,
                normalized_name,
                'manufacturer',
                record.get('source_url'),
                meta.get('last_verified_at'),
            ),
        )
        cursor.execute('SELECT id FROM ingredients WHERE normalized_name=%s', (normalized_name,))
        ingredient_id = int(cursor.fetchone()[0])
        cursor.execute(
            'INSERT IGNORE INTO product_ingredients '
            '(product_id, ingredient_id, position, raw_name) '
            'VALUES (%s, %s, %s, %s)',
            (product_id, ingredient_id, mapping.get('position'), raw_name),
        )

    for field_name, provenance in (meta.get('field_provenance') or {}).items():
        cursor.execute(
            "INSERT INTO product_field_provenance "
            "(product_id, field_name, data_class, source_type, source_url, retrieved_at, "
            "last_verified_at, evidence_type, confidence, extraction_method) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
            "ON DUPLICATE KEY UPDATE data_class=VALUES(data_class), source_type=VALUES(source_type), "
            "source_url=VALUES(source_url), retrieved_at=VALUES(retrieved_at), "
            "last_verified_at=VALUES(last_verified_at), evidence_type=VALUES(evidence_type), "
            "confidence=VALUES(confidence), extraction_method=VALUES(extraction_method)",
            (
                product_id,
                field_name,
                provenance.get('data_class', 'FACTUAL'),
                provenance.get('source_type'),
                provenance.get('source_url'),
                provenance.get('retrieved_at'),
                provenance.get('last_verified_at'),
                provenance.get('evidence_type', 'explicit'),
                provenance.get('confidence'),
                provenance.get('extraction_method'),
            ),
        )
