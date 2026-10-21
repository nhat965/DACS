"""Vercel entry point for the Lumi Beauty FastAPI backend.

Deploy this directory as a separate Vercel project whose Root Directory is the
repository root.  The Flutter application stays a separate static Vercel
project rooted at apps/web.
"""

from __future__ import annotations

import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = REPOSITORY_ROOT / "services" / "recommendation-service"

if str(SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(SERVICE_ROOT))

# Vercel detects this ASGI app and routes requests to the existing FastAPI
# implementation.  Secrets remain in the Vercel project environment only.
from recommendation_service.api import app  # noqa: E402
