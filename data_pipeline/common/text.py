from __future__ import annotations

import html
import re
import unicodedata
from typing import Any

_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")


def clean_text(value: Any) -> str | None:
    """Conservative text cleanup; never rewrites meaning."""
    if value is None:
        return None
    text = str(value)
    text = html.unescape(text)
    text = unicodedata.normalize("NFC", text)
    text = _TAG_RE.sub(" ", text)
    text = _WS_RE.sub(" ", text).strip()
    return text or None


def normalize_token(value: Any) -> str | None:
    text = clean_text(value)
    if not text:
        return None
    text = text.casefold()
    text = re.sub(r"[\s\-/]+", "_", text)
    text = re.sub(r"[^a-z0-9_]+", "", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text or None
