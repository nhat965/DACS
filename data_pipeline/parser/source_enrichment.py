from __future__ import annotations

import re
from copy import deepcopy
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


def _text(v: Any) -> str:
    return str(v or "").strip()


def _merge_tokens(existing: Any, additions: list[str]) -> str | None:
    vals: list[str] = []
    if existing:
        vals.extend(x.strip() for x in re.split(r"[;|]", str(existing)) if x.strip())
    for x in additions:
        if x and x not in vals:
            vals.append(x)
    return ";".join(vals) or None


def _read_raw_html(repo_root: Path | None, raw: dict[str, Any]) -> str:
    if repo_root is None:
        return ""
    raw_path = raw.get("raw_html_path")
    if not raw_path:
        return ""
    path = repo_root / str(raw_path)
    if not path.exists() or not path.is_file():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _html_text(value: str) -> str:
    text = re.sub(r"\\u003c/?[^>]+?\\u003e", " ", value)
    text = re.sub(r"<[^>]+>", " ", text)
    text = text.replace("\\u0026amp;", "&").replace("&amp;", "&")
    return re.sub(r"\s+", " ", text).strip()


def _focused_product_html(html: str, raw: dict[str, Any], limit: int = 50000) -> str:
    if not html:
        return ""
    snippets: list[str] = []
    url = _text(raw.get("product_url"))
    handle = urlsplit(url).path.rstrip("/").rsplit("/", 1)[-1] if url else ""
    needles = []
    if handle:
        needles.extend([f'"handle":"{handle}"', f'"handle&quot;:&quot;{handle}&quot;', handle])
    needles.extend(["window.SwymProduct", "window.SwymProductInfo.product", "dataLayer.push", "data-product-sku"])
    for needle in needles:
        idx = html.find(needle)
        if idx == -1:
            continue
        start = max(0, idx - 8000)
        end = min(len(html), idx + 22000)
        snippet = html[start:end]
        if snippet not in snippets:
            snippets.append(snippet)
        if sum(len(s) for s in snippets) >= limit:
            break
    return "\n".join(snippets)[:limit]


def _between(text: str, start_patterns: tuple[str, ...], end_patterns: tuple[str, ...]) -> str | None:
    if not text:
        return None
    start = None
    for p in start_patterns:
        m = re.search(p, text, flags=re.I | re.S)
        if m and (start is None or m.end() < start):
            start = m.end()
    if start is None:
        return None
    tail = text[start:]
    end = len(tail)
    for p in end_patterns:
        m = re.search(p, tail, flags=re.I | re.S)
        if m:
            end = min(end, m.start())
    value = re.sub(r"\s+", " ", tail[:end]).strip(" \n\t:-×")
    return value or None


def _extract_full_ingredients(value: str) -> str | None:
    # Commerce themes frequently repeat accordion content. Prefer the last explicit
    # Full Ingredients block and stop before a different product-information section.
    matches = list(re.finditer(r"(?i)full\s+ingredients\s*(?:×\s*full\s+ingredients)?\s*[:\-]?\s*", value))
    if not matches:
        return None
    candidate = value[matches[-1].end():]
    candidate = re.split(
        r"(?i)\b(?:key\s+ingredients|how\s+to\s+use|directions?|warnings?|cautions?|benefits?)\b",
        candidate,
        maxsplit=1,
    )[0]
    candidate = re.sub(r"(?i)^×\s*full\s+ingredients\s*", "", candidate)
    candidate = re.sub(r"\s+", " ", candidate).strip(" ×\n\t:-")
    return candidate or None


def _extract_key_ingredients(value: str) -> str | None:
    return _between(
        value,
        (r"\bkey\s+ingredients?\b\s*[:\-]?", r"\bhero\s+ingredients?\b\s*[:\-]?"),
        (
            r"\bfull\s+ingredients?\b",
            r"\bhow\s+to\s+use\b",
            r"\bdirections?\b",
            r"\bwarnings?\b",
            r"\bcautions?\b",
            r"\bingredients?\b\s*[:\-]",
        ),
    )


def _split_source_sentences(text: str) -> list[str]:
    """Split source copy conservatively without rewriting it.

    We keep original wording and only use boundaries that are present in the source
    (punctuation/newlines or obvious commerce headings). This function is used to
    *extract* benefit claims, never to generate new claims.
    """
    if not text:
        return []
    normalized = re.sub(
        r"(?i)\s+(?=(?:WHY\s+IT(?:'S|\s+IS)\s+SPECIAL|KEY\s+BENEFITS?|BENEFITS?|WHAT\s+IT\s+DOES|HOW\s+TO\s+USE|INGREDIENTS?|CAUTIONS?|WARNINGS?)\s*:?)",
        "\n",
        text,
    )
    chunks = re.split(r"(?:\r?\n)+|(?<=[.!?])\s+(?=[A-Z0-9*#])", normalized)
    out: list[str] = []
    for chunk in chunks:
        clean = re.sub(r"\s+", " ", chunk).strip(" \t\n•-*#")
        if clean and clean not in out:
            out.append(clean)
    return out


# These are literal linguistic benefit signals. They are deliberately narrower than
# an ingredient knowledge base: a sentence is copied only when the *source itself*
# states a product action/result. No ingredient-to-benefit inference occurs here.
_BENEFIT_CUE = re.compile(
    r"(?ix)\b(?:"
    r"help(?:s|ing)?|support(?:s|ing)?|provide(?:s|ing)?|deliver(?:s|ing)?|"
    r"hydrate(?:s|d|ing)?|moisturi[sz](?:e|es|ed|ing)|sooth(?:e|es|ed|ing)|calm(?:s|ed|ing)?|"
    r"protect(?:s|ed|ing)?|strengthen(?:s|ed|ing)?|repair(?:s|ed|ing)?|restore(?:s|d|ing)?|"
    r"replenish(?:es|ed|ing)?|nourish(?:es|ed|ing)?|soften(?:s|ed|ing)?|smooth(?:s|ed|ing)?|"
    r"brighten(?:s|ed|ing)?|improve(?:s|d|ing)?|reduce(?:s|d|ing)?|minimi[sz](?:e|es|ed|ing)|"
    r"control(?:s|led|ling)?|balance(?:s|d|ing)?|refine(?:s|d|ing)?|firm(?:s|ed|ing)?|"
    r"exfoliat(?:e|es|ed|ing)|remov(?:e|es|ed|ing)|clean(?:se|ses|sed|sing)|purif(?:y|ies|ied|ying)|"
    r"absorb(?:s|ed|ing)?|prevent(?:s|ed|ing)?|target(?:s|ed|ing)?|treat(?:s|ed|ing)?|"
    r"visibl(?:e|y)|anti[- ]?aging|sun\s+protection|uva|uvb|spf\s*\d{2,3}|"
    r"skin\s+barrier|elasticity|radiance|glow|even\s+skin\s+tone|excess\s+(?:oil|sebum)"
    r")\b"
)

_NON_BENEFIT_SECTION = re.compile(
    r"(?i)^(?:how\s+to\s+use|directions?|ingredients?|full\s+ingredients?|key\s+ingredients?|warnings?|cautions?|size|quantity)\b"
)


def _extract_benefit_claims(description: str, max_claims: int = 6, max_chars: int = 1800) -> str | None:
    """Extract source-stated benefit sentences from description copy.

    Returned text is verbatim apart from whitespace normalization and heading removal.
    This intentionally does not summarize or invent product claims.
    """
    claims: list[str] = []
    for sentence in _split_source_sentences(description):
        clean = re.sub(
            r"(?i)^(?:why\s+it(?:'s|\s+is)\s+special|key\s+benefits?|benefits?|what\s+it\s+does)\s*:\s*",
            "",
            sentence,
        ).strip()
        if not clean or _NON_BENEFIT_SECTION.search(clean):
            continue
        # Exclude ingredient-list-like strings even if an ingredient name contains a cue.
        comma_count = clean.count(",")
        if comma_count >= 8 and not re.search(r"(?i)\b(?:helps?|supports?|hydrates?|soothes?|protects?|reduces?|improves?)\b", clean):
            continue
        if _BENEFIT_CUE.search(clean):
            if clean not in claims:
                claims.append(clean)
        if len(claims) >= max_claims:
            break
    if not claims:
        return None
    result = " ".join(claims)
    return result[:max_chars].strip() or None


def _explicit_category(name: str, description: str) -> str | None:
    text = f"{name} {description[:600]}".lower()
    rules = (
        (r"\b(?:makeup|make-up)\s+remov(?:er|ing)|\bmicellar\s+water\b", "makeup_remover"),
        (r"\b(?:eye\s+cream|eye\s+serum|eye\s+treatment|eye\s+patch)\b", "eye_care"),
        (r"\b(?:lip\s+balm|lip\s+mask|lip\s+treatment|lip\s+scrub|lip\s+butter|lip\s+plump)\b", "lip_care"),
        (r"\b(?:foam|gel|facial|face|deep)\s+cleanser\b|\bcleanser\b|\bface\s*wash\b|\bcleansing\s+(?:foam|gel|bar|balm|oil|water)\b|\bbody\s+wash\b", "cleanser"),
        (r"\btoner\b", "toner"),
        (r"\b(?:serum|essence|ampoule|solution|liquid)\b", "serum"),
        (r"\b(?:moisturizer|moisturiser|moisturizing\s+cream|moisturising\s+cream|face\s+cream|facial\s+cream|gel\s+cream|lotion|all\s+in\s+one\s+cream)\b", "moisturizer"),
        (r"\b(?:sunscreen|sun\s*screen|sun\s+cream|spf\s*\d{2,3})\b", "sunscreen"),
        (r"\b(?:exfoliant|exfoliator|exfoliating\s+(?:liquid|toner|treatment)|peeling\s+solution|aha|bha|salicylic\s+acid)\b", "exfoliant"),
        (r"\b(?:sheet\s+mask|face\s+mask|facial\s+mask|sleeping\s+mask|hydrogel\s+mask|eye\s+patch|acne\s+patch|pimple\s+patch|master\s+patch)\b", "mask"),
        (r"\b(?:body\s+lotion|body\s+cream|body\s+wash)\b", "body_care"),
    )
    for pattern, code in rules:
        if re.search(pattern, text, flags=re.I):
            return code
    return None


_WEAK_CATEGORY_TERMS = {
    "acne",
    "acne products",
    "atoderm",
    "bestsellers",
    "cicabio",
    "dull skin products",
    "eczema creams and products",
    "gifts",
    "hydrabio",
    "ingredient",
    "ingrown hair products",
    "our products",
    "pigmentbio",
    "product line",
    "safety concern",
    "sebium",
    "sensibio",
    "shop by step",
    "skin concern",
    "skincare for dry skin",
    "skincare for redness",
}


def _category_needs_text_override(raw_category: Any, name: str) -> bool:
    category = _text(raw_category)
    if not category:
        return True
    token = re.sub(r"\s+", " ", category.casefold()).strip()
    if token == _text(name).casefold():
        return True
    if token in _WEAK_CATEGORY_TERMS:
        return True
    return bool(re.search(r"\b(?:bundle|collection|concern|duo|kit|regimen|routine|set|stack|trio)\b", token))


_TEXTURE_RULES = (
    (r"\bcream-to-water\b|\bcream\s+to\s+water\b", "cream-to-water"),
    (r"\bgel-cream\b|\bgel\s+cream\b", "gel-cream"),
    (r"\bwater\s+gel\b", "water gel"),
    (r"\bgel\b", "gel"),
    (r"\bcream\b", "cream"),
    (r"\blotion\b", "lotion"),
    (r"\bbalm\b", "balm"),
    (r"\bfoam\b|\bfoaming\b", "foam"),
    (r"\bmist\b", "mist"),
    (r"\bmilk\b", "milk"),
    (r"\bpowder\b", "powder"),
    (r"\bpad\b|\bpads\b", "pads"),
    (r"\bpatch\b|\bpatches\b", "patch"),
    (r"\bsheet\s+mask\b", "sheet mask"),
    (r"\bclay\b", "clay"),
    (r"\bstick\b", "stick"),
    (r"\bbar\b", "bar"),
    (r"\bliquid\b", "liquid"),
    (r"\bfluid\b", "fluid"),
    (r"\bointment\b", "ointment"),
    (r"\bwipes?\b", "wipes"),
    (r"\bserum\b", "serum"),
    (r"\b(?:face|facial|cleansing|body|hair)\s+oil\b|\boil\s+(?:serum|cleanser|cleanse)\b", "oil"),
    (r"\bessence\b", "essence"),
)


def _extract_texture(*values: str) -> str | None:
    text = " ".join(v for v in values if v).lower()
    if not text:
        return None
    for pattern, texture in _TEXTURE_RULES:
        if re.search(pattern, text):
            return texture
    return None


def _explicit_semantics(text: str) -> tuple[list[str], list[str], list[str]]:
    t = text.lower()
    skin_types: list[str] = []
    concerns: list[str] = []
    goals: list[str] = []

    if re.search(r"\ball\s+skin\s+types\b|\bskin_type::all\b|\bskin type:\s*all\b", t):
        skin_types += ["normal", "dry", "oily", "combination", "sensitive"]
    else:
        range_rules = (
            (r"\bnormal\s+to\s+dry\s+skin\b", ["normal", "dry"]),
            (r"\bnormal\s+to\s+oily\s+skin\b", ["normal", "oily"]),
            (r"\bnormal\s+to\s+combination\s+skin\b", ["normal", "combination"]),
            (r"\bcombination\s+to\s+oily\s+skin\b", ["combination", "oily"]),
            (r"\bcombination\s+to\s+dry\s+skin\b", ["combination", "dry"]),
        )
        for pat, codes in range_rules:
            if re.search(pat, t):
                skin_types.extend(codes)
        for phrase, code in [
            ("normal skin", "normal"),
            ("dry skin", "dry"),
            ("oily skin", "oily"),
            ("combination skin", "combination"),
            ("sensitive skin", "sensitive"),
        ]:
            if phrase in t:
                skin_types.append(code)

    concern_rules = (
        (r"\bacne|blemish|breakout|blackheads?|whiteheads?", "acne"),
        (r"\bdark\s+spot|discoloration|post[- ]?(?:acne|blemish)\s+mark|hyperpigment", "dark_spot"),
        (r"\bdryness|very\s+dry|dehydrated|dehydration|flaky|flaking|chapped|cracked\s+skin", "dryness"),
        (r"\bfine\s+lines?|wrinkles?|aging", "aging"),
        (r"\bredness|red\s+skin|irritation", "redness"),
        (r"\blarge\s+pores?|enlarged\s+pores?|\bpores?\b", "large_pores"),
        (r"\bdullness|dull\s+skin", "dullness"),
        (r"\buneven\s+texture|rough\s+texture|rough\s+(?:and\s+)?bumpy|bumpy\s+skin", "uneven_texture"),
        (r"\bexcess\s+(?:oil|sebum)|oiliness|oily\s+shine", "oiliness"),
        (r"\bsensitivity|sensitive\s+skin|eczema|psoriasis", "sensitivity"),
    )
    for pat, code in concern_rules:
        if re.search(pat, t):
            concerns.append(code)

    goal_rules = (
        (r"\bcleanse|cleansing|removes?\s+(?:dirt|impurities|makeup)", "cleanse"),
        (r"\bhydrat|moisturiz|moisturis", "hydrate"),
        (r"\bbrighten|brightening|radiance|glow", "brighten"),
        (r"\bacne|blemish|breakout", "anti_acne"),
        (r"\banti[- ]?aging|fine\s+lines?|wrinkles?|firming|elasticity", "anti_aging"),
        (r"\brepair|skin\s+barrier|barrier\s+(?:support|restore|strengthen)|replenish(?:es|ed|ing)?\s+(?:the\s+)?(?:moisture\s+)?barrier", "repair"),
        (r"\bsooth|calm(?:s|ed|ing)?|comfort", "soothe"),
        (r"\boil\s+control|sebum\s+control|controls?\s+(?:excess\s+)?(?:oil|sebum)|reduce[s]?\s+shine", "oil_control"),
        (r"\bsun\s+protection|uva|uvb|spf\s*\d{2,3}", "sun_protection"),
        (r"\bexfoliat|dead\s+skin\s+cells?", "exfoliate"),
    )
    for pat, code in goal_rules:
        if re.search(pat, t):
            goals.append(code)
    return list(dict.fromkeys(skin_types)), list(dict.fromkeys(concerns)), list(dict.fromkeys(goals))


def _extract_tag_values(html: str, raw: dict[str, Any]) -> tuple[list[str], list[str], list[str], list[str]]:
    """Extract explicit Shopify/Liquid tag semantics from product HTML."""
    if not html:
        return [], [], [], []
    focused = _focused_product_html(html, raw)
    snippets = re.findall(r'"productTags"\s*:\s*\[(.*?)\]', focused, flags=re.I | re.S)
    snippets += re.findall(r'"tags"\s*:\s*\[(.*?)\]', focused, flags=re.I | re.S)
    tags: list[str] = []
    for snippet in snippets:
        for m in re.finditer(r'"((?:\\.|[^"])*)"', snippet):
            tag = m.group(1).replace("\\/", "/").replace("\\u0026", "&").strip()
            if tag and tag not in tags:
                tags.append(tag)

    category_tokens: list[str] = []
    skin_tokens: list[str] = []
    concern_tokens: list[str] = []
    goal_tokens: list[str] = []
    for tag in tags:
        clean = tag.replace("_", " ").replace("-", " ").strip()
        lower = clean.lower()
        if lower.startswith("skin type::"):
            skin_tokens.append(clean.split("::", 1)[1])
        elif lower.startswith("concern::"):
            concern_tokens.append(clean.split("::", 1)[1])
        elif lower.startswith("benefit::"):
            goal_tokens.append(clean.split("::", 1)[1])
        elif lower.startswith("key ingredient::") or lower.startswith("without ingredient::"):
            continue
        elif re.search(r"\b(cleanser|toner|serum|essence|moisturizer|moisturiser|cream|sunscreen|spf|mask|eye|lip|body|powder|balm|oil)\b", lower):
            category_tokens.append(clean)
    return category_tokens, skin_tokens, concern_tokens, goal_tokens


def _extract_cerave_datalayer(html: str) -> dict[str, str]:
    if not html:
        return {}
    for m in re.finditer(r"dataLayer\.push\((\{.*?\})\);", html, flags=re.S):
        payload = m.group(1)
        out: dict[str, str] = {}
        for key in ("category", "breadcrumb", "dimension35", "dimension48"):
            km = re.search(rf'"{key}"\s*:\s*"((?:\\.|[^"])*)"', payload)
            if km:
                out[key] = km.group(1).encode("utf-8").decode("unicode_escape")
        if out:
            return out
    return {}


def _extract_bioderma_product_meta(html: str) -> dict[str, str]:
    if not html:
        return {}
    out: dict[str, str] = {}
    sku = re.search(r'data-product-sku="([^"]+)"', html, flags=re.I)
    if sku:
        out["sku"] = sku.group(1)
    price = re.search(r'"xdm:price"\s*:\s*([0-9.]+)', html)
    if price:
        out["price"] = price.group(1)
    currency = re.search(r'"xdm:currencyCode"\s*:\s*"([^"]+)"', html)
    if currency:
        out["currency"] = currency.group(1)
    cats = re.findall(r'"xdm:name"\s*:\s*"([^"]+)"', html)
    if cats:
        out["categories"] = ";".join(dict.fromkeys(cats))
    return out


def _record_extraction(r: dict[str, Any], field: str, source_field: str, method: str) -> None:
    extra = r.setdefault("extra_attributes", {})
    log = extra.setdefault("semantic_extraction", {})
    log[field] = {"source_field": source_field, "method": method}


def enrich_raw_record(raw: dict[str, Any], repo_root: Path | None = None) -> dict[str, Any]:
    r = deepcopy(raw)
    brand = _text(raw.get("brand_raw")).casefold()
    html_brand_allowlist = {"cerave", "bioderma"}
    html = _read_raw_html(repo_root, raw) if brand in html_brand_allowlist else ""
    focused_html = _focused_product_html(html, raw)
    desc = _text(r.get("description_raw"))
    ing = _text(r.get("ingredients_raw"))
    usage = _text(r.get("usage_raw"))
    name = _text(r.get("product_name_raw"))
    raw_type = _text((r.get("extra_attributes") or {}).get("raw_product_type"))

    datalayer = _extract_cerave_datalayer(html)
    if datalayer:
        if not r.get("sku_raw") and datalayer.get("dimension48"):
            r["sku_raw"] = datalayer["dimension48"]
            _record_extraction(r, "sku_raw", "raw_html_path", "cerave_datalayer")
        if not r.get("volume_raw") and datalayer.get("dimension35"):
            r["volume_raw"] = datalayer["dimension35"]
            _record_extraction(r, "volume_raw", "raw_html_path", "cerave_datalayer")
        if not r.get("category_raw") and datalayer.get("category"):
            r["category_raw"] = datalayer["category"]
            _record_extraction(r, "category_raw", "raw_html_path", "cerave_datalayer")
        if datalayer.get("breadcrumb"):
            desc = f"{desc} {datalayer['breadcrumb']}".strip()

    bioderma_meta = _extract_bioderma_product_meta(html)
    if bioderma_meta:
        if not r.get("sku_raw") and bioderma_meta.get("sku"):
            r["sku_raw"] = bioderma_meta["sku"]
            _record_extraction(r, "sku_raw", "raw_html_path", "bioderma_product_meta")
        if not r.get("price_raw") and bioderma_meta.get("price"):
            r["price_raw"] = bioderma_meta["price"]
            _record_extraction(r, "price_raw", "raw_html_path", "bioderma_product_meta")
        if not r.get("currency_raw") and bioderma_meta.get("currency"):
            r["currency_raw"] = bioderma_meta["currency"]
        if bioderma_meta.get("categories") and not r.get("category_raw"):
            r["category_raw"] = bioderma_meta["categories"]

    extra = r.get("extra_attributes") or {}
    if not r.get("sku_raw") and (extra.get("gtin") or extra.get("mpn")):
        r["sku_raw"] = extra.get("gtin") or extra.get("mpn")
        _record_extraction(r, "sku_raw", "extra_attributes", "jsonld_identifier")

    tag_categories, tag_skin, tag_concerns, tag_goals = _extract_tag_values(html, raw)
    if tag_skin:
        r["skin_types_raw"] = _merge_tokens(r.get("skin_types_raw"), tag_skin)
    if tag_concerns:
        r["skin_concerns_raw"] = _merge_tokens(r.get("skin_concerns_raw"), tag_concerns)
    if tag_goals:
        r["care_goals_raw"] = _merge_tokens(r.get("care_goals_raw"), tag_goals)
    if (not r.get("category_raw") or r.get("category_raw") == name) and tag_categories:
        r["category_raw"] = _merge_tokens(None, tag_categories)
        _record_extraction(r, "category_raw", "raw_html_path", "shopify_product_tags")

    # Recover sections that the crawler captured but did not split. Every recovered
    # value remains source-derived and its origin is logged in extra_attributes.
    if ing:
        if not r.get("key_ingredients_raw"):
            key = _extract_key_ingredients(ing)
            if key:
                r["key_ingredients_raw"] = key
                _record_extraction(r, "key_ingredients_raw", "ingredients_raw", "explicit_section")
        full = _extract_full_ingredients(ing)
        if full and full != ing:
            r["ingredients_raw"] = full
            _record_extraction(r, "ingredients_raw", "ingredients_raw", "full_ingredients_section")

    if not r.get("ingredients_raw") and desc:
        full = _between(
            desc,
            (r"\b(?:full\s+)?ingredients?\b\s*[:\-]",),
            (r"\b(?:how\s+to\s+use|directions?|warnings?|cautions?)\b",),
        )
        if full:
            r["ingredients_raw"] = full
            _record_extraction(r, "ingredients_raw", "description_raw", "explicit_section")

    if not r.get("key_ingredients_raw") and desc:
        key = _extract_key_ingredients(desc)
        if key:
            r["key_ingredients_raw"] = key
            _record_extraction(r, "key_ingredients_raw", "description_raw", "explicit_section")

    if not r.get("usage_raw") and desc:
        use = _between(
            desc,
            (r"\bhow\s+to\s+use\b\s*[:\-]?", r"\bdirections?\b\s*[:\-]?"),
            (r"\bingredients?\b\s*[:\-]", r"\bwarnings?\b", r"\bcautions?\b"),
        )
        if use:
            r["usage_raw"] = use
            usage = use
            _record_extraction(r, "usage_raw", "description_raw", "explicit_section")

    # Warnings/cautions may be embedded in usage or product description.
    warning_source = _text(r.get("usage_raw")) or desc
    if not r.get("warnings_raw") and warning_source:
        warn = _between(warning_source, (r"\b(?:cautions?|warnings?|precautions?)\b\s*[:\-]?",), ())
        if warn:
            r["warnings_raw"] = warn
            _record_extraction(
                r,
                "warnings_raw",
                "usage_raw" if _text(r.get("usage_raw")) else "description_raw",
                "explicit_section",
            )
            if _text(r.get("usage_raw")):
                before = re.split(r"(?i)\b(?:cautions?|warnings?|precautions?)\b", _text(r.get("usage_raw")), maxsplit=1)[0].strip()
                if before:
                    r["usage_raw"] = before

    # Benefits: first prefer explicit commerce sections, then copy only source-stated
    # benefit sentences from description. We never write a new benefit claim.
    if not r.get("benefits_raw") and desc:
        benefits = _between(
            desc,
            (
                r"\bwhy\s+it(?:'s|\s+is)\s+special\b\s*[:\-]?",
                r"\bkey\s+benefits?\b\s*[:\-]?",
                r"\bwhat\s+it\s+does\b\s*[:\-]?",
            ),
            (r"\bhow\s+to\s+use\b", r"\bdirections?\b", r"\bingredients?\b\s*[:\-]", r"\bwarnings?\b", r"\bcautions?\b"),
        )
        if benefits:
            r["benefits_raw"] = benefits
            _record_extraction(r, "benefits_raw", "description_raw", "explicit_benefit_section")
        else:
            benefits = _extract_benefit_claims(desc)
            if benefits and benefits.casefold() != desc.casefold():
                r["benefits_raw"] = benefits
                _record_extraction(r, "benefits_raw", "description_raw", "source_claim_sentences")

    # Semantic enum evidence may come from description, explicit benefits, existing raw
    # semantic fields and usage. This is phrase normalization only, not domain inference.
    evidence = "\n".join(
        x
        for x in [
            desc,
            name,
            raw_type,
            _html_text(focused_html),
            _text(r.get("benefits_raw")),
            _text(r.get("skin_types_raw")),
            _text(r.get("skin_concerns_raw")),
            _text(r.get("care_goals_raw")),
            _text(r.get("usage_raw")),
        ]
        if x
    )
    st, sc, cg = _explicit_semantics(evidence)
    r["skin_types_raw"] = _merge_tokens(r.get("skin_types_raw"), st)
    r["skin_concerns_raw"] = _merge_tokens(r.get("skin_concerns_raw"), sc)
    r["care_goals_raw"] = _merge_tokens(r.get("care_goals_raw"), cg)
    if st:
        _record_extraction(r, "skin_types_raw", "product_text_or_html", "explicit_phrase_mapping")
    if sc:
        _record_extraction(r, "skin_concerns_raw", "product_text_or_html", "explicit_phrase_mapping")
    if cg:
        _record_extraction(r, "care_goals_raw", "product_text_or_html", "explicit_phrase_mapping")

    if not r.get("texture_raw"):
        texture = _extract_texture(name, raw_type, desc, _text(r.get("benefits_raw")), _text(r.get("image_urls_raw")), focused_html)
        if texture:
            r["texture_raw"] = texture
            _record_extraction(r, "texture_raw", "product_text_or_html", "explicit_texture_phrase")

    name_category = _explicit_category(name, "")
    if name_category in {"eye_care", "lip_care", "makeup_remover", "sunscreen", "toner"}:
        if name_category != _text(r.get("category_raw")):
            r["category_raw"] = name_category
            r.setdefault("extra_attributes", {})["category_evidence"] = "explicit_product_name"

    if _category_needs_text_override(r.get("category_raw"), name):
        explicit = _explicit_category(name, f"{raw_type} {desc} {_text(r.get('category_raw'))}")
        if explicit:
            r["category_raw"] = explicit
            r.setdefault("extra_attributes", {})["category_evidence"] = "explicit_product_text"

    r.setdefault("extra_attributes", {})["enrichment_version"] = "3.0"
    return r
