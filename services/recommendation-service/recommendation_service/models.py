from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any


@dataclass(frozen=True)
class Product:
    product_id: int
    sku: str
    name: str
    brand: str
    category: str
    price: float | None
    currency: str | None = None
    description: str = ""
    benefits: str = ""
    inci_ingredients: str = ""
    key_ingredients: str = ""
    skin_types: tuple[str, ...] = ()
    skin_concerns: tuple[str, ...] = ()
    care_goals: tuple[str, ...] = ()
    texture: str = ""
    image_url: str = ""
    source_url: str = ""
    stock_quantity: int | None = None
    usage_instruction: str = ""
    warnings: str = ""


@dataclass(frozen=True)
class BehaviorEvent:
    event_type: str
    product_id: int | None = None
    event_value: float | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
    occurred_at: datetime | None = None


@dataclass(frozen=True)
class RecommendationContext:
    skin_type: str | None = None
    skin_concerns: tuple[str, ...] = ()
    care_goals: tuple[str, ...] = ()
    budget_min: float | None = None
    budget_max: float | None = None
    budget_currency: str | None = None
    preferred_categories: tuple[str, ...] = ()
    preferred_brands: tuple[str, ...] = ()
    avoid_ingredients: tuple[str, ...] = ()


@dataclass(frozen=True)
class RecommendationRequest:
    user_id: int | None = None
    session_id: str | None = None
    limit: int = 10
    context: RecommendationContext = field(default_factory=RecommendationContext)
    behaviors: tuple[BehaviorEvent, ...] = ()
    exclude_product_ids: tuple[int, ...] = ()


@dataclass(frozen=True)
class RecommendedProduct:
    product_id: int
    score: float
    reasons: tuple[str, ...]
    status: str = "RANKED"
    score_breakdown: dict[str, float] = field(default_factory=dict)


@dataclass(frozen=True)
class RecommendationResponse:
    algorithm: str
    items: tuple[RecommendedProduct, ...]
    weights: dict[str, float] = field(default_factory=dict)
    candidate_count: int = 0
    filtered_candidate_count: int = 0
