from __future__ import annotations

import re


def normalize_ingredient_name(value: str) -> str | None:
    key = re.sub(r"[^a-z0-9]+", " ", str(value or "").casefold()).strip()
    if not key:
        return None
    if "fragrance" in key or key == "parfum":
        return "fragrance"
    if "niacinamide" in key or key in {"vitamin b3", "nicotinamide"}:
        return "niacinamide"
    if key == "aqua":
        return "water"
    return key


def normalized_ingredient_set(value: str) -> set[str]:
    return {
        normalized
        for raw in re.split(r"[,;|]", str(value or ""))
        if (normalized := normalize_ingredient_name(raw))
    }
