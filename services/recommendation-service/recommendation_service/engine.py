from __future__ import annotations

import math
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone

from .catalog import CatalogRepository
from .models import (
    BehaviorEvent,
    Product,
    RecommendedProduct,
    RecommendationRequest,
    RecommendationResponse,
)
from .safety import evaluate_hard_constraints


EVENT_WEIGHTS = {
    "view_product": 1.0,
    "click_recommendation": 1.2,
    "add_favorite": 2.0,
    "add_to_cart": 3.0,
    "place_order": 5.0,
    "review_product": 4.0,
}

HARD_EXCLUDE_EVENTS = {"place_order", "review_product"}


@dataclass(frozen=True)
class _ScoredProduct:
    product: Product
    kb_score: float
    cb_score: float
    final_score: float
    reasons: tuple[str, ...]


class RecommendationEngine:
    def __init__(self, catalog: CatalogRepository):
        self.catalog = catalog
        self._features_by_id = {
            product.product_id: _product_features(product)
            for product in catalog.all()
        }

    def recommend(self, request: RecommendationRequest) -> RecommendationResponse:
        limit = max(1, min(request.limit or 10, 50))
        weights = self._hybrid_weights(request.behaviors, request.context)
        behavior_profile = self._behavior_profile(request.behaviors)
        excluded = set(request.exclude_product_ids) | _hard_excluded_product_ids(request.behaviors)
        candidates = []
        filtered_count = 0
        for product in self.catalog.all():
            decision = evaluate_hard_constraints(product, request.context, excluded)
            if decision.allowed:
                candidates.append(product)
            else:
                filtered_count += 1

        if not _has_scoring_context(request.context) and not behavior_profile:
            return self._cold_start_recommendations(
                limit, candidates, candidate_count=len(self.catalog.all()), filtered_count=filtered_count
            )

        scored = []
        for product in candidates:
            kb_score, kb_reasons = self._knowledge_score(product, request.context)
            cb_score, cb_reasons = self._content_score(product, behavior_profile)
            final_score = (
                weights["knowledge_based"] * kb_score
                + weights["content_based"] * cb_score
            )

            if final_score <= 0:
                continue

            scored.append(
                _ScoredProduct(
                    product=product,
                    kb_score=kb_score,
                    cb_score=cb_score,
                    final_score=final_score,
                    reasons=_top_reasons(kb_reasons + cb_reasons),
                )
            )

        scored.sort(key=lambda item: (-item.final_score, item.product.name.lower()))
        return RecommendationResponse(
            algorithm="knowledge_content_hybrid",
            weights=weights,
            items=tuple(
                RecommendedProduct(
                    product_id=item.product.product_id,
                    score=round(item.final_score, 4),
                    reasons=item.reasons,
                    score_breakdown={
                        "knowledgeBased": round(item.kb_score, 4),
                        "contentBased": round(item.cb_score, 4),
                    },
                )
                for item in scored[:limit]
            ),
            candidate_count=len(self.catalog.all()),
            filtered_candidate_count=filtered_count,
        )

    def similar_products(self, product_id: int, limit: int = 10) -> RecommendationResponse:
        anchor = self.catalog.get(product_id)
        if anchor is None:
            return RecommendationResponse(algorithm="content_based_similar", items=())

        anchor_features = self._features_by_id[anchor.product_id]
        scored = []
        for product in self.catalog.all():
            if product.product_id == anchor.product_id:
                continue

            score = _jaccard(anchor_features, self._features_by_id[product.product_id])
            if score <= 0:
                continue

            reasons = _similarity_reasons(anchor, product)
            scored.append((score, product, reasons))

        scored.sort(key=lambda item: (-item[0], item[1].name.lower()))
        return RecommendationResponse(
            algorithm="content_based_similar",
            weights={"content_based": 1.0},
            items=tuple(
                RecommendedProduct(
                    product_id=product.product_id,
                    score=round(score, 4),
                    reasons=_top_reasons(reasons),
                )
                for score, product, reasons in scored[: max(1, min(limit, 50))]
            ),
        )

    def explain(self, product_id: int, request: RecommendationRequest) -> RecommendedProduct | None:
        product = self.catalog.get(product_id)
        if product is None:
            return None
        excluded = set(request.exclude_product_ids) | _hard_excluded_product_ids(request.behaviors)
        decision = evaluate_hard_constraints(product, request.context, excluded)
        if not decision.allowed:
            return RecommendedProduct(
                product_id=product_id,
                score=0.0,
                status="FILTERED_OUT",
                reasons=(f"{decision.reason_code}: {decision.detail}",),
                score_breakdown={"knowledgeBased": 0.0, "contentBased": 0.0},
            )
        behavior_profile = self._behavior_profile(request.behaviors)
        if not _has_scoring_context(request.context) and not behavior_profile:
            return RecommendedProduct(
                product_id=product_id,
                score=_cold_start_score(product),
                reasons=("Ứng viên khởi đầu; ưu tiên theo độ đầy đủ dữ liệu sản phẩm.",),
                score_breakdown={"knowledgeBased": 0.0, "contentBased": 0.0},
            )

        weights = self._hybrid_weights(request.behaviors, request.context)
        kb_score, kb_reasons = self._knowledge_score(product, request.context)
        cb_score, cb_reasons = self._content_score(product, behavior_profile)
        final_score = (
            weights["knowledge_based"] * kb_score
            + weights["content_based"] * cb_score
        )
        reasons = _top_reasons(kb_reasons + cb_reasons)
        if final_score <= 0:
            reasons = reasons or ("Sản phẩm không khớp đủ tín hiệu để được xếp hạng.",)
        return RecommendedProduct(
            product_id=product_id,
            score=round(final_score, 4),
            status="RANKED" if final_score > 0 else "NOT_RANKED",
            reasons=reasons,
            score_breakdown={
                "knowledgeBased": round(kb_score, 4),
                "contentBased": round(cb_score, 4),
            },
        )

    def _knowledge_score(self, product: Product, context) -> tuple[float, list[str]]:
        score_parts: list[tuple[float, float]] = []
        reasons: list[str] = []

        if context.skin_type:
            match = _term(context.skin_type) in set(product.skin_types)
            score_parts.append((0.25, 1.0 if match else 0.0))
            if match:
                reasons.append(f"Phù hợp với loại da {context.skin_type}.")

        if context.skin_concerns:
            score, matched = _overlap_score(context.skin_concerns, product.skin_concerns)
            score_parts.append((0.35, score))
            if matched:
                reasons.append("Hỗ trợ vấn đề da: " + ", ".join(matched) + ".")

        if context.care_goals:
            score, matched = _overlap_score(context.care_goals, product.care_goals)
            score_parts.append((0.20, score))
            if matched:
                reasons.append("Khớp mục tiêu chăm sóc: " + ", ".join(matched) + ".")

        if context.preferred_categories:
            preferred = {_term(category) for category in context.preferred_categories}
            match = _term(product.category) in preferred
            score_parts.append((0.10, 1.0 if match else 0.0))
            if match:
                reasons.append(f"Đúng danh mục {product.category}.")

        if context.preferred_brands:
            preferred = {_term(brand) for brand in context.preferred_brands}
            match = _term(product.brand) in preferred
            score_parts.append((0.10, 1.0 if match else 0.0))
            if match:
                reasons.append(f"Đúng thương hiệu {product.brand}.")

        if context.avoid_ingredients and _contains_any(
            product.inci_ingredients,
            context.avoid_ingredients,
        ):
            return 0.0, ["Đã loại vì có thành phần người dùng muốn tránh."]

        if not score_parts:
            return 0.0, []

        return _weighted_average(score_parts), reasons

    def _content_score(
        self,
        product: Product,
        behavior_profile: dict[int, float],
    ) -> tuple[float, list[str]]:
        if not behavior_profile:
            return 0.0, []

        weighted_score = 0.0
        total_weight = 0.0
        best_anchor: Product | None = None
        best_similarity = 0.0
        product_features = self._features_by_id[product.product_id]

        for anchor_id, weight in behavior_profile.items():
            if product.product_id == anchor_id:
                continue
            anchor = self.catalog.get(anchor_id)
            if anchor is None:
                continue
            similarity = _jaccard(product_features, self._features_by_id[anchor_id])
            weighted_score += weight * similarity
            total_weight += weight
            if similarity > best_similarity:
                best_similarity = similarity
                best_anchor = anchor

        if total_weight == 0:
            return 0.0, []

        reasons = []
        if best_anchor and best_similarity > 0:
            reasons.append(f"Tương đồng với sản phẩm đã quan tâm: {best_anchor.name}.")

        return weighted_score / total_weight, reasons

    def _behavior_profile(self, behaviors: tuple[BehaviorEvent, ...]) -> dict[int, float]:
        profile: dict[int, float] = defaultdict(float)
        for event in behaviors:
            if event.product_id is None:
                continue
            profile[event.product_id] += EVENT_WEIGHTS.get(event.event_type, 0.5) * _time_decay(event.occurred_at)
        return dict(profile)

    def _hybrid_weights(self, behaviors: tuple[BehaviorEvent, ...], context) -> dict[str, float]:
        has_context = _has_scoring_context(context)
        has_behavior = any(event.product_id is not None for event in behaviors)
        if has_context and has_behavior:
            return {"knowledge_based": 0.55, "content_based": 0.45}
        if has_context:
            return {"knowledge_based": 1.0, "content_based": 0.0}
        if has_behavior:
            return {"knowledge_based": 0.0, "content_based": 1.0}
        return {"knowledge_based": 0.0, "content_based": 0.0}

    def _cold_start_recommendations(
        self,
        limit: int,
        candidates: list[Product],
        candidate_count: int,
        filtered_count: int,
    ) -> RecommendationResponse:
        selected: list[Product] = []
        seen_categories: set[str] = set()
        ordered_candidates = sorted(
            candidates,
            key=lambda product: (-_cold_start_score(product), product.name.lower()),
        )

        for product in ordered_candidates:
            category = product.category or "__missing_category__"
            if category in seen_categories:
                continue
            selected.append(product)
            seen_categories.add(category)
            if len(selected) >= limit:
                break

        if len(selected) < limit:
            for product in ordered_candidates:
                if product in selected:
                    continue
                selected.append(product)
                if len(selected) >= limit:
                    break

        return RecommendationResponse(
            algorithm="cold_start_diverse",
            weights={"knowledge_based": 0.0, "content_based": 0.0},
            items=tuple(
                RecommendedProduct(
                    product_id=product.product_id,
                    score=_cold_start_score(product),
                    reasons=("Gợi ý khởi đầu đa dạng, ưu tiên hồ sơ sản phẩm đầy đủ.",),
                )
                for product in selected
            ),
            candidate_count=candidate_count,
            filtered_candidate_count=filtered_count,
        )


def _cold_start_score(product: Product) -> float:
    signals = (
        product.price is not None,
        bool(product.currency),
        bool(product.description),
        bool(product.benefits),
        bool(product.inci_ingredients),
        bool(product.key_ingredients),
        bool(product.skin_types),
        bool(product.skin_concerns),
        bool(product.care_goals),
        bool(product.texture),
        bool(product.image_url),
        bool(product.source_url),
    )
    return round(sum(signals) / len(signals), 4)


def _product_features(product: Product) -> frozenset[str]:
    terms = set()
    for prefix, values in (
        ("brand", [product.brand]),
        ("category", [product.category]),
        ("skin", product.skin_types),
        ("concern", product.skin_concerns),
        ("goal", product.care_goals),
        ("texture", [product.texture]),
    ):
        terms.update(f"{prefix}:{_term(value)}" for value in values if value)

    text = " ".join(
        [
            product.description,
            product.benefits,
            product.inci_ingredients,
            product.key_ingredients,
        ]
    )
    common_tokens = Counter(_tokenize(text)).most_common(25)
    terms.update(f"text:{token}" for token, _count in common_tokens)
    return frozenset(terms)


def _jaccard(left: frozenset[str], right: frozenset[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)


def _overlap_score(expected: tuple[str, ...], actual: tuple[str, ...]) -> tuple[float, list[str]]:
    expected_terms = {_term(item) for item in expected if item}
    actual_terms = {_term(item) for item in actual if item}
    if not expected_terms:
        return 0.0, []
    matched = sorted(expected_terms & actual_terms)
    return len(matched) / len(expected_terms), matched


def _contains_any(text: str, terms: tuple[str, ...]) -> bool:
    ingredients = {_ingredient_key(item) for item in re.split(r"[,;|]", text) if item.strip()}
    avoided = {_ingredient_key(term) for term in terms if term}
    return bool(ingredients & avoided)


def _in_budget(price: float | None, minimum: float | None, maximum: float | None) -> bool:
    if minimum is None and maximum is None:
        return True
    if price is None or math.isnan(price):
        return False
    if minimum is not None and price < minimum:
        return False
    if maximum is not None and price > maximum:
        return False
    return True


def _similarity_reasons(anchor: Product, product: Product) -> list[str]:
    reasons = []
    if anchor.category and anchor.category == product.category:
        reasons.append(f"Cùng danh mục {product.category}.")
    shared_concerns = sorted(set(anchor.skin_concerns) & set(product.skin_concerns))
    if shared_concerns:
        reasons.append("Cùng vấn đề da: " + ", ".join(shared_concerns) + ".")
    shared_goals = sorted(set(anchor.care_goals) & set(product.care_goals))
    if shared_goals:
        reasons.append("Cùng mục tiêu: " + ", ".join(shared_goals) + ".")
    if anchor.brand and anchor.brand == product.brand:
        reasons.append(f"Cùng thương hiệu {product.brand}.")
    return reasons or ["Có nội dung và thuộc tính sản phẩm tương đồng."]


def _top_reasons(reasons: list[str], limit: int = 3) -> tuple[str, ...]:
    unique = []
    for reason in reasons:
        if reason and reason not in unique:
            unique.append(reason)
    return tuple(unique[:limit])


def _weighted_average(parts: list[tuple[float, float]]) -> float:
    total_weight = sum(weight for weight, _score in parts)
    if total_weight <= 0:
        return 0.0
    return sum(weight * score for weight, score in parts) / total_weight


def _has_scoring_context(context) -> bool:
    return any(
        [
            context.skin_type,
            context.skin_concerns,
            context.care_goals,
            context.preferred_categories,
            context.preferred_brands,
        ]
    )


def _hard_excluded_product_ids(behaviors: tuple[BehaviorEvent, ...]) -> set[int]:
    return {
        event.product_id
        for event in behaviors
        if event.product_id is not None and event.event_type in HARD_EXCLUDE_EVENTS
    }


def _time_decay(occurred_at: datetime | None) -> float:
    if occurred_at is None:
        return 1.0
    timestamp = occurred_at
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)
    age_days = max(0.0, (datetime.now(timezone.utc) - timestamp).total_seconds() / 86400)
    half_life_days = 30.0
    return math.exp(-math.log(2) * age_days / half_life_days)


def _ingredient_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def _term(value: str) -> str:
    return re.sub(r"\s+", "_", str(value).strip().lower())


def _tokenize(text: str) -> list[str]:
    return [
        token
        for token in re.findall(r"[a-zA-Z][a-zA-Z0-9_]{2,}", text.lower())
        if token not in {"the", "and", "for", "with", "this", "that", "skin", "size"}
    ]
