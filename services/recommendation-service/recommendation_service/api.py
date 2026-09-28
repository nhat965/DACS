from __future__ import annotations

import logging
import os
import time
import uuid
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Annotated, Any

try:
    from fastapi import Depends, FastAPI, Header, HTTPException, Path as ApiPath, Query, Request
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import JSONResponse
    from pydantic import BaseModel, Field, field_validator, model_validator
except ImportError as exc:  # pragma: no cover - import guard is for local setup errors.
    raise RuntimeError(
        "FastAPI dependencies are missing. Install with: "
        "python -m pip install -r services/recommendation-service/requirements.txt"
    ) from exc

from .catalog import DEFAULT_CATALOG_PATH, CatalogRepository
from .auth import (
    AuthSettings,
    InvalidTokenError,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)
from .commerce import (
    CommerceValidationError,
    DuplicateEmailError,
    MySQLCommerceRepository,
    UserRecord,
)
from .database import ProductNotFoundError, RecommendationDatabase, merge_context
from .engine import RecommendationEngine
from .models import BehaviorEvent, RecommendationContext, RecommendationRequest


logger = logging.getLogger(__name__)
PositiveProductId = Annotated[int, Field(gt=0)]
SessionId = Annotated[str, Field(min_length=1, max_length=120)]
_UNSET = object()


class EventType(str, Enum):
    VIEW_PRODUCT = "view_product"
    SEARCH_KEYWORD = "search_keyword"
    FILTER_USED = "filter_used"
    CLICK_RECOMMENDATION = "click_recommendation"
    ADD_FAVORITE = "add_favorite"
    ADD_TO_CART = "add_to_cart"
    REMOVE_FROM_CART = "remove_from_cart"
    PLACE_ORDER = "place_order"
    REVIEW_PRODUCT = "review_product"
    CHATBOT_MESSAGE = "chatbot_message"


PRODUCT_REQUIRED_EVENTS = {
    EventType.VIEW_PRODUCT,
    EventType.CLICK_RECOMMENDATION,
    EventType.ADD_FAVORITE,
    EventType.ADD_TO_CART,
    EventType.REMOVE_FROM_CART,
    EventType.PLACE_ORDER,
    EventType.REVIEW_PRODUCT,
}

SKIN_TYPES = {"normal", "dry", "oily", "combination", "sensitive", "unknown"}
SKIN_CONCERNS = {
    "acne", "dark_spot", "dryness", "aging", "redness", "large_pores",
    "dullness", "uneven_texture", "oiliness", "sensitivity",
}
CARE_GOALS = {
    "cleanse", "hydrate", "brighten", "anti_acne", "anti_aging", "repair",
    "soothe", "oil_control", "sun_protection", "exfoliate",
}
CATEGORIES = {
    "cleanser", "toner", "serum", "moisturizer", "sunscreen", "exfoliant",
    "mask", "makeup_remover", "eye_care", "lip_care", "body_care",
    "makeup", "fragrance",
}


class RecommendationBehaviorPayload(BaseModel):
    eventType: EventType
    productId: PositiveProductId | None = None
    eventValue: float | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    occurredAt: datetime | None = None

    @model_validator(mode="after")
    def validate_required_product(self):
        if self.eventType in PRODUCT_REQUIRED_EVENTS and self.productId is None:
            raise ValueError(f"{self.eventType.value} requires productId")
        return self


class BehaviorEventPayload(RecommendationBehaviorPayload):
    userId: int | None = Field(default=None, gt=0)
    sessionId: SessionId | None = None

    @field_validator("sessionId", mode="before")
    @classmethod
    def normalize_session_id(cls, value):
        return _normalize_session_id(value)

    @model_validator(mode="after")
    def validate_user_or_session(self):
        if self.userId is None and self.sessionId is None:
            raise ValueError("userId or sessionId is required")
        return self


class RecommendationContextPayload(BaseModel):
    skinType: str | None = None
    skinConcerns: list[str] = Field(default_factory=list)
    careGoals: list[str] = Field(default_factory=list)
    budgetMin: float | None = Field(default=None, ge=0)
    budgetMax: float | None = Field(default=None, ge=0)
    budgetCurrency: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")
    preferredCategories: list[str] = Field(default_factory=list)
    preferredBrands: list[str] = Field(default_factory=list)
    avoidIngredients: list[str] = Field(default_factory=list)

    @field_validator("skinType")
    @classmethod
    def validate_skin_type(cls, value):
        if value is not None and value not in SKIN_TYPES:
            raise ValueError("unsupported skinType")
        return value

    @field_validator("skinConcerns")
    @classmethod
    def validate_skin_concerns(cls, values):
        if any(value not in SKIN_CONCERNS for value in values):
            raise ValueError("unsupported skinConcerns value")
        return values

    @field_validator("careGoals")
    @classmethod
    def validate_care_goals(cls, values):
        if any(value not in CARE_GOALS for value in values):
            raise ValueError("unsupported careGoals value")
        return values

    @field_validator("preferredCategories")
    @classmethod
    def validate_categories(cls, values):
        if any(value not in CATEGORIES for value in values):
            raise ValueError("unsupported preferredCategories value")
        return values

    @model_validator(mode="after")
    def validate_budget_range(self):
        if self.budgetMin is not None and self.budgetMax is not None and self.budgetMin > self.budgetMax:
            raise ValueError("budgetMin must be less than or equal to budgetMax")
        if (self.budgetMin is not None or self.budgetMax is not None) and self.budgetCurrency is None:
            raise ValueError("budgetCurrency is required when a budget is provided")
        return self


class RecommendationPayload(BaseModel):
    userId: int | None = Field(default=None, gt=0)
    sessionId: SessionId | None = None
    limit: int = Field(default=10, ge=1, le=50)
    context: RecommendationContextPayload = Field(default_factory=RecommendationContextPayload)
    behaviors: list[RecommendationBehaviorPayload] = Field(default_factory=list)
    excludeProductIds: list[PositiveProductId] = Field(default_factory=list)

    @field_validator("sessionId", mode="before")
    @classmethod
    def normalize_session_id(cls, value):
        return _normalize_session_id(value)


class ExplainPayload(RecommendationPayload):
    productId: int = Field(gt=0)


class RegisterPayload(BaseModel):
    fullName: str = Field(min_length=2, max_length=120)
    email: str = Field(min_length=5, max_length=160)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if "@" not in normalized or normalized.startswith("@") or normalized.endswith("@"):
            raise ValueError("invalid email")
        return normalized


class LoginPayload(BaseModel):
    email: str = Field(min_length=5, max_length=160)
    password: str = Field(min_length=1, max_length=128)


class OrderItemPayload(BaseModel):
    productId: PositiveProductId
    quantity: int = Field(ge=1, le=99)


class OrderCreatePayload(BaseModel):
    items: list[OrderItemPayload] = Field(min_length=1, max_length=100)
    currency: str = Field(pattern=r"^[A-Z]{3}$")
    shippingName: str = Field(min_length=2, max_length=120)
    shippingPhone: str = Field(min_length=8, max_length=30)
    shippingAddress: str = Field(min_length=5, max_length=500)
    note: str | None = Field(default=None, max_length=1000)
    paymentMethod: str = Field(default="COD", pattern=r"^(COD|BANK_TRANSFER)$")


class PreferencesPayload(RecommendationContextPayload):
    currency: str = Field(default="USD", pattern=r"^[A-Z]{3}$")

    @model_validator(mode="after")
    def copy_currency_to_budget(self):
        if self.budgetCurrency is None:
            self.budgetCurrency = self.currency
        return self


def create_app(
    catalog_repository: CatalogRepository | None = None,
    database_override: Any = _UNSET,
    commerce_repository_override: Any = _UNSET,
    auth_settings_override: AuthSettings | None = None,
) -> FastAPI:
    catalog_path = Path(os.getenv("RECOMMENDATION_CATALOG_PATH", str(DEFAULT_CATALOG_PATH)))
    database = RecommendationDatabase.from_env() if database_override is _UNSET else database_override
    catalog, catalog_source = (
        (catalog_repository, "test")
        if catalog_repository is not None
        else _load_catalog(catalog_path, database)
    )
    personalization_database = None if catalog_source == "csv_fallback" else database
    commerce_repository = (
        MySQLCommerceRepository(database)
        if commerce_repository_override is _UNSET
        and isinstance(database, RecommendationDatabase)
        else None
        if commerce_repository_override is _UNSET
        else commerce_repository_override
    )
    auth_settings = auth_settings_override or AuthSettings.from_env()
    if isinstance(commerce_repository, MySQLCommerceRepository):
        _bootstrap_admin(commerce_repository)
    engine = RecommendationEngine(catalog)

    app = FastAPI(
        title="Cosmetic Recommendation Service",
        version="0.1.0",
        description="Knowledge-based + content-based recommendation API.",
    )

    allowed_origins = [
        origin.strip()
        for origin in os.getenv("CORS_ALLOW_ORIGINS", "").split(",")
        if origin.strip()
    ]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_origin_regex=os.getenv(
            "CORS_ALLOW_ORIGIN_REGEX",
            r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        ),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def request_observability(request: Request, call_next):
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception as exc:
            logger.error(
                "request_failed request_id=%s method=%s path=%s error_type=%s",
                request_id,
                request.method,
                request.url.path,
                type(exc).__name__,
            )
            response = JSONResponse(status_code=500, content={"detail": "Internal server error"})
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        response.headers["x-request-id"] = request_id
        logger.info(
            "request_complete request_id=%s method=%s path=%s status=%s latency_ms=%s",
            request_id,
            request.method,
            request.url.path,
            response.status_code,
            latency_ms,
        )
        return response

    @app.get("/health")
    def health() -> dict[str, Any]:
        return {
            "status": "ok",
            "service": "recommendation-service",
            "productCount": len(catalog.all()),
            "catalogSource": catalog_source,
            "databaseEnabled": database is not None,
        }

    @app.get("/ready")
    def ready() -> dict[str, Any]:
        catalog_available = len(catalog.all()) > 0
        database_available = database.is_available() if database is not None else True
        degraded = catalog_source == "csv_fallback" and not database_available
        checks = {
            "appInitialized": True,
            "catalogAvailable": catalog_available,
            "databaseAvailable": database_available,
            "degradedMode": degraded,
        }
        if not catalog_available or (not database_available and not degraded):
            raise HTTPException(status_code=503, detail={"status": "not_ready", "checks": checks})
        return {
            "status": "ready_degraded" if degraded else "ready",
            "service": "recommendation-service",
            "checks": checks,
        }

    def require_user(authorization: str | None = Header(default=None)) -> UserRecord:
        if commerce_repository is None:
            raise HTTPException(status_code=503, detail="Commerce database is unavailable")
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Authentication required")
        try:
            claims = decode_access_token(
                authorization.removeprefix("Bearer ").strip(),
                settings=auth_settings,
            )
            user = commerce_repository.get_user_by_id(int(claims["sub"]))
        except (InvalidTokenError, TypeError, ValueError) as exc:
            raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
        if user is None:
            raise HTTPException(status_code=401, detail="User no longer exists")
        return user

    def require_admin(user: UserRecord = Depends(require_user)) -> UserRecord:
        if user.role != "ADMIN":
            raise HTTPException(status_code=403, detail="ADMIN role is required")
        return user

    def optional_user(authorization: str | None = Header(default=None)) -> UserRecord | None:
        if not authorization:
            return None
        return require_user(authorization)

    @app.post("/auth/register", status_code=201)
    def register(payload: RegisterPayload) -> dict[str, Any]:
        if commerce_repository is None:
            raise HTTPException(status_code=503, detail="Commerce database is unavailable")
        try:
            user = commerce_repository.create_user(
                full_name=payload.fullName,
                email=payload.email,
                password_hash=hash_password(payload.password),
            )
        except DuplicateEmailError as exc:
            raise HTTPException(status_code=409, detail="Email is already registered") from exc
        return _auth_response(user, auth_settings)

    @app.post("/auth/login")
    def login(payload: LoginPayload) -> dict[str, Any]:
        if commerce_repository is None:
            raise HTTPException(status_code=503, detail="Commerce database is unavailable")
        user = commerce_repository.get_user_by_email(payload.email.strip().lower())
        if user is None or not verify_password(payload.password, user.password_hash):
            raise HTTPException(status_code=401, detail="Email or password is incorrect")
        return _auth_response(user, auth_settings)

    @app.get("/auth/profile")
    def profile(user: UserRecord = Depends(require_user)) -> dict[str, Any]:
        return _user_to_dict(user)

    @app.get("/users/me/preferences")
    def get_preferences(user: UserRecord = Depends(require_user)) -> dict[str, Any]:
        return commerce_repository.get_preferences(user.id)

    @app.put("/users/me/preferences")
    def put_preferences(
        payload: PreferencesPayload,
        user: UserRecord = Depends(require_user),
    ) -> dict[str, Any]:
        data = payload.model_dump()
        data["currency"] = payload.currency
        return commerce_repository.save_preferences(user.id, data)

    @app.post("/orders", status_code=201)
    def create_order(
        payload: OrderCreatePayload,
        user: UserRecord = Depends(require_user),
    ) -> dict[str, Any]:
        try:
            order = commerce_repository.create_order(
                user_id=user.id,
                items=[item.model_dump() for item in payload.items],
                currency=payload.currency,
                shipping_name=payload.shippingName,
                shipping_phone=payload.shippingPhone,
                shipping_address=payload.shippingAddress,
                note=payload.note,
                payment_method=payload.paymentMethod,
            )
        except CommerceValidationError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        _track_placed_order(database, user.id, order)
        return order

    @app.get("/orders")
    def list_my_orders(user: UserRecord = Depends(require_user)) -> dict[str, Any]:
        items = commerce_repository.list_orders(user_id=user.id)
        return {"items": items, "total": len(items)}

    @app.get("/admin/orders")
    def list_all_orders(_: UserRecord = Depends(require_admin)) -> dict[str, Any]:
        items = commerce_repository.list_orders()
        return {"items": items, "total": len(items)}

    @app.get("/admin/metrics")
    def admin_metrics(_: UserRecord = Depends(require_admin)) -> dict[str, int]:
        return commerce_repository.get_admin_metrics()

    @app.get("/products")
    def list_products(
        search: str | None = Query(default=None, max_length=120),
        category: str | None = Query(default=None, max_length=80),
        brand: str | None = Query(default=None, max_length=80),
        priceMin: float | None = Query(default=None, ge=0),
        priceMax: float | None = Query(default=None, ge=0),
        sort: str = Query(default="name_asc", pattern=r"^(name_asc|price_asc|price_desc)$"),
        limit: int = Query(default=24, ge=1, le=100),
        offset: int = Query(default=0, ge=0),
    ) -> dict[str, Any]:
        products = list(catalog.all())
        if search:
            term = search.strip().casefold()
            products = [
                product
                for product in products
                if term in product.name.casefold()
                or term in product.brand.casefold()
                or term in product.category.casefold()
            ]
        if category:
            normalized_category = category.strip().casefold()
            products = [
                product
                for product in products
                if product.category.casefold() == normalized_category
            ]
        if brand:
            normalized_brand = brand.strip().casefold()
            products = [
                product
                for product in products
                if product.brand.casefold() == normalized_brand
            ]
        if priceMin is not None:
            products = [
                product for product in products
                if product.price is not None and product.price >= priceMin
            ]
        if priceMax is not None:
            products = [
                product for product in products
                if product.price is not None and product.price <= priceMax
            ]
        if sort == "price_asc":
            products.sort(
                key=lambda product: (
                    product.price is None,
                    product.price if product.price is not None else float("inf"),
                    product.name.casefold(),
                )
            )
        elif sort == "price_desc":
            products.sort(
                key=lambda product: (
                    product.price is None,
                    -(product.price or 0),
                    product.name.casefold(),
                )
            )
        else:
            products.sort(key=lambda product: product.name.casefold())
        total = len(products)
        page = products[offset : offset + limit]
        return {
            "items": [_product_to_dict(product) for product in page],
            "total": total,
            "limit": limit,
            "offset": offset,
        }

    @app.get("/products/{productId}")
    def get_product(productId: int = ApiPath(gt=0)) -> dict[str, Any]:
        product = catalog.get(productId)
        if product is None:
            raise HTTPException(status_code=404, detail="Product not found")
        return _product_to_dict(product)

    @app.post("/behavior-events", status_code=202)
    def track_behavior_event(
        payload: BehaviorEventPayload,
        user: UserRecord | None = Depends(optional_user),
    ) -> dict[str, Any]:
        if database is None:
            raise HTTPException(
                status_code=503,
                detail=(
                    "Database integration is disabled. Set RECOMMENDATION_DB_ENABLED=true "
                    "and MYSQL_* environment variables to store behavior events."
                ),
            )
        if user is None and payload.sessionId is None:
            raise HTTPException(status_code=422, detail="Guest behavior requires sessionId")
        event = _payload_to_behavior_event(payload)
        try:
            result = database.save_behavior_event(
                user_id=user.id if user is not None else None,
                session_id=payload.sessionId,
                event=event,
            )
        except Exception as exc:
            raise _database_http_error(exc) from exc
        return {"accepted": True, **result}

    @app.post("/recommendations/personalized")
    def personalized(
        payload: RecommendationPayload,
        user: UserRecord | None = Depends(optional_user),
    ) -> dict[str, Any]:
        request = _payload_to_request(payload)
        if user is not None:
            request = RecommendationRequest(
                user_id=user.id,
                session_id=request.session_id,
                limit=request.limit,
                context=request.context,
                behaviors=request.behaviors,
                exclude_product_ids=request.exclude_product_ids,
            )
        if personalization_database is not None:
            try:
                request = _hydrate_request_from_database(personalization_database, request)
            except Exception as exc:
                raise _database_http_error(exc) from exc
        response = engine.recommend(request)
        logger.info(
            "recommendation_complete algorithm=%s candidate_count=%s filtered_candidate_count=%s result_count=%s",
            response.algorithm,
            response.candidate_count,
            response.filtered_candidate_count,
            len(response.items),
        )
        if personalization_database is not None:
            try:
                personalization_database.save_recommendation_log(
                    user_id=request.user_id,
                    session_id=request.session_id,
                    algorithm=response.algorithm,
                    request_context=_context_to_dict(request.context),
                    items=response.items,
                )
            except Exception as exc:
                logger.warning(
                    "recommendation_log_failed error_type=%s",
                    type(exc).__name__,
                )
        return _response_to_dict(response)

    @app.get("/recommendations/similar-products/{productId}")
    def similar_products(
        productId: int = ApiPath(gt=0),
        limit: int = Query(default=10, ge=1, le=50),
    ) -> dict[str, Any]:
        if catalog.get(productId) is None:
            raise HTTPException(status_code=404, detail="Product not found")
        return _response_to_dict(engine.similar_products(productId, limit=limit))

    @app.post("/recommendations/explain")
    def explain(
        payload: ExplainPayload,
        user: UserRecord | None = Depends(optional_user),
    ) -> dict[str, Any]:
        request = _payload_to_request(payload)
        if user is not None:
            request = RecommendationRequest(
                user_id=user.id,
                session_id=request.session_id,
                limit=request.limit,
                context=request.context,
                behaviors=request.behaviors,
                exclude_product_ids=request.exclude_product_ids,
            )
        if personalization_database is not None:
            try:
                request = _hydrate_request_from_database(personalization_database, request)
            except Exception as exc:
                raise _database_http_error(exc) from exc
        item = engine.explain(payload.productId, request)
        if item is None:
            raise HTTPException(status_code=404, detail="Recommendation explanation not found")
        return {
            "productId": item.product_id,
            "score": item.score,
            "reasons": list(item.reasons),
            "status": item.status,
            "scoreBreakdown": item.score_breakdown,
        }

    return app


def _load_catalog(
    catalog_path: Path,
    database: RecommendationDatabase | None,
) -> tuple[CatalogRepository, str]:
    if database is not None:
        if not database.is_available():
            return CatalogRepository.from_csv(catalog_path), "csv_fallback"
        products = database.load_products()
        return CatalogRepository(products), "mysql"
    return CatalogRepository.from_csv(catalog_path), "csv"


def _payload_to_request(payload: RecommendationPayload) -> RecommendationRequest:
    context = RecommendationContext(
        skin_type=payload.context.skinType,
        skin_concerns=tuple(payload.context.skinConcerns),
        care_goals=tuple(payload.context.careGoals),
        budget_min=payload.context.budgetMin,
        budget_max=payload.context.budgetMax,
        budget_currency=payload.context.budgetCurrency,
        preferred_categories=tuple(payload.context.preferredCategories),
        preferred_brands=tuple(payload.context.preferredBrands),
        avoid_ingredients=tuple(payload.context.avoidIngredients),
    )
    return RecommendationRequest(
        user_id=payload.userId,
        session_id=payload.sessionId,
        limit=payload.limit,
        context=context,
        behaviors=tuple(
            _payload_to_behavior_event(event)
            for event in payload.behaviors
        ),
        exclude_product_ids=tuple(payload.excludeProductIds),
    )


def _payload_to_behavior_event(payload: RecommendationBehaviorPayload) -> BehaviorEvent:
    return BehaviorEvent(
        event_type=payload.eventType.value,
        product_id=payload.productId,
        event_value=payload.eventValue,
        metadata=payload.metadata,
        occurred_at=payload.occurredAt,
    )


def _hydrate_request_from_database(
    database: RecommendationDatabase,
    request: RecommendationRequest,
) -> RecommendationRequest:
    stored_context = database.load_user_context(request.user_id)
    stored_behaviors = database.load_behavior_events(
        user_id=request.user_id,
        session_id=request.session_id,
    )
    return RecommendationRequest(
        user_id=request.user_id,
        session_id=request.session_id,
        limit=request.limit,
        context=merge_context(request.context, stored_context),
        behaviors=request.behaviors + stored_behaviors,
        exclude_product_ids=request.exclude_product_ids,
    )


def _response_to_dict(response) -> dict[str, Any]:
    return {
        "algorithm": response.algorithm,
        "weights": response.weights,
        "items": [
            {
                "productId": item.product_id,
                "score": item.score,
                "reasons": list(item.reasons),
                "status": item.status,
                "scoreBreakdown": item.score_breakdown,
            }
            for item in response.items
        ],
        "candidateCount": response.candidate_count,
        "filteredCandidateCount": response.filtered_candidate_count,
    }


def _product_to_dict(product) -> dict[str, Any]:
    return {
        "productId": product.product_id,
        "sku": product.sku,
        "name": product.name,
        "brand": product.brand,
        "category": product.category,
        "price": product.price,
        "currency": product.currency,
        "description": product.description,
        "benefits": product.benefits,
        "inciIngredients": product.inci_ingredients,
        "keyIngredients": product.key_ingredients,
        "skinTypes": list(product.skin_types),
        "skinConcerns": list(product.skin_concerns),
        "careGoals": list(product.care_goals),
        "texture": product.texture,
        "imageUrl": product.image_url,
        "sourceUrl": product.source_url,
        "stockQuantity": product.stock_quantity,
        "usageInstruction": product.usage_instruction,
        "warnings": product.warnings,
    }


def _user_to_dict(user: UserRecord) -> dict[str, Any]:
    return {
        "userId": user.id,
        "fullName": user.full_name,
        "email": user.email,
        "role": user.role,
        "skinType": user.skin_type,
    }


def _auth_response(user: UserRecord, settings: AuthSettings) -> dict[str, Any]:
    return {
        "accessToken": create_access_token(
            user_id=user.id,
            email=user.email,
            role=user.role,
            settings=settings,
        ),
        "tokenType": "bearer",
        "expiresIn": settings.token_ttl_seconds,
        "user": _user_to_dict(user),
    }


def _track_placed_order(database: Any, user_id: int, order: dict[str, Any]) -> None:
    if database is None or not hasattr(database, "save_behavior_event"):
        return
    for item in order.get("items", []):
        try:
            database.save_behavior_event(
                user_id=user_id,
                session_id=None,
                event=BehaviorEvent(
                    event_type=EventType.PLACE_ORDER.value,
                    product_id=int(item["productId"]),
                    event_value=float(item["quantity"]),
                    metadata={"orderId": order["orderId"]},
                ),
            )
        except Exception as exc:
            logger.warning(
                "order_behavior_tracking_failed order_id=%s product_id=%s error_type=%s",
                order.get("orderId"),
                item.get("productId"),
                type(exc).__name__,
            )


def _context_to_dict(context: RecommendationContext) -> dict[str, Any]:
    return {
        "skinType": context.skin_type,
        "skinConcerns": list(context.skin_concerns),
        "careGoals": list(context.care_goals),
        "budgetMin": context.budget_min,
        "budgetMax": context.budget_max,
        "budgetCurrency": context.budget_currency,
        "preferredCategories": list(context.preferred_categories),
        "preferredBrands": list(context.preferred_brands),
        "avoidIngredients": list(context.avoid_ingredients),
    }


def _database_http_error(exc: Exception) -> HTTPException:
    if isinstance(exc, ProductNotFoundError):
        return HTTPException(status_code=404, detail="Product not found")
    logger.error("recommendation_database_failed error_type=%s", type(exc).__name__)
    return HTTPException(status_code=503, detail="Recommendation database is temporarily unavailable")


def _normalize_session_id(value):
    if value is None:
        return None
    if not isinstance(value, str):
        return value
    normalized = value.strip()
    return normalized or None


def _bootstrap_admin(repository: MySQLCommerceRepository) -> None:
    email = os.getenv("ADMIN_EMAIL", "").strip().lower()
    password = os.getenv("ADMIN_PASSWORD", "")
    full_name = os.getenv("ADMIN_NAME", "Lumi Administrator").strip()
    if not email and not password:
        return
    if not email or not password:
        logger.warning("admin_bootstrap_skipped reason=incomplete_environment")
        return
    try:
        repository.ensure_admin(
            full_name=full_name,
            email=email,
            password_hash=hash_password(password),
        )
        logger.info("admin_bootstrap_ready email=%s", email)
    except Exception as exc:
        logger.error("admin_bootstrap_failed error_type=%s", type(exc).__name__)


# Keep module-level app creation after every helper used by create_app().
# This matters when MySQL is enabled because create_app() invokes the admin
# bootstrap during import.
app = create_app()
