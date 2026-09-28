"""Immutable data contract for the cosmetic product pipeline.

This module deliberately mirrors the currently agreed production contract.
Do not add production fields or enum values here without an approved contract change.
"""

from __future__ import annotations

PRODUCTION_PRODUCT_FIELDS = (
    "sku",
    "name",
    "brand_id",
    "category_id",
    "price",
    "currency",
    "volume",
    "stock_quantity",
    "description",
    "benefits",
    "inci_ingredients",
    "key_ingredients",
    "skin_types",
    "skin_concerns",
    "care_goals",
    "texture",
    "usage_instruction",
    "warnings",
    "image_url",
    "source_url",
    "verified_at",
    "status",
    "ai_ready",
)

API_PRODUCT_FIELDS = (
    "id",
    "sku",
    "name",
    "brandId",
    "brandName",
    "categoryId",
    "categoryName",
    "price",
    "volume",
    "stockQuantity",
    "description",
    "benefits",
    "inciIngredients",
    "keyIngredients",
    "skinTypes",
    "skinConcerns",
    "careGoals",
    "texture",
    "usageInstruction",
    "warnings",
    "imageUrl",
    "status",
)

SKIN_TYPES = frozenset({"normal", "dry", "oily", "combination", "sensitive"})
SKIN_CONCERNS = frozenset(
    {
        "acne",
        "dark_spot",
        "dryness",
        "aging",
        "redness",
        "large_pores",
        "dullness",
        "uneven_texture",
        "oiliness",
        "sensitivity",
    }
)
CARE_GOALS = frozenset(
    {
        "cleanse",
        "hydrate",
        "brighten",
        "anti_acne",
        "anti_aging",
        "repair",
        "soothe",
        "oil_control",
        "sun_protection",
        "exfoliate",
    }
)
CATEGORY_CODES = frozenset(
    {
        "cleanser",
        "toner",
        "serum",
        "moisturizer",
        "sunscreen",
        "exfoliant",
        "mask",
        "makeup_remover",
        "eye_care",
        "lip_care",
        "body_care",
    }
)
PRODUCT_STATUSES = frozenset({"ACTIVE", "INACTIVE", "DRAFT"})

# Hard production requirements come from the current DB schema / import semantics.
# brand_id/category_id are resolved at import time, so the processed layer validates
# normalized brand/category instead of requiring DB IDs prematurely.
PROCESSED_IDENTITY_REQUIRED = ("name", "brand_normalized", "category_normalized", "source_url")
PRODUCTION_IMPORT_REQUIRED = (
    "sku", "name", "brand_id", "category_id", "price", "currency",
    "stock_quantity", "status", "ai_ready",
)

FIELD_CLASSIFICATION = {
    "required": (
        "name", "brand_normalized", "category_normalized", "sku", "price",
        "currency", "source_url",
    ),
    "recommended": (
        "description", "benefits", "inci_ingredients", "skin_types",
        "skin_concerns", "care_goals", "usage_instruction", "warnings",
    ),
    "optional": ("volume", "key_ingredients", "texture", "image_url"),
}

REJECTION_CODES = frozenset({
    "MISSING_NAME",
    "MISSING_BRAND",
    "MISSING_CATEGORY",
    "MISSING_SKU",
    "INVALID_PRICE",
    "INVALID_CURRENCY",
    "INVALID_SOURCE",
    "INSUFFICIENT_AI_FEATURES",
    "DUPLICATE_PRODUCT",
    "MALFORMED_PRODUCT",
})

# AI quality weights intentionally favor semantic accuracy and provenance.
AI_FIELD_WEIGHTS = {
    "description": 12,
    "benefits": 14,
    "inci_ingredients": 18,
    "key_ingredients": 10,
    "skin_types": 10,
    "skin_concerns": 10,
    "care_goals": 10,
    "usage_instruction": 6,
    "warnings": 4,
    "texture": 2,
    "volume": 2,
    "image_url": 2,
}


# Core product knowledge is shared by website product-detail content and AI/RAG.
# These are existing production fields; this list only drives internal quality metrics.
CORE_PRODUCT_KNOWLEDGE_FIELDS = (
    "description",
    "benefits",
    "inci_ingredients",
    "key_ingredients",
    "skin_types",
    "skin_concerns",
    "care_goals",
    "usage_instruction",
    "warnings",
)

AI_READY_SCORE_THRESHOLD = 70

# A record cannot be AI-ready when these high-value semantic groups are all missing.
AI_SEMANTIC_MINIMUM_GROUPS = (
    ("description", "benefits"),
    ("inci_ingredients", "key_ingredients"),
    ("skin_types", "skin_concerns", "care_goals"),
)
