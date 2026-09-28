# DACS cosmetic data pipeline

The pipeline is deliberately split into crawl/raw and processing/validation phases. Raw records are never dropped merely because they are incomplete.

## Reviewed official brands

Wave 1:

- COSRX
- CeraVe
- The Ordinary
- La Roche-Posay
- Paula's Choice

Wave 2 expansion:

- Bioderma
- Eucerin
- Neutrogena
- Vichy
- Kiehl's
- LANEIGE
- innisfree
- First Aid Beauty

Each brand is crawled from its official website. See `docs/data-pipeline/brand-analysis/wave1-five-brands.md` for the original source-selection policy. Wave 2 uses the same official-source, raw-first, conservative-normalization pipeline.

## One-command local run

Windows:

```bat
run_data_pipeline.bat
```

macOS/Linux:

```bash
./run_data_pipeline.sh
```

The launcher installs `requirements-data-pipeline.txt` and runs:

```bash
python -m data_pipeline.cli run-all --repo-root .
```

That command performs:

1. crawl all reviewed official brands into `datasets/raw/{brand}/products.json` **and** `products.csv`;
2. create combined raw overview `datasets/raw/all_brands_products.json` and `.csv`;
3. clean, normalize, deduplicate and validate each available brand;
4. write processed JSON + CSV and strict AI-ready product-catalog JSON + CSV;
5. create combined processed/catalog JSON + CSV;
6. ensure the existing MySQL schema exists (using the repository migration only when needed);
7. import only records that pass quality and DB gates, without overwriting existing SKU/source URL rows;
8. write `datasets/reports/mysql_import_report.json` and `wave1_run_report.json`.

## MySQL local configuration

`.env.local` is gitignored and contains local connection settings. Do not commit or share it. Defaults are local MySQL, user `root`, database `cosmetic_ecommerce`. Edit it if your MySQL username/port/database differs.

The current product schema has **no currency column**. To avoid silently mixing price semantics, `MYSQL_EXPECTED_PRICE_CURRENCY` is a hard guard. A record with a different explicit source currency is skipped and reported, not converted or guessed.

Imported products are intentionally `DRAFT` with `stock_quantity=0`; the crawler never fabricates inventory. Existing production data is not overwritten.
The importer also persists the `ai_ready` gate. Recommendation queries require
`ai_ready = TRUE` in addition to `ACTIVE` status and positive stock.

## Useful commands

```bash
python -m data_pipeline.cli crawl-brand cosrx --repo-root .
python -m data_pipeline.cli crawl-brand bioderma --repo-root .
python -m data_pipeline.cli crawl-wave1
python -m data_pipeline.cli crawl-all
python -m data_pipeline.cli process-brand cosrx --repo-root .
python -m data_pipeline.cli process-wave1 --repo-root .
python -m data_pipeline.cli process-all --repo-root .
python -m data_pipeline.cli import-mysql --repo-root . --dry-run
python -m data_pipeline.cli import-mysql --repo-root .
python -m data_pipeline.cli run-all --repo-root . --dry-run-mysql
```

Dry-run commands never create a database or apply schema migrations. The target
schema must already exist when validating a dry-run import.

## Output overview

Per brand:

```text
datasets/raw/{brand}/products.json
datasets/raw/{brand}/products.csv
datasets/processed/{brand}/products.json
datasets/processed/{brand}/products.csv
datasets/product-catalog/{brand}/products.json
datasets/product-catalog/{brand}/products.csv
```

Combined reviewed-brand overview:

```text
datasets/raw/all_brands_products.json
datasets/raw/all_brands_products.csv
datasets/processed/all_brands_products.json
datasets/processed/all_brands_products.csv
datasets/product-catalog/all_brands_products.json
datasets/product-catalog/all_brands_products.csv
```

CSV is UTF-8 with BOM so it opens cleanly in Excel. Lists/dicts are JSON strings inside cells.

## Pipeline v2 quality-gate fix

- Duplicate observations of the same product are **merged**, not discarded first-record-wins.
- Embedded `KEY INGREDIENTS`, `Full Ingredients`, `How to Use`, `Cautions` and explicit benefit text are recovered from already-crawled source text before normalization.
- Missing category may be filled only from an explicit product-type phrase in the official product name/description (for example `cleanser`, `serum`, `toner`, `sunscreen`); ambiguous products remain unmapped.
- Explicit source wording is normalized into skin type / concern / care-goal enums. No ingredient-effect inference is performed.
- `production_candidate` and `ai_ready` are independent. MySQL imports production-valid records as `DRAFT`; recommendation/RAG should use `ai_ready_products.json/csv` only.
- `datasets/product-catalog/{brand}/products.*` = production-ready; `ai_ready_products.*` = stricter AI-ready subset.

## v0.3 semantic product knowledge

`description`, `benefits`, `inci_ingredients`, `key_ingredients`, `skin_types`,
`skin_concerns`, `care_goals`, `usage_instruction`, and `warnings` are treated as
core product knowledge shared by the website and the recommendation/chatbot stack.

The enrichment stage may recover missing structured fields only from text already
present in the official source record. In particular, when a site has no separate
Benefits section, source-stated benefit sentences may be copied from
`description_raw` into `benefits_raw`. The pipeline does **not** infer a benefit
from an ingredient or external cosmetic knowledge.

Each processed record now also contains internal-only quality metadata:

- `_processing.core_knowledge_score`
- `_processing.core_knowledge_present`
- `_processing.core_knowledge_missing`

A combined semantic coverage report is written to:

`datasets/reports/semantic_coverage_report.json`

These `_processing` fields are never imported into the production product table or
returned by the Product API.


## Reprocess and sync existing MySQL rows

The v4 importer can refresh products that are already present in MySQL. Existing rows are matched by `sku` or `source_url`. Only non-empty reprocessed fields are written back, while existing `stock_quantity` and `status` are preserved.

```bash
python -m data_pipeline.cli process-wave1 --repo-root .
python -m data_pipeline.cli import-mysql --repo-root . --dry-run --sync-existing
python -m data_pipeline.cli import-mysql --repo-root . --sync-existing
```

Without `--sync-existing`, pre-existing rows are skipped for backward compatibility.
