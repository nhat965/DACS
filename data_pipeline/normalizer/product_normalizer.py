from __future__ import annotations

import re
from decimal import Decimal, InvalidOperation
from typing import Any, Iterable
from urllib.parse import urlsplit, urlunsplit

from data_pipeline.common.text import clean_text, normalize_token
from data_pipeline.config.contracts import CARE_GOALS, CATEGORY_CODES, SKIN_CONCERNS, SKIN_TYPES
from data_pipeline.normalizer.ingredient_normalizer import parse_ingredient_list

_PRICE_DIGITS = re.compile(r"[^0-9,\.]" )
_VOLUME_RE = re.compile(r"(?i)(\d+(?:[.,]\d+)?)\s*(ml|g|kg|l|oz|fl\.?\s*oz)\b")

# Only deterministic aliases are allowed. Ambiguous phrases must remain unmapped.
SKIN_TYPE_ALL_ALIASES = {
    "all",
    "all_skin",
    "all_skin_type",
    "all_skin_types",
}
SKIN_TYPE_ALIASES = {
    "normal": "normal", "normal_skin": "normal",
    "dry": "dry", "dry_skin": "dry",
    "very_dry": "dry", "very_dry_skin": "dry",
    "oily": "oily", "oily_skin": "oily",
    "combination": "combination", "combination_skin": "combination",
    "sensitive": "sensitive", "sensitive_skin": "sensitive",
    "blemish_prone": "oily",
    "acne_prone": "oily",
    "dehydrated": "dry",
    "dehydrated_skin": "dry",
}
SKIN_CONCERN_ALIASES = {k: k for k in SKIN_CONCERNS}
SKIN_CONCERN_ALIASES.update({
    "dark_spots": "dark_spot",
    "dark_spots_uneven_skin_tone": "dark_spot",
    "large_pore": "large_pores",
    "large_pores": "large_pores",
    "pores": "large_pores",
    "pore": "large_pores",
    "uneven_skin_texture": "uneven_texture",
    "blemish_prone": "acne",
    "blemishes": "acne",
    "acne_prone": "acne",
    "troubled": "acne",
    "troubled_skin": "acne",
    "dehydrated": "dryness",
    "dehydrated_skin": "dryness",
    "dry_skin": "dryness",
    "very_dry_skin": "dryness",
    "early_signs_aging": "aging",
    "slow_aging": "aging",
    "age_prevention": "aging",
    "sensitive_skin": "sensitivity",
    "redness": "redness",
    "dullness_uneven_skin_tone": "dullness",
    "dull_skin": "dullness",
    "oiliness": "oiliness",
})
CARE_GOAL_ALIASES = {k: k for k in CARE_GOALS}
CARE_GOAL_ALIASES.update({
    "am": "hydrate",
    "pm": "hydrate",
    "am_pm": "hydrate",
    "hydration": "hydrate",
    "brightening": "brighten",
    "glow": "brighten",
    "radiance": "brighten",
    "anti_acne_care": "anti_acne",
    "anti_aging_care": "anti_aging",
    "visibly_firms": "anti_aging",
    "firming": "anti_aging",
    "revitalizing": "anti_aging",
    "soothing": "soothe",
    "oil_control": "oil_control",
    "oil_moisture_balance": "oil_control",
    "sun_protection": "sun_protection",
    "uv_protection": "sun_protection",
    "exfoliation": "exfoliate",
    "resurface": "exfoliate",
    "resurfacing": "exfoliate",
})
CATEGORY_ALIASES = {k: k for k in CATEGORY_CODES}
CATEGORY_ALIASES.update({
    "cleanser_face_wash": "cleanser",
    "face_wash": "cleanser",
    "cleansers": "cleanser",
    "facial_cleansers": "cleanser",
    "daily_rinse_off_cleansers": "cleanser",
    "daily_cleansers": "cleanser",
    "body_wash_and_cleanser": "cleanser",
    "toners": "toner",
    "toner_essence": "toner",
    "toner_pads": "toner",
    "serums": "serum",
    "facial_serums": "serum",
    "serums_essences": "serum",
    "skincare_serums": "serum",
    "essence": "serum",
    "essences": "serum",
    "moisturiser": "moisturizer",
    "moisturisers": "moisturizer",
    "moisturizers": "moisturizer",
    "moisturizers_for_dry_skin": "moisturizer",
    "daily_skincare": "moisturizer",
    "hydration": "moisturizer",
    "sun_screen": "sunscreen",
    "sun_care": "sunscreen",
    "sunscreens": "sunscreen",
    "spf_products": "sunscreen",
    "uv_protection": "sunscreen",
    "exfoliants": "exfoliant",
    "exfoliators": "exfoliant",
    "masks": "mask",
    "sleeping_masks": "mask",
    "makeup_removers": "makeup_remover",
    "micellar_water": "makeup_remover",
    "eye_care": "eye_care",
    "eye_care_products": "eye_care",
    "eye_contour_cream": "eye_care",
    "lip_care": "lip_care",
    "lip_balm": "lip_care",
    "body_care": "body_care",
    "body": "body_care",
    "body_cream_and_care": "body_care",
    "travel_size_skincare": "body_care",
    "for_baby": "body_care",
})


def normalize_price(value: Any) -> Decimal | None:
    text = clean_text(value)
    if not text:
        return None
    cleaned = _PRICE_DIGITS.sub("", text)
    if not cleaned:
        return None
    # Cosmetic prices in VN sources commonly use separators for thousands.
    # This routine stays conservative: if both separators exist, the last one
    # is considered decimal only when followed by 1-2 digits.
    try:
        if "," in cleaned and "." in cleaned:
            last = max(cleaned.rfind(","), cleaned.rfind("."))
            tail = cleaned[last + 1 :]
            if 1 <= len(tail) <= 2:
                integer = re.sub(r"[.,]", "", cleaned[:last])
                cleaned = f"{integer}.{tail}"
            else:
                cleaned = re.sub(r"[.,]", "", cleaned)
        elif "," in cleaned or "." in cleaned:
            sep = "," if "," in cleaned else "."
            parts = cleaned.split(sep)
            if len(parts) == 2 and 1 <= len(parts[1]) <= 2:
                cleaned = f"{parts[0]}.{parts[1]}"
            else:
                cleaned = "".join(parts)
        price = Decimal(cleaned)
        return price if price >= 0 else None
    except (InvalidOperation, ValueError):
        return None


def normalize_volume(value: Any) -> str | None:
    text = clean_text(value)
    if not text:
        return None
    match = _VOLUME_RE.search(text)
    if not match:
        return None
    amount = match.group(1).replace(",", ".")
    unit = re.sub(r"[.\s]", "", match.group(2).lower())
    return f"{amount}{unit}"


def canonicalize_url(value: Any) -> str | None:
    text = clean_text(value)
    if not text:
        return None
    try:
        parts = urlsplit(text)
        if parts.scheme not in {"http", "https"} or not parts.netloc:
            return None
        # Strip fragment only; do not remove query params because some product URLs
        # genuinely identify variants with them.
        return urlunsplit((parts.scheme.lower(), parts.netloc.lower(), parts.path, parts.query, ""))
    except ValueError:
        return None


def _as_values(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(x) for x in value if x is not None]
    text = clean_text(value)
    if not text:
        return []
    return [x.strip() for x in re.split(r"[;,|/]", text) if x.strip()]


def map_enum_values(value: Any, aliases: dict[str, str], allowed: Iterable[str]) -> tuple[list[str] | None, list[str]]:
    """Map explicit source phrases conservatively.

    Exact aliases are preferred. For verbose source text (for example
    "Normal to Dry Skin; Including Sensitive Skin"), we only extract enum aliases
    that literally occur in the source phrase. This is normalization, not inference.
    """
    allowed_set = set(allowed)
    mapped: list[str] = []
    unmapped: list[str] = []
    for raw in _as_values(value):
        token = normalize_token(raw) or ""
        if aliases is SKIN_TYPE_ALIASES and token in SKIN_TYPE_ALL_ALIASES:
            for target in ("normal", "dry", "oily", "combination", "sensitive"):
                if target in allowed_set and target not in mapped:
                    mapped.append(target)
            continue
        normalized = aliases.get(token)
        if normalized and normalized in allowed_set:
            if normalized not in mapped:
                mapped.append(normalized)
            continue

        literal_hits: list[str] = []
        padded = f"_{token}_"
        for alias_token, target in aliases.items():
            if target not in allowed_set:
                continue
            needle = f"_{alias_token}_"
            if alias_token and needle in padded:
                literal_hits.append(target)
        for target in literal_hits:
            if target not in mapped:
                mapped.append(target)
        if not literal_hits:
            unmapped.append(raw)

    if not mapped and unmapped:
        return None, unmapped
    return mapped, unmapped


def normalize_product(cleaned: dict[str, Any]) -> dict[str, Any]:
    skin_types, unmapped_skin_types = map_enum_values(cleaned.get("skin_types_raw"), SKIN_TYPE_ALIASES, SKIN_TYPES)
    concerns, unmapped_concerns = map_enum_values(cleaned.get("skin_concerns_raw"), SKIN_CONCERN_ALIASES, SKIN_CONCERNS)
    goals, unmapped_goals = map_enum_values(cleaned.get("care_goals_raw"), CARE_GOAL_ALIASES, CARE_GOALS)

    category_token = normalize_token(cleaned.get("category_raw"))
    category = CATEGORY_ALIASES.get(category_token or "")
    category_unmapped = [] if category else ([cleaned.get("category_raw")] if cleaned.get("category_raw") else [])

    images = cleaned.get("image_urls_raw") or []
    primary_image = canonicalize_url(images[0]) if images else canonicalize_url(cleaned.get("image_url_raw"))

    field_source_map = {
        "sku": "sku_raw",
        "name": "product_name_raw",
        "brand_normalized": "brand_raw",
        "category_normalized": "category_raw",
        "price": "sale_price_raw" if cleaned.get("sale_price_raw") else "price_raw",
        "volume": "volume_raw",
        "description": "description_raw",
        "benefits": "benefits_raw",
        "inci_ingredients": "ingredients_raw",
        "key_ingredients": "key_ingredients_raw",
        "skin_types": "skin_types_raw",
        "skin_concerns": "skin_concerns_raw",
        "care_goals": "care_goals_raw",
        "texture": "texture_raw",
        "usage_instruction": "usage_raw",
        "warnings": "warnings_raw",
        "image_url": "image_urls_raw",
        "source_url": "product_url",
    }
    raw_source_type = clean_text(cleaned.get("source_type"))
    source_type = "manufacturer" if raw_source_type in {"official_brand", "manufacturer"} else raw_source_type
    source_info = {
        "source_url": canonicalize_url(cleaned.get("product_url")),
        "source_name": clean_text(cleaned.get("source_name")),
        "source_type": source_type,
    }
    extra = cleaned.get("extra_attributes") or {}
    extraction = extra.get("semantic_extraction") or {}
    derived_targets = {
        "skin_types", "skin_concerns", "care_goals"
    }
    field_provenance = {}
    for target, raw_field in field_source_map.items():
        if cleaned.get(raw_field) in (None, "", []):
            continue
        extraction_info = extraction.get(raw_field) or {}
        is_derived = target in derived_targets and extraction_info.get("method") == "explicit_phrase_mapping"
        if target == "category_normalized" and extra.get("category_evidence"):
            is_derived = True
        field_provenance[target] = {
            **source_info,
            "raw_field": raw_field,
            "retrieved_at": clean_text(cleaned.get("crawled_at")),
            "last_verified_at": clean_text(cleaned.get("last_verified_at") or cleaned.get("verified_at")),
            "data_class": "DERIVED" if is_derived else "FACTUAL",
            "evidence_type": "inferred" if is_derived else "explicit",
            "confidence": 0.85 if is_derived else 1.0,
            "extraction_method": extraction_info.get("method"),
        }

    currency = clean_text(cleaned.get("currency_raw"))
    currency = currency.upper() if currency else None
    ingredient_mappings = parse_ingredient_list(cleaned.get("ingredients_raw"))

    return {
        "sku": clean_text(cleaned.get("sku_raw")),
        "name": clean_text(cleaned.get("product_name_raw")),
        "brand_normalized": clean_text(cleaned.get("brand_raw")),
        "category_normalized": category,
        "price": normalize_price(cleaned.get("sale_price_raw") or cleaned.get("price_raw")),
        "currency": currency,
        "volume": normalize_volume(cleaned.get("volume_raw")),
        "description": clean_text(cleaned.get("description_raw")),
        "benefits": clean_text(cleaned.get("benefits_raw")),
        "inci_ingredients": clean_text(cleaned.get("ingredients_raw")),
        "key_ingredients": clean_text(cleaned.get("key_ingredients_raw")),
        "skin_types": skin_types,
        "skin_concerns": concerns,
        "care_goals": goals,
        "texture": clean_text(cleaned.get("texture_raw")),
        "usage_instruction": clean_text(cleaned.get("usage_raw")),
        "warnings": clean_text(cleaned.get("warnings_raw")),
        "image_url": primary_image,
        "source_url": canonicalize_url(cleaned.get("product_url")),
        "_processing": {
            "field_provenance": field_provenance,
            "source_currency": clean_text(cleaned.get("currency_raw")),
            "source_price_raw": clean_text(cleaned.get("sale_price_raw") or cleaned.get("price_raw")),
            "ingredient_mappings": ingredient_mappings,
            "retrieved_at": clean_text(cleaned.get("crawled_at")),
            "last_verified_at": clean_text(cleaned.get("last_verified_at") or cleaned.get("verified_at")),
            "unmapped_values": {
                "category": category_unmapped,
                "skin_types": unmapped_skin_types,
                "skin_concerns": unmapped_concerns,
                "care_goals": unmapped_goals,
            }
        },
    }
