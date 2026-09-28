"""Config-driven official-brand crawler.

This module deliberately captures source-faithful raw values. It does not invent
production enums. Brand configs are reviewed individually in docs/data-pipeline/brand-analysis/.
"""
from __future__ import annotations

import html as html_lib
import json
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urljoin, urlsplit

from bs4 import BeautifulSoup

from data_pipeline.crawler.base import Checkpoint, CrawlPolicy, RateLimitedHttpClient
from data_pipeline.exporter.csv_exporter import write_csv
from data_pipeline.exporter.json_exporter import write_json


@dataclass(frozen=True)
class OfficialBrandConfig:
    slug: str
    brand_name: str
    base_url: str
    official_url: str
    sitemap_urls: tuple[str, ...] = ('/sitemap.xml',)
    listing_urls: tuple[str, ...] = ()
    product_path_patterns: tuple[str, ...] = ()
    exclude_url_patterns: tuple[str, ...] = ()
    category_path_map: dict[str, str] = field(default_factory=dict)
    section_headings: dict[str, tuple[str, ...]] = field(default_factory=dict)
    max_sitemaps: int = 80
    max_listing_pages: int = 80
    max_products: int | None = None


def _clean(value: Any) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str):
        value = str(value)
    value = html_lib.unescape(re.sub(r'\s+', ' ', value)).strip()
    return value or None


def _jsonld_products(soup: BeautifulSoup) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    for node in soup.select('script[type="application/ld+json"]'):
        text = node.string or node.get_text('', strip=True)
        if not text:
            continue
        try:
            payload = json.loads(text)
        except Exception:
            continue
        queue = payload if isinstance(payload, list) else [payload]
        for value in queue:
            if not isinstance(value, dict):
                continue
            if str(value.get('@type', '')).lower() == 'product':
                found.append(value)
            graph = value.get('@graph')
            if isinstance(graph, list):
                found.extend(x for x in graph if isinstance(x, dict) and str(x.get('@type', '')).lower() == 'product')
    return found


def _section(soup: BeautifulSoup, headings: tuple[str, ...], limit: int = 10000) -> str | None:
    wanted = [re.sub(r'\s+', ' ', h).strip().lower() for h in headings]
    if not wanted:
        return None
    for tag in soup.find_all(['h2', 'h3', 'h4', 'h5', 'summary', 'button', 'strong', 'dt']):
        label = re.sub(r'\s+', ' ', tag.get_text(' ', strip=True)).strip().lower().rstrip(':')
        if not any(label == x.rstrip(':') or label.startswith(x.rstrip(':')) for x in wanted):
            continue
        chunks: list[str] = []
        parent = tag.parent
        if parent:
            for child in parent.find_all(['p', 'li', 'div', 'dd'], recursive=True):
                text = _clean(child.get_text(' ', strip=True))
                if text and text.lower() != label and text not in chunks:
                    chunks.append(text)
                if len('\n'.join(chunks)) >= limit:
                    break
        if chunks:
            return '\n'.join(chunks)[:limit]
        # Sibling fallback for plain document layouts.
        for sibling in tag.next_siblings:
            name = getattr(sibling, 'name', None)
            if name in {'h1', 'h2', 'h3', 'h4'}:
                break
            text = _clean(sibling.get_text(' ', strip=True) if hasattr(sibling, 'get_text') else str(sibling))
            if text:
                chunks.append(text)
            if len('\n'.join(chunks)) >= limit:
                break
        if chunks:
            return '\n'.join(chunks)[:limit]
    return None


def _meta(soup: BeautifulSoup, *names: str) -> str | None:
    for name in names:
        node = soup.find('meta', attrs={'property': name}) or soup.find('meta', attrs={'name': name})
        if node and node.get('content'):
            return _clean(node.get('content'))
    return None


def _breadcrumb_category(soup: BeautifulSoup) -> str | None:
    candidates: list[str] = []
    for sel in ('nav[aria-label*="breadcrumb" i] a', '.breadcrumb a', '[class*="breadcrumb" i] a'):
        for a in soup.select(sel):
            text = _clean(a.get_text(' ', strip=True))
            if text:
                candidates.append(text)
    generic = {'home', 'shop', 'products', 'skincare', 'skin care'}
    for text in reversed(candidates):
        if text.lower() not in generic:
            return text
    return None


def _category_from_url(url: str, mapping: dict[str, str]) -> str | None:
    path = urlsplit(url).path.lower()
    for needle, code in mapping.items():
        if needle.lower() in path:
            return code
    return None


def _extract_volume(text: str) -> str | None:
    patterns = (
        r'(?i)(?:size|volume|net\s*(?:wt|weight)?)\s*[:|]?\s*((?:\d+(?:[.,]\d+)?\s*(?:ml|mL|g|kg|fl\.?\s*oz|oz))(?:\s*/\s*\d+(?:[.,]\d+)?\s*(?:ml|g|fl\.?\s*oz|oz))?)',
        r'(?i)\b(\d+(?:[.,]\d+)?\s*(?:ml|mL|g|fl\.?\s*oz))\b',
    )
    for pattern in patterns:
        m = re.search(pattern, text)
        if m:
            return _clean(m.group(1))
    return None


def parse_official_product_html(config: OfficialBrandConfig, url: str, html_text: str) -> dict[str, Any]:
    soup = BeautifulSoup(html_text, 'html.parser')
    products = _jsonld_products(soup)
    product = products[0] if products else {}
    h1 = soup.find('h1')
    name = _clean(product.get('name')) or (_clean(h1.get_text(' ', strip=True)) if h1 else None) or _meta(soup, 'og:title')
    offers = product.get('offers')
    offer = offers[0] if isinstance(offers, list) and offers else offers if isinstance(offers, dict) else {}
    price = _clean(offer.get('price') if isinstance(offer, dict) else None) or _meta(soup, 'product:price:amount')
    currency = _clean(offer.get('priceCurrency') if isinstance(offer, dict) else None) or _meta(soup, 'product:price:currency')
    sku = _clean(product.get('sku'))
    description = (
        _clean(product.get('description'))
        or _section(soup, config.section_headings.get('description', ()), limit=4000)
        or _meta(soup, 'og:description', 'description')
    )

    images_raw = product.get('image')
    if isinstance(images_raw, str):
        images = [urljoin(config.base_url, images_raw)]
    elif isinstance(images_raw, list):
        images = [urljoin(config.base_url, str(x)) for x in images_raw if x]
    else:
        og_img = _meta(soup, 'og:image')
        images = [urljoin(config.base_url, og_img)] if og_img else []
    images = list(dict.fromkeys(x for x in images if x))

    headings = config.section_headings
    ingredients = _section(soup, headings.get('ingredients', ('Ingredients', 'Ingredient List', 'Full Ingredients')))
    key_ingredients = _section(soup, headings.get('key_ingredients', ('Key Ingredients', 'Highlighted Ingredients')))
    usage = _section(soup, headings.get('usage', ('How to Use', 'How To Use', 'Directions')))
    warnings = _section(soup, headings.get('warnings', ('Warnings', 'Caution', 'Cautions', 'Precautions')))
    benefits = _section(soup, headings.get('benefits', ('Benefits', 'Key Benefits', 'Features & Benefits', 'Key Features & Benefits')))
    skin_types = _section(soup, headings.get('skin_types', ('Skin Type', 'Skin Types', 'Suitable For')))
    concerns = _section(soup, headings.get('concerns', ('Concern', 'Concerns', 'Skin Concerns')))
    texture = _section(soup, headings.get('texture', ('Texture',)))

    page_text = soup.get_text('\n', strip=True)
    volume = _extract_volume(page_text)
    category = _category_from_url(url, config.category_path_map) or _breadcrumb_category(soup)
    availability = None
    if isinstance(offer, dict) and offer.get('availability'):
        availability = str(offer.get('availability')).rsplit('/', 1)[-1]

    return {
        'product_name_raw': name,
        'sku_raw': sku,
        'brand_raw': config.brand_name,
        'category_raw': category,
        'price_raw': price,
        'sale_price_raw': None,
        'currency_raw': currency,
        'volume_raw': volume,
        'description_raw': description,
        'benefits_raw': benefits,
        'ingredients_raw': ingredients,
        'key_ingredients_raw': key_ingredients,
        'skin_types_raw': skin_types,
        'skin_concerns_raw': concerns,
        'care_goals_raw': None,
        'texture_raw': texture,
        'usage_raw': usage,
        'warnings_raw': warnings,
        'image_urls_raw': images,
        'availability_raw': availability,
        'product_url': url,
        'canonical_url': url.split('#', 1)[0],
        'source_name': f'{config.brand_name} Official',
        'source_type': 'official_brand',
        'crawled_at': datetime.now(timezone.utc).isoformat(),
        'extra_attributes': {
            'jsonld_present': bool(products),
            'raw_product_type': product.get('category') if isinstance(product, dict) else None,
            'gtin': product.get('gtin') or product.get('gtin13') or product.get('gtin12') if isinstance(product, dict) else None,
            'mpn': product.get('mpn') if isinstance(product, dict) else None,
        },
    }


class GenericOfficialCrawler:
    def __init__(self, repo_root: Path, config: OfficialBrandConfig, http: RateLimitedHttpClient | None = None):
        self.repo_root = repo_root
        self.config = config
        self.http = http or RateLimitedHttpClient(CrawlPolicy(min_delay_seconds=1.0))
        self.checkpoint = Checkpoint(repo_root / 'datasets' / 'checkpoints' / f'{config.slug}.json')
        self.raw_dir = repo_root / 'datasets' / 'raw' / config.slug
        self.html_dir = self.raw_dir / 'html'

    def _is_product_url(self, url: str) -> bool:
        if not url.startswith(('http://', 'https://')):
            return False
        if urlsplit(url).netloc.lower().replace('www.', '') != urlsplit(self.config.base_url).netloc.lower().replace('www.', ''):
            return False
        if self.config.exclude_url_patterns and any(re.search(p, url, flags=re.I) for p in self.config.exclude_url_patterns):
            return False
        return any(re.search(p, url, flags=re.I) for p in self.config.product_path_patterns)

    def _read_sitemap(self, url: str, seen: set[str], products: set[str], count: list[int]) -> None:
        if url in seen or count[0] >= self.config.max_sitemaps:
            return
        seen.add(url)
        count[0] += 1
        try:
            _, body = self.http.get_text(url)
            root = ET.fromstring(body)
        except Exception:
            return
        locs = [(_clean(node.text) or '') for node in root.findall('.//{*}loc')]
        root_name = root.tag.rsplit('}', 1)[-1].lower()
        if root_name == 'sitemapindex':
            prioritized = sorted(locs, key=lambda x: (0 if re.search(r'product|shop|skin', x, re.I) else 1, x))
            for child in prioritized:
                if child:
                    self._read_sitemap(child, seen, products, count)
        else:
            for loc in locs:
                clean = loc.split('#', 1)[0]
                if self._is_product_url(clean):
                    products.add(clean)

    def _is_listing_url(self, url: str) -> bool:
        if not url.startswith(('http://', 'https://')):
            return False
        if urlsplit(url).netloc.lower().replace('www.', '') != urlsplit(self.config.base_url).netloc.lower().replace('www.', ''):
            return False
        if self._is_product_url(url):
            return False
        path = urlsplit(url).path.lower()
        if self.config.exclude_url_patterns and any(re.search(p, url, flags=re.I) for p in self.config.exclude_url_patterns):
            return False
        listing_terms = (
            'product', 'products', 'skincare', 'skin-care', 'face', 'body',
            'cleanser', 'cleansers', 'moistur', 'serum', 'toner', 'sunscreen',
            'sun', 'mask', 'exfol', 'eye', 'lip', 'collection', 'collections',
        )
        return any(term in path for term in listing_terms)

    def discover_product_urls(self) -> list[str]:
        products = set(self.checkpoint.data.get('discovered_urls', []))
        listing_queue = [urljoin(self.config.base_url, listing) for listing in self.config.listing_urls]
        listing_seen = set(self.checkpoint.data.get('listing_pages_visited', []))
        seen: set[str] = set()
        count = [0]
        for sitemap in self.config.sitemap_urls:
            self._read_sitemap(urljoin(self.config.base_url, sitemap), seen, products, count)
        while listing_queue and len(listing_seen) < self.config.max_listing_pages:
            listing_url = listing_queue.pop(0).split('#', 1)[0]
            if listing_url in listing_seen:
                continue
            listing_seen.add(listing_url)
            try:
                _, body = self.http.get_text(listing_url)
            except Exception:
                continue
            soup = BeautifulSoup(body, 'html.parser')
            for a in soup.find_all('a', href=True):
                candidate = urljoin(self.config.base_url, a['href']).split('#', 1)[0]
                if self._is_product_url(candidate):
                    products.add(candidate)
                elif self._is_listing_url(candidate) and candidate not in listing_seen and candidate not in listing_queue:
                    listing_queue.append(candidate)
        ordered = sorted(products)
        if self.config.max_products:
            ordered = ordered[: self.config.max_products]
        self.checkpoint.data['discovered_urls'] = ordered
        self.checkpoint.data['sitemaps_visited'] = sorted(seen)
        self.checkpoint.data['listing_pages_visited'] = sorted(listing_seen)
        self.checkpoint.save()
        return ordered

    def crawl(self) -> dict[str, Any]:
        urls = self.discover_product_urls()
        self.html_dir.mkdir(parents=True, exist_ok=True)
        products_path = self.raw_dir / 'products.json'
        csv_path = self.raw_dir / 'products.csv'
        crawled = set(self.checkpoint.data.get('crawled_urls', []))
        failed = self.checkpoint.data.get('failed_urls', []) or []
        existing: list[dict[str, Any]] = []
        if products_path.exists():
            try:
                payload = json.loads(products_path.read_text(encoding='utf-8'))
                existing = payload if isinstance(payload, list) else payload.get('products', [])
            except Exception:
                existing = []
        by_url = {p.get('product_url'): p for p in existing if isinstance(p, dict) and p.get('product_url')}

        for index, url in enumerate(urls, start=1):
            if url in crawled:
                continue
            try:
                status, body = self.http.get_text(url)
                safe = re.sub(r'[^a-zA-Z0-9._-]+', '-', urlsplit(url).path.strip('/'))[-180:] or f'product-{index}'
                html_path = self.html_dir / f'{safe}.html'
                html_path.write_text(body, encoding='utf-8')
                record = parse_official_product_html(self.config, url, body)
                record['raw_html_path'] = str(html_path.relative_to(self.repo_root))
                record['http_status'] = status
                by_url[url] = record
                crawled.add(url)
                failed = [x for x in failed if not (isinstance(x, dict) and x.get('url') == url)]
            except Exception as exc:
                failed.append({
                    'url': url,
                    'status_code': None,
                    'error_type': type(exc).__name__,
                    'error_message': str(exc),
                    'retry_count': self.http.policy.max_retries,
                    'timestamp': datetime.now(timezone.utc).isoformat(),
                })
            current = list(by_url.values())
            write_json(products_path, current)
            write_csv(csv_path, current)
            self.checkpoint.data.update({'crawled_urls': sorted(crawled), 'failed_urls': failed, 'cursor': {'index': index, 'total': len(urls)}})
            self.checkpoint.save()

        records = list(by_url.values())
        write_json(products_path, records)
        write_csv(csv_path, records)
        return {
            'brand': self.config.slug,
            'discovered_urls': len(urls),
            'crawled_success': len(records),
            'failed_urls': len(failed),
            'raw_json': str(products_path.relative_to(self.repo_root)),
            'raw_csv': str(csv_path.relative_to(self.repo_root)),
        }
