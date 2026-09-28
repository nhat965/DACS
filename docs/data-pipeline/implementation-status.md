# Data pipeline implementation status

## Implemented

- Immutable production contract + enum constants.
- Cleaner / normalizer / deduplicator / validator / exporter / importer contract guard.
- AI-ready quality gate separated from production candidacy.
- Field-level provenance and unmapped-value reporting.
- Checkpoint/resume + retry/backoff/rate-limited HTTP infrastructure.
- COSRX official-site analysis and reviewed crawler adapter.
- COSRX raw HTML snapshots per product, canonical URL discovery, category/concern collection hints.
- CLI: `crawl-brand cosrx` then `process-brand cosrx`.
- Static parser tests plus end-to-end quality-gate tests.
- Wave 2 config-driven official crawlers for Bioderma, Eucerin, Neutrogena, Vichy, Kiehl's, LANEIGE, innisfree and First Aid Beauty.
- Extended `crawl-all`, `process-all` and `run-all` CLI commands for all reviewed brands.
- Generic official crawler now follows additional in-domain skincare/category listing pages, capped by `max_listing_pages`, to increase product discovery without turning the crawler into an unbounded site crawl.

## Current execution note

The code execution sandbox used while implementing this repository may block external
network/package access, so a full live crawl should be run from a normal local Python
environment. The adapters are built for normal network execution and resume from
checkpoints if interrupted. No fake crawl records are generated to hide this limitation.

## Next wave

After running `python -m data_pipeline.cli run-all --repo-root . --dry-run-mysql`,
review the per-brand quality reports before importing into MySQL. Brands with many
`missing_price`, `missing_sku` or `category_id_unresolved` records should be tuned with
more source-specific extraction only when the official page exposes those values clearly.
Do not change database/API contracts merely to force uncertain records through the gate.
