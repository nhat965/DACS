import importlib.util
import json
import unittest

from recommendation_service.catalog import CatalogRepository
from recommendation_service.llm import (
    LLMCaution,
    LLMConsultation,
    LLMProviderError,
    LLMRecommendation,
    LLMRoutineStep,
)
from recommendation_service.models import Product


FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None


class FakeLLMProvider:
    def __init__(self, result: LLMConsultation | None = None, error: Exception | None = None):
        self.result = result or LLMConsultation(
            response="Mình đã phân tích dựa trên dữ liệu danh mục.",
            recommendations=[],
            followUpQuestions=[],
        )
        self.error = error
        self.prompts: list[str] = []

    async def generate_consultation(self, prompt: str) -> LLMConsultation:
        self.prompts.append(prompt)
        if self.error:
            raise self.error
        return self.result


@unittest.skipUnless(FASTAPI_AVAILABLE, "fastapi is not installed")
class ChatApiTest(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        self.products = [
            Product(
                product_id=1,
                sku="DRY-1",
                name="Serum làm dịu",
                brand="Lumi Lab",
                category="serum",
                price=420_000,
                currency="VND",
                benefits="Cấp ẩm và làm dịu da khô",
                inci_ingredients="Water, Panthenol, Hyaluronic Acid",
                key_ingredients="Panthenol, Hyaluronic Acid",
                skin_types=("dry", "sensitive"),
                skin_concerns=("dryness", "sensitivity"),
                care_goals=("hydrate", "soothe"),
                stock_quantity=12,
            ),
            Product(
                product_id=2,
                sku="DRY-2",
                name="Kem dưỡng phục hồi",
                brand="Lumi Lab",
                category="moisturizer",
                price=650_000,
                currency="VND",
                benefits="Hỗ trợ hàng rào da",
                inci_ingredients="Water, Fragrance, Ceramide",
                skin_types=("dry",),
                skin_concerns=("dryness",),
                care_goals=("hydrate", "repair"),
                stock_quantity=4,
            ),
            Product(
                product_id=3,
                sku="OILY-1",
                name="Gel làm sạch",
                brand="Lumi Lab",
                category="cleanser",
                price=210_000,
                currency="VND",
                skin_types=("oily",),
                skin_concerns=("acne", "oiliness"),
                care_goals=("cleanse", "anti_acne"),
            ),
            Product(
                product_id=4,
                sku="MASK-1",
                name="Mặt nạ làm dịu",
                brand="Lumi Lab",
                category="mask",
                price=280_000,
                currency="VND",
                benefits="Làm dịu tức thì",
                skin_types=(),
                skin_concerns=(),
                care_goals=(),
                stock_quantity=6,
            ),
        ]
        self.provider = FakeLLMProvider()
        self.client = TestClient(
            create_app(
                catalog_repository=CatalogRepository(self.products),
                database_override=None,
                llm_provider_override=self.provider,
            )
        )

    def test_general_skincare_question(self):
        self.provider.result = LLMConsultation(
            response="Bạn nên làm sạch dịu nhẹ và dưỡng ẩm đều đặn.",
            recommendations=[],
            followUpQuestions=["Da bạn có dễ kích ứng không?"],
        )

        response = self.client.post("/chat", json={"message": "Tôi nên chăm sóc da thế nào?"})

        self.assertEqual(response.status_code, 200)
        self.assertIn("dưỡng ẩm", response.json()["response"])
        self.assertEqual(response.json()["recommendedProductIds"], [])

    def test_product_recommendations_return_verified_product_data(self):
        self.provider.result = LLMConsultation(
            response="Serum này phù hợp với nhu cầu làm dịu.",
            recommendations=[
                LLMRecommendation(productId=1, explanation="Khớp da khô và mục tiêu làm dịu.")
            ],
            followUpQuestions=[],
        )

        response = self.client.post(
            "/chat",
            json={"message": "Da khô, tôi cần serum làm dịu"},
        )

        self.assertEqual(response.status_code, 200)
        recommendation = response.json()["recommendations"][0]
        self.assertEqual(recommendation["productId"], 1)
        self.assertEqual(recommendation["product"]["price"], 420_000)

    def test_budget_constraint_filters_expensive_product(self):
        response = self.client.post(
            "/chat",
            json={"message": "Da khô cần cấp ẩm, ngân sách khoảng 500k"},
        )

        self.assertEqual(response.status_code, 200)
        prompt = self.provider.prompts[-1]
        self.assertIn('"budgetMax":500000.0', prompt)
        self.assertIn('"productId":1', prompt)
        self.assertNotIn('"productId":2', prompt)

    def test_natural_long_message_extracts_skin_type(self):
        response = self.client.post(
            "/chat",
            json={
                "message": (
                    "Da của tôi bị khô và tôi cần sản phẩm làm dịu da, mát da "
                    "nhưng tài chính chỉ khoảng 500k."
                )
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["resolvedProfile"]["skinType"], "dry")
        self.assertEqual(response.json()["resolvedProfile"]["budgetMax"], 500_000)

    def test_current_message_overrides_stored_style_profile_for_this_turn(self):
        response = self.client.post(
            "/chat",
            json={
                "message": "Hôm nay tôi muốn tìm sản phẩm cho da dầu dưới 300k",
                "profile": {
                    "skinType": "dry",
                    "budgetMax": 900_000,
                    "budgetCurrency": "VND",
                },
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["resolvedProfile"]["skinType"], "oily")
        self.assertEqual(response.json()["resolvedProfile"]["budgetMax"], 300_000)

    def test_ingredient_exclusion_is_respected(self):
        response = self.client.post(
            "/chat",
            json={
                "message": "Tìm kem dưỡng cho da khô",
                "profile": {
                    "skinType": "dry",
                    "avoidIngredients": ["fragrance"],
                },
            },
        )

        self.assertEqual(response.status_code, 200)
        prompt = self.provider.prompts[-1]
        self.assertIn('"productId":1', prompt)
        self.assertNotIn('"productId":2', prompt)

    def test_missing_product_data_is_marked_explicitly(self):
        response = self.client.post("/chat", json={"message": "Tư vấn chăm sóc da cơ bản"})

        self.assertEqual(response.status_code, 200)
        self.assertIn("KHÔNG_CÓ_DỮ_LIỆU", self.provider.prompts[-1])

    def test_no_suitable_products_supplies_empty_candidate_list(self):
        response = self.client.post(
            "/chat",
            json={
                "message": "Tìm sản phẩm dưới 10 đồng",
                "profile": {"budgetMax": 10, "budgetCurrency": "VND"},
            },
        )

        self.assertEqual(response.status_code, 200)
        payload = json.loads(self.provider.prompts[-1].split("\n\n", 1)[1])
        self.assertEqual(payload["verifiedCandidateProducts"], [])

    def test_invalid_product_ids_from_llm_are_removed(self):
        self.provider.result = LLMConsultation(
            response="Đây là kết quả.",
            recommendations=[
                LLMRecommendation(productId=999, explanation="Không có thật"),
                LLMRecommendation(productId=1, explanation="Có trong danh mục"),
            ],
            followUpQuestions=[],
        )

        response = self.client.post("/chat", json={"message": "Da khô cần serum"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["recommendedProductIds"], [1])

    def test_llm_api_failure_returns_catalog_grounded_fallback(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        provider = FakeLLMProvider(error=LLMProviderError("Gemini quá tải"))
        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository(self.products),
                database_override=None,
                llm_provider_override=provider,
            )
        )

        response = client.post("/chat", json={"message": "Tư vấn cho tôi"})

        self.assertEqual(response.status_code, 200)
        self.assertIn("đang phản hồi chậm", response.json()["response"])
        self.assertTrue(response.json()["recommendations"])

    def test_unconfigured_llm_still_reports_service_unavailable(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        provider = FakeLLMProvider(
            error=LLMProviderError("Gemini chưa được cấu hình", unavailable=True)
        )
        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository(self.products),
                database_override=None,
                llm_provider_override=provider,
            )
        )

        response = client.post("/chat", json={"message": "Tư vấn cho tôi"})

        self.assertEqual(response.status_code, 503)

    def test_multi_turn_history_is_bounded_and_forwarded(self):
        history = [
            {"role": "user" if index % 2 == 0 else "assistant", "content": f"Lượt {index}"}
            for index in range(10)
        ]

        response = self.client.post(
            "/chat",
            json={"message": "Vậy loại nào dưới 500k?", "history": history},
        )

        self.assertEqual(response.status_code, 200)
        prompt = self.provider.prompts[-1]
        self.assertIn("Lượt 0", prompt)
        self.assertIn("Lượt 9", prompt)
        too_many = self.client.post(
            "/chat",
            json={"message": "Tiếp tục", "history": history + [history[0]]},
        )
        self.assertEqual(too_many.status_code, 422)

    def test_multi_turn_context_is_reused_for_retrieval(self):
        response = self.client.post(
            "/chat",
            json={
                "message": "Vậy loại nào dưới 500k?",
                "history": [
                    {"role": "user", "content": "Da tôi khô và nhạy cảm"},
                    {
                        "role": "assistant",
                        "content": "Bạn muốn ưu tiên mục tiêu nào?",
                    },
                    {"role": "user", "content": "Tôi muốn cấp ẩm và làm dịu"},
                ],
            },
        )

        self.assertEqual(response.status_code, 200)
        profile = response.json()["resolvedProfile"]
        self.assertEqual(profile["skinType"], "dry")
        self.assertIn("hydrate", profile["careGoals"])
        self.assertEqual(profile["budgetMax"], 500_000)

    def test_current_category_focus_keeps_history_as_ranking_not_exclusion(self):
        response = self.client.post(
            "/chat",
            json={
                "message": "Tôi muốn tìm mặt nạ dưới 500k",
                "history": [
                    {"role": "user", "content": "Da tôi khô và nhạy cảm"},
                    {"role": "user", "content": "Tôi cần làm dịu da"},
                ],
            },
        )

        self.assertEqual(response.status_code, 200)
        prompt = self.provider.prompts[-1]
        self.assertIn('"productId":4', prompt)
        self.assertIn('"category":"mask"', prompt)
        self.assertNotIn('"productId":2', prompt)

    def test_missing_skin_information_gets_deterministic_follow_up(self):
        self.provider.result = LLMConsultation(
            response="Mình cần hiểu làn da trước khi gợi ý.",
            recommendations=[],
            followUpQuestions=[],
            consultationType="recommendation",
        )

        response = self.client.post(
            "/chat",
            json={"message": "Tư vấn cho tôi một sản phẩm tốt"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("Loại da hiện tại", response.json()["missingInformation"])
        self.assertIn("Da của bạn thuộc loại", response.json()["followUpQuestions"][0])

    def test_routine_is_structured_and_product_ids_are_validated(self):
        self.provider.result = LLMConsultation(
            response="Đây là routine tối giản cho da khô.",
            recommendations=[
                LLMRecommendation(productId=1, explanation="Phù hợp để cấp ẩm.")
            ],
            followUpQuestions=[],
            consultationType="routine",
            routine=[
                LLMRoutineStep(
                    order=1,
                    timeOfDay="both",
                    label="Làm sạch dịu nhẹ",
                    productId=None,
                    instruction="Dùng nước ấm và không chà xát.",
                    reason="Giảm nguy cơ khô căng.",
                ),
                LLMRoutineStep(
                    order=2,
                    timeOfDay="both",
                    label="Cấp ẩm",
                    productId=1,
                    instruction="Thoa trên nền da còn hơi ẩm.",
                    reason="Hỗ trợ làm dịu da khô.",
                ),
                LLMRoutineStep(
                    order=3,
                    timeOfDay="evening",
                    label="Sản phẩm không hợp lệ",
                    productId=999,
                    instruction="Không được trả về.",
                    reason="ID không thuộc catalog.",
                ),
            ],
        )

        response = self.client.post(
            "/chat",
            json={"message": "Lập routine cho da khô dưới 500k"},
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["consultationType"], "routine")
        self.assertEqual(len(body["routine"]), 2)
        self.assertIsNone(body["routine"][0]["productId"])
        self.assertEqual(body["routine"][1]["productId"], 1)
        self.assertEqual(body["routine"][1]["product"]["name"], "Serum làm dịu")

    def test_total_budget_is_enforced_for_recommendations_and_routine(self):
        affordable_second = Product(
            product_id=5,
            sku="DRY-5",
            name="Xịt khoáng làm dịu",
            brand="Lumi Lab",
            category="toner",
            price=200_000,
            currency="VND",
            skin_types=("dry",),
            skin_concerns=("dryness",),
            care_goals=("hydrate", "soothe"),
        )
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        provider = FakeLLMProvider(
            LLMConsultation(
                response="Routine theo ngân sách.",
                recommendations=[
                    LLMRecommendation(productId=1, explanation="Cấp ẩm"),
                    LLMRecommendation(productId=5, explanation="Làm dịu"),
                ],
                followUpQuestions=[],
                consultationType="routine",
                routine=[
                    LLMRoutineStep(
                        order=1,
                        timeOfDay="both",
                        label="Serum",
                        productId=1,
                        instruction="Thoa mỏng.",
                    ),
                    LLMRoutineStep(
                        order=2,
                        timeOfDay="both",
                        label="Xịt khoáng",
                        productId=5,
                        instruction="Dùng khi cần.",
                    ),
                ],
            )
        )
        client = TestClient(
            create_app(
                catalog_repository=CatalogRepository([*self.products, affordable_second]),
                database_override=None,
                llm_provider_override=provider,
            )
        )

        response = client.post(
            "/chat",
            json={"message": "Routine da khô tổng ngân sách 500k"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["recommendedProductIds"], [1])
        self.assertEqual([item["productId"] for item in response.json()["routine"]], [1])

    def test_cautions_and_missing_information_are_returned(self):
        self.provider.result = LLMConsultation(
            response="Mình cần thêm thông tin trước khi chốt routine.",
            recommendations=[],
            followUpQuestions=["Da bạn có dễ kích ứng không?"],
            consultationType="safety",
            cautions=[
                LLMCaution(
                    severity="medical",
                    title="Cần đánh giá chuyên môn",
                    detail="Nếu da sưng đau hoặc rỉ dịch, hãy gặp bác sĩ da liễu.",
                )
            ],
            missingInformation=["Mức độ nhạy cảm của da"],
        )

        response = self.client.post("/chat", json={"message": "Da tôi đang rất đỏ"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["consultationType"], "safety")
        self.assertEqual(response.json()["cautions"][0]["severity"], "medical")
        self.assertEqual(
            response.json()["missingInformation"],
            ["Mức độ nhạy cảm của da"],
        )


if __name__ == "__main__":
    unittest.main()
