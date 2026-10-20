from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import dataclass

from .catalog import CatalogRepository
from .database import merge_context
from .engine import RecommendationEngine
from .llm import (
    LLMCaution,
    LLMConsultation,
    LLMProvider,
    LLMProviderError,
    LLMRecommendation,
    LLMRoutineStep,
)
from .models import Product, RecommendationContext, RecommendationRequest
from .safety import evaluate_hard_constraints


MAX_HISTORY_MESSAGES = 10
MAX_CANDIDATES = 8


@dataclass(frozen=True)
class ConversationTurn:
    role: str
    content: str


@dataclass(frozen=True)
class ValidatedChatRecommendation:
    product: Product
    explanation: str


@dataclass(frozen=True)
class ValidatedRoutineStep:
    order: int
    time_of_day: str
    label: str
    product: Product | None
    instruction: str
    reason: str


@dataclass(frozen=True)
class ChatCaution:
    severity: str
    title: str
    detail: str


@dataclass(frozen=True)
class ChatResult:
    response: str
    recommendations: tuple[ValidatedChatRecommendation, ...]
    follow_up_questions: tuple[str, ...]
    context: RecommendationContext
    consultation_type: str
    routine: tuple[ValidatedRoutineStep, ...]
    cautions: tuple[ChatCaution, ...]
    missing_information: tuple[str, ...]


class ChatService:
    def __init__(
        self,
        *,
        catalog: CatalogRepository,
        engine: RecommendationEngine,
        llm_provider: LLMProvider,
    ):
        self.catalog = catalog
        self.engine = engine
        self.llm_provider = llm_provider

    async def consult(
        self,
        *,
        message: str,
        history: tuple[ConversationTurn, ...] = (),
        context: RecommendationContext = RecommendationContext(),
        user_id: int | None = None,
        session_id: str | None = None,
        behaviors=(),
    ) -> ChatResult:
        extracted = extract_context(message)
        history_context = RecommendationContext()
        for turn in history[-MAX_HISTORY_MESSAGES:]:
            if turn.role == "user":
                history_context = merge_context(
                    extract_context(turn.content),
                    history_context,
                )
        # What the user says in the current turn is the most specific signal;
        # conversation history comes next and stored preferences fill the rest.
        effective_context = merge_context(
            extracted,
            merge_context(history_context, context),
        )
        request = RecommendationRequest(
            user_id=user_id,
            session_id=session_id,
            limit=MAX_CANDIDATES,
            context=effective_context,
            behaviors=tuple(behaviors),
        )
        ranked = self.engine.recommend(request)
        candidates = tuple(
            product
            for item in ranked.items
            if (product := self.catalog.get(item.product_id)) is not None
        )
        # The newest category request is a search focus, not merely a weak
        # preference. A user's existing skin profile still sorts these results,
        # but incomplete category metadata must not hide every matching product.
        focused_candidates = _current_category_candidates(
            products=self.catalog.all(),
            categories=extracted.preferred_categories,
            context=effective_context,
        )
        if focused_candidates:
            candidates = focused_candidates
        prompt = _build_prompt(
            message=message,
            history=history[-MAX_HISTORY_MESSAGES:],
            context=effective_context,
            candidates=candidates,
        )
        try:
            generated = await self.llm_provider.generate_consultation(prompt)
        except LLMProviderError as error:
            if error.unavailable:
                raise
            generated = _fallback_consultation(
                candidates=candidates,
                context=effective_context,
                category_focus=extracted.preferred_categories,
            )
        recommendation_budget = (
            effective_context.budget_max
            if generated.consultationType == "routine"
            else None
        )
        validated = _validate_recommendations(
            generated,
            candidates,
            budget_max=recommendation_budget,
        )
        routine = _validate_routine(
            generated.routine,
            candidates,
            budget_max=effective_context.budget_max,
        )
        cautions = _merge_cautions(
            generated.cautions,
            _catalog_cautions(tuple(item.product for item in validated)),
        )
        missing_information = _resolve_missing_information(
            generated=generated,
            context=effective_context,
        )
        follow_up_questions = _resolve_follow_up_questions(
            generated=generated,
            missing_information=missing_information,
        )
        return ChatResult(
            response=generated.response.strip(),
            recommendations=validated,
            follow_up_questions=follow_up_questions,
            context=effective_context,
            consultation_type=generated.consultationType,
            routine=routine,
            cautions=cautions,
            missing_information=missing_information,
        )


def extract_context(message: str) -> RecommendationContext:
    text = _fold(message)
    skin_type = _first_match(
        text,
        {
            "oily": ("da dau", "nhieu dau"),
            "dry": ("da kho", "kho bong", "thieu am"),
            "combination": ("da hon hop",),
            "sensitive": ("da nhay cam", "de kich ung"),
            "normal": ("da thuong",),
        },
    )
    if skin_type is None and re.search(r"\bda\b.{0,30}\bkho\b", text):
        skin_type = "dry"
    if skin_type is None and re.search(r"\bda\b.{0,30}\b(dau|nhieu dau)\b", text):
        skin_type = "oily"
    concerns = _all_matches(
        text,
        {
            "acne": ("mun",),
            "dryness": ("kho", "bong troc", "thieu am"),
            "sensitivity": ("nhay cam", "kich ung"),
            "redness": ("do da", "man do"),
            "dark_spot": ("tham", "dom nau"),
            "aging": ("lao hoa", "nep nhan"),
            "large_pores": ("lo chan long",),
            "oiliness": ("do dau", "nhieu dau"),
            "dullness": ("xin mau", "xam xin"),
            "uneven_texture": ("khong deu mau", "be mat san sui"),
        },
    )
    goals = _all_matches(
        text,
        {
            "hydrate": ("cap am", "duong am", "mong am", "mat da"),
            "brighten": ("lam sang", "duong sang"),
            "oil_control": ("kiem soat dau", "giam dau"),
            "anti_acne": ("tri mun", "giam mun", "mun"),
            "anti_aging": ("chong lao hoa", "nep nhan"),
            "repair": ("phuc hoi", "hang rao da"),
            "soothe": ("lam diu", "diu da", "mat da"),
            "sun_protection": ("chong nang",),
            "cleanse": ("lam sach",),
            "exfoliate": ("tay te bao chet",),
        },
    )
    categories = _all_matches(
        text,
        {
            "serum": ("serum", "tinh chat"),
            "cleanser": ("sua rua mat", "lam sach"),
            "toner": ("toner", "nuoc can bang"),
            "moisturizer": ("kem duong", "duong am"),
            "sunscreen": ("kem chong nang", "chong nang"),
            "mask": ("mat na",),
            "lip_care": ("son duong", "cham soc moi"),
            "body_care": ("duong the", "body"),
            "makeup": ("trang diem", "makeup"),
            "fragrance": ("nuoc hoa",),
        },
    )
    budget_max = _extract_budget_max(text)
    avoid_ingredients = _extract_avoid_ingredients(message)
    return RecommendationContext(
        skin_type=skin_type,
        skin_concerns=concerns,
        care_goals=goals,
        budget_max=budget_max,
        budget_currency="VND" if budget_max is not None else None,
        preferred_categories=categories,
        avoid_ingredients=avoid_ingredients,
    )


def _build_prompt(
    *,
    message: str,
    history: tuple[ConversationTurn, ...],
    context: RecommendationContext,
    candidates: tuple[Product, ...],
) -> str:
    history_data = [
        {"role": turn.role, "content": turn.content[:2000]}
        for turn in history
    ]
    candidate_data = [_grounded_product(product) for product in candidates]
    payload = {
        "conversationHistory": history_data,
        "currentMessage": message,
        "verifiedProfileAndConstraints": _context_data(context),
        "verifiedCandidateProducts": candidate_data,
        "currentTurnFocus": {
            "requestedCategories": list(extract_context(message).preferred_categories),
            "requestedBudgetMax": extract_context(message).budget_max,
        },
        "responseRules": {
            "budgetAppliesToRoutineTotal": context.budget_max is not None,
            "maxRecommendedProducts": 3,
            "askBeforeGuessingMissingSkinFacts": True,
            "routineProductIdsMustComeFromCandidates": True,
        },
    }
    return (
        "Hãy phân loại yêu cầu thành general, recommendation, routine, comparison hoặc safety. "
        "Trả lời bằng tiếng Việt, rõ ràng, thân thiện và có cơ sở. Tóm tắt nhu cầu đã hiểu trước, "
        "sau đó đưa hướng dẫn có thể thực hiện. "
        "Nếu câu hỏi mang tính y khoa hoặc có dấu hiệu nghiêm trọng, khuyên người dùng gặp bác sĩ da liễu. "
        "Chỉ đề xuất productId có trong verifiedCandidateProducts. Không suy đoán dữ liệu bị thiếu; "
        "hãy nói rõ dữ liệu nào chưa có. Nếu không có ứng viên phù hợp, để recommendations rỗng và "
        "giải thích điều kiện nào khiến chưa tìm được. Khi currentTurnFocus có requestedCategories, "
        "ưu tiên đúng danh mục đang được hỏi; hồ sơ cũ chỉ dùng để xếp hạng, không được tự ý trả lời "
        "không có sản phẩm nếu verifiedCandidateProducts vẫn có ứng viên. Nếu tạo routine, tổng giá các sản phẩm khác nhau "
        "không vượt budgetMax và thứ tự dùng phải hợp lý; bước không gắn sản phẩm đặt productId=null. "
        "Chỉ nêu tương tác hoạt chất khi thành phần tương ứng có trong dữ liệu đã xác minh. "
        "Nếu thiếu loại da, vấn đề, mục tiêu hoặc ngân sách cần thiết cho yêu cầu thì ghi vào "
        "missingInformation và hỏi ngắn gọn. Tối đa 3 đề xuất và 2 câu hỏi tiếp theo.\n\n"
        + json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    )


def _grounded_product(product: Product) -> dict[str, object]:
    def known(value):
        return value if value not in (None, "", (), []) else "KHÔNG_CÓ_DỮ_LIỆU"

    return {
        "productId": product.product_id,
        "name": product.name,
        "brand": known(product.brand),
        "category": known(product.category),
        "price": known(product.price),
        "currency": known(product.currency),
        "stockQuantity": known(product.stock_quantity),
        "benefits": known(product.benefits),
        "keyIngredients": known(product.key_ingredients),
        "inciIngredients": known(product.inci_ingredients),
        "skinTypes": known(product.skin_types),
        "skinConcerns": known(product.skin_concerns),
        "careGoals": known(product.care_goals),
        "warnings": known(product.warnings),
    }


def _context_data(context: RecommendationContext) -> dict[str, object]:
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


def _validate_recommendations(
    generated: LLMConsultation,
    candidates: tuple[Product, ...],
    *,
    budget_max: float | None,
) -> tuple[ValidatedChatRecommendation, ...]:
    allowed = {product.product_id: product for product in candidates}
    seen: set[int] = set()
    result: list[ValidatedChatRecommendation] = []
    total = 0.0
    for item in generated.recommendations:
        product = allowed.get(item.productId)
        if product is None or product.product_id in seen:
            continue
        price = product.price or 0.0
        if budget_max is not None and product.price is not None and total + price > budget_max:
            continue
        seen.add(product.product_id)
        total += price
        result.append(
            ValidatedChatRecommendation(
                product=product,
                explanation=item.explanation.strip(),
            )
        )
        if len(result) == 3:
            break
    return tuple(result)


_CATEGORY_QUERY_PATTERNS: dict[str, tuple[str, ...]] = {
    "serum": (r"\bserum\b", r"tinh chat"),
    "cleanser": (r"sua rua mat", r"\bcleanser\b"),
    "toner": (r"\btoner\b", r"nuoc can bang"),
    "moisturizer": (r"kem duong", r"\bmoisturi[sz]er\b", r"cream"),
    "sunscreen": (r"kem chong nang", r"\bsunscreen\b", r"sun cream"),
    "mask": (r"mat na", r"\bmask\b"),
    "lip_care": (r"son duong", r"lip balm", r"lip care"),
    "body_care": (r"duong the", r"\bbody\b"),
    "makeup": (r"trang diem", r"\bmakeup\b", r"cushion", r"foundation"),
    "fragrance": (r"nuoc hoa", r"\bperfume\b", r"\bfragrance\b"),
}


def _current_category_candidates(
    *,
    products: tuple[Product, ...],
    categories: tuple[str, ...],
    context: RecommendationContext,
) -> tuple[Product, ...]:
    if not categories:
        return ()
    selected = []
    for product in products:
        if not _matches_requested_category(product, categories):
            continue
        if not evaluate_hard_constraints(product, context, set()).allowed:
            continue
        selected.append(product)
    selected.sort(key=lambda product: (-_focus_score(product, context), product.name.casefold()))
    return tuple(selected[:MAX_CANDIDATES])


def _matches_requested_category(product: Product, categories: tuple[str, ...]) -> bool:
    searchable = _fold(
        " ".join((product.category, product.name, product.description, product.benefits))
    )
    for category in categories:
        if _fold(product.category) == _fold(category):
            return True
        patterns = _CATEGORY_QUERY_PATTERNS.get(category, (re.escape(_fold(category)),))
        if any(re.search(pattern, searchable) for pattern in patterns):
            return True
    return False


def _focus_score(product: Product, context: RecommendationContext) -> float:
    score = 0.0
    if context.skin_type and context.skin_type in product.skin_types:
        score += 4.0
    score += 2.0 * len(set(context.skin_concerns) & set(product.skin_concerns))
    score += 2.0 * len(set(context.care_goals) & set(product.care_goals))
    if product.stock_quantity is not None and product.stock_quantity > 0:
        score += 0.5
    if product.price is not None:
        score += max(0.0, 0.25 - product.price / 10_000_000)
    return score


def _fallback_consultation(
    *,
    candidates: tuple[Product, ...],
    context: RecommendationContext,
    category_focus: tuple[str, ...],
) -> LLMConsultation:
    recommendations = [
        LLMRecommendation(
            productId=product.product_id,
            explanation=_fallback_explanation(product, context, category_focus),
        )
        for product in candidates[:3]
    ]
    if recommendations:
        response = (
            "Lumi AI đang phản hồi chậm, nhưng mình vẫn tìm được các sản phẩm "
            "đã được lọc từ catalog theo yêu cầu của bạn."
        )
    else:
        response = (
            "Lumi AI đang phản hồi chậm và hiện chưa có sản phẩm catalog nào "
            "khớp với các điều kiện đã nêu. Bạn có thể thử đổi ngân sách hoặc danh mục."
        )
    follow_ups = []
    if category_focus:
        follow_ups.append("Bạn muốn ưu tiên làm dịu, cấp ẩm hay làm sáng da?")
    return LLMConsultation(
        response=response,
        recommendations=recommendations,
        followUpQuestions=follow_ups,
        consultationType="recommendation",
    )


def _fallback_explanation(
    product: Product,
    context: RecommendationContext,
    category_focus: tuple[str, ...],
) -> str:
    reasons: list[str] = []
    if category_focus:
        reasons.append("Đúng danh mục bạn vừa hỏi")
    if context.skin_type and context.skin_type in product.skin_types:
        reasons.append(f"có thông tin phù hợp da {context.skin_type}")
    if product.price is not None:
        reasons.append(f"giá {int(product.price):,} {product.currency or ''}".strip())
    return "; ".join(reasons) or "Được chọn từ catalog hiện có."


def _validate_routine(
    steps: list[LLMRoutineStep],
    candidates: tuple[Product, ...],
    *,
    budget_max: float | None,
) -> tuple[ValidatedRoutineStep, ...]:
    allowed = {product.product_id: product for product in candidates}
    accepted_products: set[int] = set()
    total = 0.0
    result: list[ValidatedRoutineStep] = []
    for step in sorted(steps, key=lambda item: (item.order, item.timeOfDay)):
        product = allowed.get(step.productId) if step.productId is not None else None
        if step.productId is not None and product is None:
            continue
        if product is not None and product.product_id not in accepted_products:
            price = product.price or 0.0
            if budget_max is not None and product.price is not None and total + price > budget_max:
                continue
            accepted_products.add(product.product_id)
            total += price
        result.append(
            ValidatedRoutineStep(
                order=step.order,
                time_of_day=step.timeOfDay,
                label=step.label.strip(),
                product=product,
                instruction=step.instruction.strip(),
                reason=step.reason.strip(),
            )
        )
    return tuple(result[:10])


def _catalog_cautions(products: tuple[Product, ...]) -> tuple[ChatCaution, ...]:
    cautions: list[ChatCaution] = []
    ingredient_text = " ".join(
        _fold(f"{product.key_ingredients} {product.inci_ingredients}")
        for product in products
    )
    has_retinoid = any(value in ingredient_text for value in ("retinol", "retinal", "retinoid"))
    has_exfoliating_acid = any(
        value in ingredient_text
        for value in ("glycolic acid", "lactic acid", "salicylic acid", "aha", "bha")
    )
    has_benzoyl_peroxide = "benzoyl peroxide" in ingredient_text
    if has_retinoid and has_exfoliating_acid:
        cautions.append(
            ChatCaution(
                severity="warning",
                title="Không nên bắt đầu cùng một buổi",
                detail=(
                    "Danh sách có retinoid và acid tẩy da chết. Nên dùng xen kẽ buổi tối, "
                    "bắt đầu chậm và ngưng nếu da kích ứng."
                ),
            )
        )
    if has_retinoid and has_benzoyl_peroxide:
        cautions.append(
            ChatCaution(
                severity="warning",
                title="Tách thời điểm sử dụng hoạt chất",
                detail=(
                    "Danh sách có retinoid và benzoyl peroxide. Nên dùng ở các thời điểm khác nhau "
                    "và ưu tiên hướng dẫn của bác sĩ nếu đang điều trị mụn."
                ),
            )
        )
    for product in products:
        if product.warnings.strip():
            cautions.append(
                ChatCaution(
                    severity="info",
                    title=f"Lưu ý với {product.name}",
                    detail=product.warnings.strip()[:700],
                )
            )
    return tuple(cautions[:5])


def _merge_cautions(
    generated: list[LLMCaution],
    catalog: tuple[ChatCaution, ...],
) -> tuple[ChatCaution, ...]:
    result: list[ChatCaution] = []
    seen: set[str] = set()
    for caution in [
        *(ChatCaution(item.severity, item.title.strip(), item.detail.strip()) for item in generated),
        *catalog,
    ]:
        fingerprint = _fold(f"{caution.title} {caution.detail}")
        if not caution.title or not caution.detail or fingerprint in seen:
            continue
        seen.add(fingerprint)
        result.append(caution)
        if len(result) == 5:
            break
    return tuple(result)


def _resolve_missing_information(
    *,
    generated: LLMConsultation,
    context: RecommendationContext,
) -> tuple[str, ...]:
    values = [item.strip() for item in generated.missingInformation if item.strip()]
    if generated.consultationType in {"recommendation", "routine", "comparison"}:
        if context.skin_type is None:
            values.append("Loại da hiện tại")
        if not context.skin_concerns and not context.care_goals:
            values.append("Vấn đề hoặc mục tiêu chăm sóc chính")
    return tuple(dict.fromkeys(values))[:5]


def _resolve_follow_up_questions(
    *,
    generated: LLMConsultation,
    missing_information: tuple[str, ...],
) -> tuple[str, ...]:
    questions = [
        question.strip()
        for question in generated.followUpQuestions
        if question.strip()
    ]
    fallback = {
        "Loại da hiện tại": "Da của bạn thuộc loại khô, dầu, hỗn hợp hay nhạy cảm?",
        "Vấn đề hoặc mục tiêu chăm sóc chính": (
            "Bạn muốn ưu tiên cấp ẩm, làm dịu, giảm mụn hay làm sáng da?"
        ),
    }
    for item in missing_information:
        if item in fallback and fallback[item] not in questions:
            questions.append(fallback[item])
    return tuple(questions[:4])


def _fold(value: str) -> str:
    normalized = unicodedata.normalize("NFD", value.lower().replace("đ", "d"))
    return " ".join(
        "".join(char for char in normalized if unicodedata.category(char) != "Mn").split()
    )


def _first_match(text: str, mapping: dict[str, tuple[str, ...]]) -> str | None:
    for value, phrases in mapping.items():
        if any(phrase in text for phrase in phrases):
            return value
    return None


def _all_matches(text: str, mapping: dict[str, tuple[str, ...]]) -> tuple[str, ...]:
    return tuple(
        value
        for value, phrases in mapping.items()
        if any(phrase in text for phrase in phrases)
    )


def _extract_budget_max(text: str) -> float | None:
    matches = re.findall(r"(\d+(?:[.,]\d+)?)\s*(trieu|m|k|nghin|ngan|dong|vnd)?", text)
    for raw_value, unit in reversed(matches):
        value = float(raw_value.replace(",", "."))
        if unit in {"trieu", "m"}:
            value *= 1_000_000
        elif unit in {"k", "nghin", "ngan"}:
            value *= 1_000
        elif not unit and value < 10_000:
            continue
        if 10_000 <= value <= 100_000_000:
            return value
    return None


def _extract_avoid_ingredients(message: str) -> tuple[str, ...]:
    folded = _fold(message)
    values: list[str] = []
    for pattern in (
        r"(?:tranh|di ung voi|khong chua)\s+([^,.;]+)",
    ):
        for match in re.findall(pattern, folded):
            value = re.split(r"\s+(?:va|nhung|voi)\s+", match, maxsplit=1)[0].strip()
            if value and len(value) <= 80:
                values.append(value)
    return tuple(dict.fromkeys(values))
