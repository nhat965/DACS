"""COSRX official-store crawler adapter.

Analysis completed before implementation (see docs/data-pipeline/brand-analysis/cosrx.md).
The adapter is intentionally source-faithful: it captures raw values and does not
invent production enums or semantic claims.
"""
from __future__ import annotations

import html
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from data_pipeline.crawler.base import Checkpoint, CrawlPolicy, RateLimitedHttpClient
from data_pipeline.exporter.json_exporter import write_json
from data_pipeline.exporter.csv_exporter import write_csv


COSRX_BASE_URL = "https://www.cosrx.com"
COSRX_ALL_COLLECTION = f"{COSRX_BASE_URL}/collections/all"

# Only deterministic mappings observed in the official site's own collection labels
# are used here. Semantic skin concern / goal mapping stays in the normalizer layer.
COLLECTION_CATEGORY_MAP: dict[str, str] = {
    "cleansers": "cleanser",
    "toners": "toner",
    "serums-essences": "serum",
    "moisturizers": "moisturizer",
    "sun-care": "sunscreen",
    "exfoliants": "exfoliant",
    "masks": "mask",
    "eye-care": "eye_care",
    "lip-care": "lip_care",
    "body-care": "body_care",
}

# Official site concern collection → raw domain values. They are captured as source
# evidence; normalization to the immutable enum remains conservative downstream.
CONCERN_COLLECTIONS: dict[str, str] = {
    "acne-blemishes": "acne",
    "dryness": "dryness",
    "redness-sensitivity": "sensitivity",
    "pores-oil-control": "large_pores;oiliness",
    "dullness-uneven-tone": "dullness;dark_spot",
    "fine-lines-wrinkles": "aging",
}


@dataclass(frozen=True)
class CosrxCrawlConfig:
    brand_slug: str = "cosrx"
    brand_name: str = "COSRX"
    source_type: str = "official_brand"
    discovery_limit_pages: int = 20


def _absolute(url: str | None) -> str | None:
    if not url:
        return None
    return urljoin(COSRX_BASE_URL, url)


def _canonical_product_url(url: str | None) -> str | None:
    absolute = _absolute(url)
    if not absolute:
        return None
    m = re.search(r"/products/([^/?#]+)", absolute)
    if not m:
        return absolute.split("?", 1)[0]
    return f"{COSRX_BASE_URL}/products/{m.group(1)}"

def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    value = html.unescape(re.sub(r"\s+", " ", value)).strip()
    return value or None


def _money_from_jsonld(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, (str, int, float)):
        return str(value)
    return None


def _jsonld_products(soup: BeautifulSoup) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    for node in soup.select('script[type="application/ld+json"]'):
        text = node.string or node.get_text("", strip=True)
        if not text:
            continue
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            continue
        values = payload if isinstance(payload, list) else [payload]
        for value in values:
            if not isinstance(value, dict):
                continue
            if value.get("@type") == "Product":
                found.append(value)
            graph = value.get("@graph")
            if isinstance(graph, list):
                found.extend(x for x in graph if isinstance(x, dict) and x.get("@type") == "Product")
    return found


def _heading_section_text(soup: BeautifulSoup, headings: tuple[str, ...]) -> str | None:
    """Extract text after an exact/near heading until the next major heading.

    This is deliberately conservative and returns None when a section cannot be
    isolated. It does not infer text from unrelated marketing/recommendation blocks.
    """
    wanted = {re.sub(r"\s+", " ", h).strip().lower() for h in headings}
    for tag in soup.find_all(["h2", "h3", "h4", "summary", "button"]):
        label = re.sub(r"\s+", " ", tag.get_text(" ", strip=True)).strip().lower()
        if label not in wanted:
            continue
        chunks: list[str] = []
        # Common accordion structure: heading/summary and nearby panel.
        parent = tag.parent
        if parent:
            for child in parent.find_all(["p", "li", "div"], recursive=True):
                if child is tag or tag in getattr(child, "parents", []):
                    continue
                text = _clean(child.get_text(" ", strip=True))
                if text and text.lower() != label and text not in chunks:
                    chunks.append(text)
                if len(" ".join(chunks)) > 5000:
                    break
        if chunks:
            return "\n".join(chunks)
    return None


def parse_cosrx_product_html(url: str, html_text: str, category_hint: str | None = None,
                             concern_hints: list[str] | None = None) -> dict[str, Any]:
    soup = BeautifulSoup(html_text, "html.parser")
    jsonld = _jsonld_products(soup)
    product = jsonld[0] if jsonld else {}

    h1 = soup.find("h1")
    name = _clean(product.get("name") if isinstance(product.get("name"), str) else (h1.get_text(" ", strip=True) if h1 else None))

    offers = product.get("offers")
    offer = offers[0] if isinstance(offers, list) and offers else offers if isinstance(offers, dict) else {}
    price = _money_from_jsonld(offer.get("price") if isinstance(offer, dict) else None)
    sku = _clean(product.get("sku") if isinstance(product.get("sku"), str) else None)

    images_raw = product.get("image")
    if isinstance(images_raw, str):
        images = [_absolute(images_raw)]
    elif isinstance(images_raw, list):
        images = [_absolute(str(x)) for x in images_raw if x]
    else:
        images = []
    images = [x for x in images if x]

    description = _clean(product.get("description") if isinstance(product.get("description"), str) else None)
    ingredients = _heading_section_text(soup, ("Ingredient List", "Ingredients", "Full Ingredients"))
    usage = _heading_section_text(soup, ("How to Use", "How To Use"))
    warnings = _heading_section_text(soup, ("Warnings", "Caution", "Cautions"))
    key_ingredients = _heading_section_text(soup, ("KEY INGREDIENTS", "Key Ingredients"))
    benefits = _heading_section_text(soup, ("Concerns & Benefits", "Benefits"))

    page_text = soup.get_text("\n", strip=True)
    suitability_text = f"{description or ''}\n{page_text}".lower()
    volume_match = re.search(r"(?i)(?:Volume|Size)\s*[:|]?\s*((?:\d+(?:\.\d+)?\s*(?:mL|ml|g|fl\.?\s*oz)(?:\s*/\s*)?)+)", page_text)
    volume = _clean(volume_match.group(1)) if volume_match else None

    # Capture explicit skin suitability text only when the page says it.
    skin_types_raw: list[str] = []
    for raw, enum in (("all skin types", "normal;dry;oily;combination;sensitive"),
                      ("sensitive skin", "sensitive"), ("dry skin", "dry"),
                      ("oily skin", "oily"), ("combination skin", "combination"),
                      ("normal skin", "normal")):
        if raw in suitability_text:
            skin_types_raw.extend(enum.split(";"))
    skin_types_text = ";".join(dict.fromkeys(skin_types_raw)) or None

    availability = None
    if isinstance(offer, dict) and offer.get("availability"):
        availability = str(offer.get("availability")).rsplit("/", 1)[-1]

    return {
        "product_name_raw": name,
        "sku_raw": sku,
        "brand_raw": "COSRX",
        "category_raw": category_hint,
        "price_raw": price,
        "sale_price_raw": None,
        "currency_raw": _clean(offer.get("priceCurrency") if isinstance(offer, dict) else None),
        "volume_raw": volume,
        "description_raw": description,
        "benefits_raw": benefits,
        "ingredients_raw": ingredients,
        "key_ingredients_raw": key_ingredients,
        "skin_types_raw": skin_types_text,
        "skin_concerns_raw": ";".join(concern_hints or []) or None,
        "care_goals_raw": None,
        "texture_raw": None,
        "usage_raw": usage,
        "warnings_raw": warnings,
        "image_urls_raw": images,
        "availability_raw": availability,
        "product_url": url,
        "canonical_url": _canonical_product_url(url),
        "source_name": "COSRX Official",
        "source_type": "official_brand",
        "crawled_at": datetime.now(timezone.utc).isoformat(),
        "extra_attributes": {
            "jsonld_present": bool(jsonld),
            "raw_product_type": product.get("category") if isinstance(product, dict) else None,
        },
    }


class CosrxCrawler:
    def __init__(self, repo_root: Path, http: RateLimitedHttpClient | None = None,
                 config: CosrxCrawlConfig | None = None):
        self.repo_root = repo_root
        self.config = config or CosrxCrawlConfig()
        self.http = http or RateLimitedHttpClient(CrawlPolicy(min_delay_seconds=1.0))
        self.checkpoint = Checkpoint(repo_root / "datasets" / "checkpoints" / "cosrx.json")
        self.raw_dir = repo_root / "datasets" / "raw" / self.config.brand_slug
        self.html_dir = self.raw_dir / "html"

    def discover_product_urls(self) -> tuple[list[str], dict[str, str], dict[str, list[str]]]:
        urls: set[str] = set(self.checkpoint.data.get("discovered_urls", []))
        category_by_url: dict[str, str] = self.checkpoint.data.get("category_by_url", {}) or {}
        concerns_by_url: dict[str, list[str]] = self.checkpoint.data.get("concerns_by_url", {}) or {}

        # Use the official Shop All listing as the primary coverage source. The site
        # currently exposes all products in this collection; page iteration is kept
        # because Shopify themes commonly paginate.
        for page in range(1, self.config.discovery_limit_pages + 1):
            listing_url = f"{COSRX_ALL_COLLECTION}?page={page}"
            _, body = self.http.get_text(listing_url)
            soup = BeautifulSoup(body, "html.parser")
            before = len(urls)
            for a in soup.select('a[href*="/products/"]'):
                href = a.get("href")
                if not href:
                    continue
                absolute = _canonical_product_url(href)
                if absolute and "/products/" in absolute:
                    urls.add(absolute)
            if len(urls) == before and page > 1:
                break

        # Category and concern collection passes enrich discovery metadata only;
        # they do not create new production values.
        for handle, category in COLLECTION_CATEGORY_MAP.items():
            try:
                _, body = self.http.get_text(f"{COSRX_BASE_URL}/collections/{handle}")
            except RuntimeError:
                continue
            soup = BeautifulSoup(body, "html.parser")
            for a in soup.select('a[href*="/products/"]'):
                absolute = _canonical_product_url(a.get("href"))
                if absolute:
                    urls.add(absolute)
                    category_by_url.setdefault(absolute, category)

        for handle, concern in CONCERN_COLLECTIONS.items():
            try:
                _, body = self.http.get_text(f"{COSRX_BASE_URL}/collections/{handle}")
            except RuntimeError:
                continue
            soup = BeautifulSoup(body, "html.parser")
            for a in soup.select('a[href*="/products/"]'):
                absolute = _canonical_product_url(a.get("href"))
                if absolute:
                    urls.add(absolute)
                    values = concerns_by_url.setdefault(absolute, [])
                    for item in concern.split(";"):
                        if item not in values:
                            values.append(item)

        ordered = sorted(urls)
        self.checkpoint.data.update({
            "discovered_urls": ordered,
            "category_by_url": category_by_url,
            "concerns_by_url": concerns_by_url,
        })
        self.checkpoint.save()
        return ordered, category_by_url, concerns_by_url

    def crawl(self) -> dict[str, Any]:
        urls, category_by_url, concerns_by_url = self.discover_product_urls()
        self.html_dir.mkdir(parents=True, exist_ok=True)
        crawled = set(self.checkpoint.data.get("crawled_urls", []))
        failed = self.checkpoint.data.get("failed_urls", []) or []
        failed_urls = {x.get("url") for x in failed if isinstance(x, dict)}

        products_path = self.raw_dir / "products.json"
        csv_path = self.raw_dir / "products.csv"
        existing: list[dict[str, Any]] = []
        if products_path.exists():
            try:
                payload = json.loads(products_path.read_text(encoding="utf-8"))
                existing = payload if isinstance(payload, list) else payload.get("products", [])
            except Exception:
                existing = []
        by_url = {p.get("product_url"): p for p in existing if isinstance(p, dict) and p.get("product_url")}

        for index, url in enumerate(urls, start=1):
            if url in crawled:
                continue
            try:
                status, body = self.http.get_text(url)
                handle = url.rstrip("/").rsplit("/", 1)[-1]
                html_path = self.html_dir / f"{handle}.html"
                html_path.write_text(body, encoding="utf-8")
                record = parse_cosrx_product_html(
                    url,
                    body,
                    category_hint=category_by_url.get(url),
                    concern_hints=concerns_by_url.get(url, []),
                )
                record["raw_html_path"] = str(html_path.relative_to(self.repo_root))
                record["http_status"] = status
                by_url[url] = record
                crawled.add(url)
                failed_urls.discard(url)
                failed = [x for x in failed if not (isinstance(x, dict) and x.get("url") == url)]
            except Exception as exc:
                failed.append({
                    "url": url,
                    "status_code": None,
                    "error_type": type(exc).__name__,
                    "error_message": str(exc),
                    "retry_count": self.http.policy.max_retries,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                })
                failed_urls.add(url)

            self.checkpoint.data.update({
                "crawled_urls": sorted(crawled),
                "failed_urls": failed,
                "cursor": {"index": index, "total": len(urls)},
            })
            self.checkpoint.save()
            current = list(by_url.values())
            write_json(products_path, current)
            write_csv(csv_path, current)

        products = list(by_url.values())
        write_json(products_path, products)
        write_csv(csv_path, products)

        report = {
            "brand": self.config.brand_slug,
            "source": COSRX_BASE_URL,
            "discovered_product_urls": len(urls),
            "crawled_success": len(crawled),
            "failed": len(failed_urls),
            "raw_records": len(by_url),
            "checkpoint": str(self.checkpoint.path.relative_to(self.repo_root)),
            "raw_json": str(products_path.relative_to(self.repo_root)),
            "raw_csv": str(csv_path.relative_to(self.repo_root)),
        }
        write_json(self.repo_root / "datasets" / "reports" / "cosrx_crawl_report.json", report)
        return report
