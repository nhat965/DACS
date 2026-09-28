from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import BehaviorEvent, Product, RecommendationContext, RecommendedProduct


REPO_ROOT = Path(__file__).resolve().parents[3]


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


@dataclass(frozen=True)
class MySQLSettings:
    host: str = "127.0.0.1"
    port: int = 3306
    user: str = "root"
    password: str = ""
    database: str = "cosmetic_ecommerce"
    enabled: bool = False

    @classmethod
    def from_env(cls, repo_root: Path = REPO_ROOT) -> "MySQLSettings":
        _load_env_file(repo_root / ".env.local")
        enabled_value = os.getenv("RECOMMENDATION_DB_ENABLED", "false").strip().lower()
        return cls(
            host=os.getenv("MYSQL_HOST", "127.0.0.1"),
            port=int(os.getenv("MYSQL_PORT", "3306")),
            user=os.getenv("MYSQL_USER", "root"),
            password=os.getenv("MYSQL_PASSWORD", ""),
            database=os.getenv("MYSQL_DATABASE", "cosmetic_ecommerce"),
            enabled=enabled_value in {"1", "true", "yes", "on"},
        )


class RecommendationDatabase:
    def __init__(self, settings: MySQLSettings):
        self.settings = settings

    @classmethod
    def from_env(cls) -> "RecommendationDatabase | None":
        settings = MySQLSettings.from_env()
        if not settings.enabled:
            return None
        return cls(settings)

    def is_available(self) -> bool:
        try:
            conn = self._connect()
            conn.close()
            return True
        except Exception:
            return False

    def load_products(self) -> tuple[Product, ...]:
        conn = self._connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT
                    p.id,
                    p.sku,
                    p.name,
                    b.name AS brand,
                    c.name AS category,
                    p.price,
                    p.currency,
                    p.description,
                    p.benefits,
                    p.inci_ingredients,
                    p.key_ingredients,
                    p.skin_types,
                    p.skin_concerns,
                    p.care_goals,
                    p.texture,
                    p.image_url,
                    p.source_url
                    ,p.stock_quantity
                    ,p.usage_instruction
                    ,p.warnings
                FROM products p
                JOIN brands b ON b.id = p.brand_id
                JOIN categories c ON c.id = p.category_id
                WHERE p.status = 'ACTIVE'
                  AND p.stock_quantity > 0
                  AND p.ai_ready = TRUE
                ORDER BY p.id
                """
            )
            return tuple(_row_to_product(row) for row in cursor.fetchall())
        finally:
            conn.close()

    def save_behavior_event(
        self,
        *,
        user_id: int | None,
        session_id: str | None,
        event: BehaviorEvent,
    ) -> dict[str, Any]:
        metadata = dict(event.metadata)
        db_product_id = self._resolve_db_product_id(event.product_id)
        if event.product_id is not None and db_product_id is None:
            raise ProductNotFoundError(event.product_id)
        occurred_at = to_utc_naive(event.occurred_at)

        conn = self._connect()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO user_behavior_events
                    (user_id, session_id, product_id, event_type, event_value, metadata, occurred_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    user_id,
                    session_id,
                    db_product_id,
                    event.event_type,
                    event.event_value,
                    json.dumps(metadata, ensure_ascii=False) if metadata else None,
                    occurred_at,
                ),
            )
            conn.commit()
            return {"stored": True, "eventId": cursor.lastrowid, "productId": db_product_id}
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def load_user_context(self, user_id: int | None) -> RecommendationContext:
        if user_id is None:
            return RecommendationContext()

        conn = self._connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT
                    COALESCE(up.skin_type, u.skin_type) AS skin_type,
                    up.skin_concerns,
                    up.care_goals,
                    up.preferred_categories,
                    up.preferred_brands,
                    up.avoid_ingredients,
                    up.budget_min,
                    up.budget_max
                    ,up.budget_currency
                FROM users u
                LEFT JOIN user_profiles up ON up.user_id = u.id
                WHERE u.id = %s
                LIMIT 1
                """,
                (user_id,),
            )
            row = cursor.fetchone()
            if not row:
                return RecommendationContext()
            return RecommendationContext(
                skin_type=row.get("skin_type"),
                skin_concerns=_parse_db_terms(row.get("skin_concerns")),
                care_goals=_parse_db_terms(row.get("care_goals")),
                preferred_categories=_parse_db_terms(row.get("preferred_categories")),
                preferred_brands=_parse_db_terms(row.get("preferred_brands")),
                avoid_ingredients=_parse_db_terms(row.get("avoid_ingredients")),
                budget_min=_float_or_none(row.get("budget_min")),
                budget_max=_float_or_none(row.get("budget_max")),
                budget_currency=str(row.get("budget_currency") or "").upper() or None,
            )
        finally:
            conn.close()

    def load_behavior_events(
        self,
        *,
        user_id: int | None,
        session_id: str | None,
        limit: int = 100,
    ) -> tuple[BehaviorEvent, ...]:
        if user_id is None and not session_id:
            return ()

        if user_id is not None:
            where_clause = "ube.user_id = %s"
            params: list[Any] = [user_id]
        elif session_id:
            where_clause = "ube.session_id = %s"
            params = [session_id]
        else:
            return ()

        conn = self._connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                f"""
                SELECT
                    ube.product_id AS db_product_id,
                    ube.event_type,
                    ube.event_value,
                    ube.metadata,
                    ube.occurred_at
                FROM user_behavior_events ube
                WHERE {where_clause}
                ORDER BY ube.occurred_at DESC
                LIMIT %s
                """,
                tuple(params + [limit]),
            )
            return tuple(_row_to_behavior_event(row) for row in cursor.fetchall())
        finally:
            conn.close()

    def save_recommendation_log(
        self,
        *,
        user_id: int | None,
        session_id: str | None,
        algorithm: str,
        request_context: dict[str, Any],
        items: tuple[RecommendedProduct, ...],
    ) -> None:
        conn = self._connect()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO recommendation_logs
                    (user_id, session_id, algorithm, request_context, result_items)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    user_id,
                    session_id,
                    algorithm,
                    json.dumps(request_context, ensure_ascii=False),
                    json.dumps(
                        [
                            {
                                "productId": item.product_id,
                                "score": item.score,
                                "reasons": list(item.reasons),
                                "status": item.status,
                                "scoreBreakdown": item.score_breakdown,
                            }
                            for item in items
                        ],
                        ensure_ascii=False,
                    ),
                ),
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def _resolve_db_product_id(self, recommendation_product_id: int | None) -> int | None:
        if recommendation_product_id is None:
            return None

        conn = self._connect()
        try:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT id FROM products WHERE id = %s LIMIT 1",
                (recommendation_product_id,),
            )
            row = cursor.fetchone()
            return int(row[0]) if row else None
        finally:
            conn.close()

    def _connect(self):
        return self.connect()

    def connect(self):
        try:
            import mysql.connector  # type: ignore
        except ImportError as exc:
            raise RuntimeError(
                "mysql-connector-python is required. Install requirements-data-pipeline.txt "
                "or services/recommendation-service/requirements.txt"
            ) from exc
        return mysql.connector.connect(
            host=self.settings.host,
            port=self.settings.port,
            user=self.settings.user,
            password=self.settings.password,
            database=self.settings.database,
            charset="utf8mb4",
            autocommit=False,
        )


def merge_context(explicit: RecommendationContext, stored: RecommendationContext) -> RecommendationContext:
    return RecommendationContext(
        skin_type=explicit.skin_type or stored.skin_type,
        skin_concerns=explicit.skin_concerns or stored.skin_concerns,
        care_goals=explicit.care_goals or stored.care_goals,
        budget_min=explicit.budget_min if explicit.budget_min is not None else stored.budget_min,
        budget_max=explicit.budget_max if explicit.budget_max is not None else stored.budget_max,
        budget_currency=explicit.budget_currency or stored.budget_currency,
        preferred_categories=explicit.preferred_categories or stored.preferred_categories,
        preferred_brands=explicit.preferred_brands or stored.preferred_brands,
        avoid_ingredients=explicit.avoid_ingredients or stored.avoid_ingredients,
    )


class ProductNotFoundError(ValueError):
    def __init__(self, product_id: int):
        super().__init__(f"Product {product_id} was not found")
        self.product_id = product_id


def to_utc_naive(value: datetime | None) -> datetime:
    if value is None:
        return datetime.now(timezone.utc).replace(tzinfo=None)
    if value.tzinfo is not None:
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


def _row_to_behavior_event(row: dict[str, Any]) -> BehaviorEvent:
    metadata = _parse_json(row.get("metadata"))
    return BehaviorEvent(
        event_type=row["event_type"],
        product_id=_int_or_none(row.get("db_product_id")),
        event_value=_float_or_none(row.get("event_value")),
        metadata=metadata,
        occurred_at=row.get("occurred_at"),
    )


def _row_to_product(row: dict[str, Any]) -> Product:
    return Product(
        product_id=int(row["id"]),
        sku=str(row.get("sku") or row["id"]),
        name=str(row.get("name") or ""),
        brand=str(row.get("brand") or ""),
        category=_normalize_category(row.get("category")),
        price=_float_or_none(row.get("price")),
        currency=str(row.get("currency") or "").upper() or None,
        description=str(row.get("description") or ""),
        benefits=str(row.get("benefits") or ""),
        inci_ingredients=str(row.get("inci_ingredients") or ""),
        key_ingredients=str(row.get("key_ingredients") or ""),
        skin_types=_parse_db_terms(row.get("skin_types")),
        skin_concerns=_parse_db_terms(row.get("skin_concerns")),
        care_goals=_parse_db_terms(row.get("care_goals")),
        texture=str(row.get("texture") or ""),
        image_url=str(row.get("image_url") or ""),
        source_url=str(row.get("source_url") or ""),
        stock_quantity=_int_or_none(row.get("stock_quantity")),
        usage_instruction=str(row.get("usage_instruction") or ""),
        warnings=str(row.get("warnings") or ""),
    )


def _parse_json(value: Any) -> dict[str, Any]:
    if not value:
        return {}
    if isinstance(value, dict):
        return value
    try:
        parsed = json.loads(value)
        return parsed if isinstance(parsed, dict) else {}
    except (TypeError, json.JSONDecodeError):
        return {}


def _parse_db_terms(value: Any) -> tuple[str, ...]:
    if not value:
        return ()
    if isinstance(value, (list, tuple, set)):
        raw_terms = value
    else:
        raw_terms = str(value).replace("|", ",").replace(";", ",").split(",")
    return tuple(term.strip().lower() for term in raw_terms if term.strip())


def _normalize_category(value: Any) -> str:
    return str(value or "").strip().lower().replace(" ", "_")


def _int_or_none(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _float_or_none(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
