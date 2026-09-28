"""Generic crawler infrastructure only.

Brand-specific selectors/discovery adapters MUST NOT be added before completing
that brand's website analysis checklist.
"""
from __future__ import annotations

import json
import random
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


@dataclass(frozen=True)
class CrawlPolicy:
    timeout_seconds: float = 20.0
    max_retries: int = 4
    base_backoff_seconds: float = 1.0
    min_delay_seconds: float = 0.8
    user_agent: str = "DACS-CosmeticDataPipeline/0.1 (+academic-project)"


class Checkpoint:
    def __init__(self, path: Path):
        self.path = path
        self.data: dict[str, Any] = {
            "discovered_urls": [],
            "crawled_urls": [],
            "failed_urls": [],
            "cursor": None,
        }
        if path.exists():
            with path.open("r", encoding="utf-8") as fh:
                self.data.update(json.load(fh))

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        with tmp.open("w", encoding="utf-8") as fh:
            json.dump(self.data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        tmp.replace(self.path)


class RateLimitedHttpClient:
    def __init__(self, policy: CrawlPolicy | None = None, sleep: Callable[[float], None] = time.sleep):
        self.policy = policy or CrawlPolicy()
        self._sleep = sleep
        self._last_request_at = 0.0

    def _rate_limit(self) -> None:
        wait = self.policy.min_delay_seconds - (time.monotonic() - self._last_request_at)
        if wait > 0:
            self._sleep(wait)

    def get_text(self, url: str) -> tuple[int, str]:
        last_error: Exception | None = None
        for attempt in range(self.policy.max_retries + 1):
            try:
                self._rate_limit()
                request = Request(url, headers={"User-Agent": self.policy.user_agent})
                with urlopen(request, timeout=self.policy.timeout_seconds) as response:  # nosec B310 - URLs are brand configs, reviewed before adapter implementation.
                    self._last_request_at = time.monotonic()
                    status = getattr(response, "status", 200)
                    body = response.read().decode(response.headers.get_content_charset() or "utf-8", errors="replace")
                    return status, body
            except (HTTPError, URLError, TimeoutError) as exc:
                last_error = exc
                if attempt >= self.policy.max_retries:
                    break
                backoff = self.policy.base_backoff_seconds * (2 ** attempt) + random.uniform(0, 0.25)
                self._sleep(backoff)
        raise RuntimeError(f"GET failed after retries: {url}: {last_error}")
