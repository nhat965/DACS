# Wave 1 — five official brands

This Wave intentionally favors official sources with rich product semantics for recommendation and chatbot/RAG use. Raw values are captured first; normalization and quality gating happen only after crawl.

## 1. COSRX
- Source: https://www.cosrx.com
- Discovery: official Shop All + category/concern collections.
- Product pattern: `/products/{handle}`.
- Strong fields: name, price, description, INCI, key ingredients, usage, image, collection/category/concern evidence.
- Adapter: dedicated `CosrxCrawler` because collection metadata is useful for semantic normalization.

## 2. CeraVe
- Source: https://www.cerave.com
- Discovery: sitemap first, `/skincare` fallback.
- Product families are organized under paths such as cleansers, moisturizers and facial serums.
- Strong fields on official PDPs: full ingredients, key ingredients, usage and, for many products, comparison data containing skin type, concern, benefits and texture.
- Risk: comparison tables can mention other products; parser/validator must not use recommendation/comparison rows as the current product without a clear heading boundary.

## 3. The Ordinary
- Source: https://theordinary.com/en-us
- Discovery: sitemap + skincare category fallback.
- Product pattern uses numeric `.html` product identifiers.
- Strong fields: price/currency, volume, description/targets and full ingredients.
- Risk: regional URLs/currency and editorial/category pages. Discovery uses numeric product-page pattern and excludes categories/guides.

## 4. La Roche-Posay
- Source: https://www.laroche-posay.us
- Discovery: sitemap + official product listing fallbacks.
- Product pages commonly expose benefits, recommended skin concern/type, key ingredients, full ingredient list and how-to-use instructions.
- Risk: bundles/routines may be present in the product tree; quality gate and category mapping prevent uncertain records from production import.

## 5. Paula's Choice
- Source: https://www.paulaschoice.com
- Discovery: sitemap + skincare listing fallback.
- Product pattern is restricted to product URLs ending in a numeric `.html` identifier.
- Intended strong fields: description, benefits, ingredients, usage, price and images.
- Risk: extensive editorial/ingredient-dictionary content; those URL families are explicitly excluded.

## Import policy
Only records that are both `production_candidate=true` and `ai_ready=true`, have SKU, normalized category and price, and pass the configured currency guard can be inserted into MySQL. Inserts use `status=DRAFT` and `stock_quantity=0`; existing SKU/source URL rows are skipped rather than overwritten.
