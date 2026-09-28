from __future__ import annotations

from dataclasses import dataclass

from .ingredients import normalize_ingredient_name, normalized_ingredient_set
from .models import Product, RecommendationContext


@dataclass(frozen=True)
class SafetyDecision:
    allowed: bool
    reason_code: str | None = None
    detail: str | None = None


def evaluate_hard_constraints(
    product: Product,
    context: RecommendationContext,
    excluded_product_ids: set[int],
) -> SafetyDecision:
    if product.product_id in excluded_product_ids:
        return SafetyDecision(False, "EXPLICIT_PRODUCT_EXCLUSION", "Sản phẩm nằm trong danh sách loại trừ.")

    if context.budget_min is not None or context.budget_max is not None:
        if product.price is None:
            return SafetyDecision(False, "MISSING_PRICE", "Sản phẩm không có giá để kiểm tra ngân sách.")
        if not product.currency:
            return SafetyDecision(False, "MISSING_CURRENCY", "Sản phẩm không có đơn vị tiền tệ để kiểm tra ngân sách.")
        if context.budget_currency and product.currency and context.budget_currency != product.currency:
            return SafetyDecision(False, "CURRENCY_MISMATCH", "Đơn vị tiền tệ không khớp ngân sách.")
        if context.budget_min is not None and product.price < context.budget_min:
            return SafetyDecision(False, "OUTSIDE_BUDGET", "Giá thấp hơn khoảng ngân sách yêu cầu.")
        if context.budget_max is not None and product.price > context.budget_max:
            return SafetyDecision(False, "OUTSIDE_BUDGET", "Giá vượt ngân sách tối đa.")

    avoided = {
        normalized for term in context.avoid_ingredients
        if (normalized := normalize_ingredient_name(term))
    }
    if avoided:
        product_ingredients = normalized_ingredient_set(product.inci_ingredients)
        matched = sorted(avoided & product_ingredients)
        if matched:
            return SafetyDecision(
                False,
                "USER_EXCLUDED_INGREDIENT",
                "Chứa thành phần người dùng yêu cầu loại trừ: " + ", ".join(matched) + ".",
            )

    return SafetyDecision(True)
