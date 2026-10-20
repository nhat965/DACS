from __future__ import annotations

import logging
import os
from typing import Any, Protocol

from pydantic import BaseModel, Field, ValidationError


logger = logging.getLogger(__name__)


class LLMRecommendation(BaseModel):
    productId: int = Field(gt=0)
    explanation: str = Field(min_length=1, max_length=600)


class LLMRoutineStep(BaseModel):
    order: int = Field(ge=1, le=10)
    timeOfDay: str = Field(pattern=r"^(morning|evening|both|weekly)$")
    label: str = Field(min_length=1, max_length=120)
    productId: int | None = Field(default=None, gt=0)
    instruction: str = Field(min_length=1, max_length=500)
    reason: str = Field(default="", max_length=500)


class LLMCaution(BaseModel):
    severity: str = Field(pattern=r"^(info|warning|medical)$")
    title: str = Field(min_length=1, max_length=120)
    detail: str = Field(min_length=1, max_length=700)


class LLMConsultation(BaseModel):
    response: str = Field(min_length=1, max_length=5000)
    recommendations: list[LLMRecommendation] = Field(max_length=5)
    followUpQuestions: list[str] = Field(max_length=4)
    consultationType: str = Field(
        default="recommendation",
        pattern=r"^(general|recommendation|routine|comparison|safety)$",
    )
    routine: list[LLMRoutineStep] = Field(default_factory=list, max_length=10)
    cautions: list[LLMCaution] = Field(default_factory=list, max_length=5)
    missingInformation: list[str] = Field(default_factory=list, max_length=5)


class LLMProviderError(RuntimeError):
    def __init__(self, message: str, *, unavailable: bool = False):
        super().__init__(message)
        self.unavailable = unavailable


class LLMProvider(Protocol):
    async def generate_consultation(self, prompt: str) -> LLMConsultation:
        ...


class UnavailableLLMProvider:
    def __init__(self, reason: str):
        self.reason = reason

    async def generate_consultation(self, prompt: str) -> LLMConsultation:
        del prompt
        raise LLMProviderError(self.reason, unavailable=True)


class GeminiLLMProvider:
    """Gemini Developer API adapter. The SDK is imported only by the backend."""

    _RESPONSE_SCHEMA: dict[str, Any] = {
        "type": "object",
        "properties": {
            "response": {"type": "string"},
            "recommendations": {
                "type": "array",
                "maxItems": 5,
                "items": {
                    "type": "object",
                    "properties": {
                        "productId": {"type": "integer"},
                        "explanation": {"type": "string"},
                    },
                    "required": ["productId", "explanation"],
                },
            },
            "followUpQuestions": {
                "type": "array",
                "maxItems": 4,
                "items": {"type": "string"},
            },
            "consultationType": {
                "type": "string",
                "enum": ["general", "recommendation", "routine", "comparison", "safety"],
            },
            "routine": {
                "type": "array",
                "maxItems": 10,
                "items": {
                    "type": "object",
                    "properties": {
                        "order": {"type": "integer"},
                        "timeOfDay": {
                            "type": "string",
                            "enum": ["morning", "evening", "both", "weekly"],
                        },
                        "label": {"type": "string"},
                        "productId": {"anyOf": [{"type": "integer"}, {"type": "null"}]},
                        "instruction": {"type": "string"},
                        "reason": {"type": "string"},
                    },
                    "required": [
                        "order", "timeOfDay", "label", "productId", "instruction", "reason"
                    ],
                },
            },
            "cautions": {
                "type": "array",
                "maxItems": 5,
                "items": {
                    "type": "object",
                    "properties": {
                        "severity": {
                            "type": "string",
                            "enum": ["info", "warning", "medical"],
                        },
                        "title": {"type": "string"},
                        "detail": {"type": "string"},
                    },
                    "required": ["severity", "title", "detail"],
                },
            },
            "missingInformation": {
                "type": "array",
                "maxItems": 5,
                "items": {"type": "string"},
            },
        },
        "required": [
            "response",
            "recommendations",
            "followUpQuestions",
            "consultationType",
            "routine",
            "cautions",
            "missingInformation",
        ],
    }

    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        timeout_seconds: float = 20,
    ):
        try:
            from google import genai
            from google.genai import types
        except ImportError as exc:  # pragma: no cover - installation guard
            raise LLMProviderError(
                "Google Gen AI SDK is not installed. Install backend requirements.",
                unavailable=True,
            ) from exc

        retry_options = types.HttpRetryOptions(
            attempts=2,
            initial_delay=0.5,
            max_delay=4,
            exp_base=2,
            jitter=0.2,
            http_status_codes=[429, 500, 502, 503, 504],
        )
        self._client = genai.Client(
            api_key=api_key,
            http_options=types.HttpOptions(
                timeout=max(1000, int(timeout_seconds * 1000)),
                retry_options=retry_options,
            ),
        )
        self._types = types
        self.model = model

    async def generate_consultation(self, prompt: str) -> LLMConsultation:
        try:
            response = await self._client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
                config=self._types.GenerateContentConfig(
                    system_instruction=(
                        "Bạn là Lumi AI, chuyên viên tư vấn mỹ phẩm bằng tiếng Việt. "
                        "Chỉ sử dụng dữ liệu sản phẩm được cung cấp, không chẩn đoán bệnh "
                        "và không tự tạo tên, giá, thành phần, công dụng hay tồn kho. "
                        "Ưu tiên câu trả lời có thể hành động: hỏi lại khi thiếu dữ kiện, "
                        "xếp routine đúng thứ tự và nêu cảnh báo an toàn ngắn gọn."
                    ),
                    temperature=0.2,
                    max_output_tokens=1800,
                    response_mime_type="application/json",
                    response_json_schema=self._RESPONSE_SCHEMA,
                ),
            )
            if not response.text:
                raise LLMProviderError("Gemini returned an empty response")
            return LLMConsultation.model_validate_json(response.text)
        except LLMProviderError:
            raise
        except ValidationError as exc:
            logger.warning("gemini_invalid_structured_response error_type=%s", type(exc).__name__)
            raise LLMProviderError("Gemini returned an invalid structured response") from exc
        except Exception as exc:
            logger.warning("gemini_request_failed error_type=%s", type(exc).__name__)
            raise LLMProviderError("Gemini is temporarily unavailable") from exc


def build_llm_provider_from_env() -> LLMProvider:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        return UnavailableLLMProvider(
            "Lumi AI is not configured. Set GEMINI_API_KEY on the backend."
        )
    model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite").strip() or "gemini-3.5-flash-lite"
    try:
        timeout_seconds = float(os.getenv("GEMINI_TIMEOUT_SECONDS", "15"))
    except ValueError:
        timeout_seconds = 15
    try:
        return GeminiLLMProvider(
            api_key=api_key,
            model=model,
            timeout_seconds=max(1, min(timeout_seconds, 60)),
        )
    except LLMProviderError as exc:
        logger.error("gemini_provider_unavailable reason=%s", str(exc))
        return UnavailableLLMProvider(str(exc))
