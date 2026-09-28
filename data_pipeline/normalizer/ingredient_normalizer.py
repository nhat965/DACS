from __future__ import annotations

import re
from typing import Any

from data_pipeline.common.text import clean_text


_ALIASES = {
    "vitamin b3": "niacinamide",
    "nicotinamide": "niacinamide",
    "parfum": "fragrance",
    "fragrance parfum": "fragrance",
    "aqua": "water",
}


def normalize_ingredient_name(value: Any) -> str | None:
    """Return a stable ingredient identity without discarding the source name."""
    text = clean_text(value)
    if not text:
        return None
    key = re.sub(r"[^a-z0-9]+", " ", text.casefold()).strip()
    if not key:
        return None
    if "fragrance" in key or key == "parfum":
        return "fragrance"
    if "niacinamide" in key or key in {"vitamin b3", "nicotinamide"}:
        return "niacinamide"
    return _ALIASES.get(key, key)


def parse_ingredient_list(value: Any) -> list[dict[str, Any]]:
    text = clean_text(value)
    if not text:
        return []
    mappings: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for position, raw in enumerate(re.split(r"[,;|]", text), start=1):
        raw_name = clean_text(raw)
        normalized_name = normalize_ingredient_name(raw_name)
        if not raw_name or not normalized_name:
            continue
        identity = (raw_name.casefold(), normalized_name)
        if identity in seen:
            continue
        seen.add(identity)
        mappings.append({
            "position": position,
            "raw_name": raw_name,
            "normalized_name": normalized_name,
            "inci_name": raw_name,
        })
    return mappings
