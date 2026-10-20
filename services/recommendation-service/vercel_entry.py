"""Vercel Services entrypoint for Lumi Beauty's FastAPI backend.

The public Vercel routing table forwards `/api/*` to this service and preserves
the path. Mounting the existing application keeps local routes unchanged while
making the deployed API available at `/api/...` on the same public domain as
the Flutter application.
"""

from fastapi import FastAPI

from recommendation_service.api import app as lumi_api


app = FastAPI(title="Lumi Beauty API gateway")
app.mount("/api", lumi_api)
