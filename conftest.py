"""Shared test bootstrap so the complete suite runs from the repository root."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
LOCAL_SITE_PACKAGES = ROOT / ".venv" / "Lib" / "site-packages"
RECOMMENDATION_SERVICE = ROOT / "services" / "recommendation-service"

for path in (LOCAL_SITE_PACKAGES, RECOMMENDATION_SERVICE):
    if path.exists():
        sys.path.insert(0, str(path))
