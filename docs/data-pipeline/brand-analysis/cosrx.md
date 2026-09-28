# COSRX crawler analysis (official source)

Status: **analysis complete; adapter approved for implementation**.

## 1. Website / brand

- Brand: COSRX
- Official domain: `https://www.cosrx.com`
- Source tier: Tier 1 — official brand website.
- Primary coverage collection: `/collections/all`.

## 2. Website structure

The official site is collection/product oriented. Product listing pages live under
`/collections/{handle}` and product detail pages under `/products/{handle}`. The
`/collections/all` page currently represents the broadest discovery surface.

## 3. Discovery strategy

1. Iterate `/collections/all?page=N` until a page yields no new `/products/` links.
2. Pass through reviewed category collections to attach conservative category hints.
3. Pass through official skin-concern collections to attach source-backed concern hints.
4. Canonicalize product URLs to the `/products/{handle}` URL and deduplicate before crawling.
5. Persist discovered/crawled/failed URLs in `datasets/checkpoints/cosrx.json`.

## 4. Crawl technology

Use direct HTTP + BeautifulSoup first. The public listing/detail pages expose useful
HTML/JSON-LD and do not require browser automation for the initial adapter. Playwright
should only be added if later verification shows critical fields exist only after JS execution.

## 5. Fields obtainable from official pages

Expected/high-confidence fields include product name, price/currency, volume/size,
description, benefits/concerns, full ingredient list, key ingredients, explicit skin
suitability, usage instructions, images, availability and source URL. SKU is captured
only when the page/JSON-LD actually exposes it.

## 6. Production mapping

Raw values are stored unchanged first. Deterministic category hints map to the existing
category enum only. Skin concerns/goals/types are normalized later under the immutable
contract. No new production field is introduced.

## 7. Fields that may remain unmapped

- SKU if the official page does not expose one.
- Stock quantity: availability text is not converted into a made-up quantity.
- Care goals where the official wording cannot be deterministically mapped.
- Texture if not explicitly stated.
- Warnings if no warning/caution section exists.

## 8. Extraction risks

- Product detail pages include recommendation/routine/FAQ blocks; those must not be
  mixed into the current product's ingredients or usage fields.
- Bundles/sets can reference several child products and must remain distinct from a
  single-product record unless the source identifies a direct product SKU.
- Multiple size variants can share one product URL; raw size information must be kept
  without inventing separate SKUs.
- Marketing/clinical claims are source text only and must not be expanded by the pipeline.

## 9. Duplicate strategy

Use existing project policy: SKU → source product ID if later available → canonical URL →
brand + normalized name + volume. Canonical URL is the primary reliable key for this adapter.

## 10. Validation rules

Require source URL, name, recognized brand, category mapping for production candidacy;
validate semantic enums in the normalizer/validator; keep unmapped raw values; reject
cross-product contamination; AI-ready gating remains stricter than production validity.

## 11. Files created/modified

- `data_pipeline/crawler/brands/cosrx.py`
- `docs/data-pipeline/brand-analysis/cosrx.md`
- CLI brand crawl support
- parser tests using static HTML fixture

No database migration or OpenAPI contract is changed.
