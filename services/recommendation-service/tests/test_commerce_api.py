import importlib.util
import unittest

from recommendation_service.auth import AuthSettings, hash_password
from recommendation_service.catalog import CatalogRepository
from recommendation_service.commerce import (
    CommerceValidationError,
    DuplicateEmailError,
    UserRecord,
)
from recommendation_service.models import Product


FASTAPI_AVAILABLE = importlib.util.find_spec("fastapi") is not None


class FakeCommerceRepository:
    def __init__(self):
        self.users: dict[int, UserRecord] = {
            99: UserRecord(
                id=99,
                full_name="Administrator",
                email="admin@lumi.test",
                password_hash=hash_password("Admin123"),
                role="ADMIN",
            )
        }
        self.orders: list[dict] = []
        self.preferences: dict[int, dict] = {}

    def create_user(self, *, full_name, email, password_hash):
        if self.get_user_by_email(email):
            raise DuplicateEmailError(email)
        user = UserRecord(
            id=max(self.users) + 1,
            full_name=full_name,
            email=email,
            password_hash=password_hash,
            role="CUSTOMER",
        )
        self.users[user.id] = user
        return user

    def get_user_by_email(self, email):
        return next((user for user in self.users.values() if user.email == email), None)

    def get_user_by_id(self, user_id):
        return self.users.get(user_id)

    def create_order(self, *, user_id, items, currency, **shipping):
        if currency != "USD":
            raise CommerceValidationError("All products must use the checkout currency")
        prices = {1: 15.0, 2: 30.0}
        total = sum(prices[item["productId"]] * item["quantity"] for item in items)
        order = {
            "orderId": len(self.orders) + 1,
            "userId": user_id,
            "status": "PENDING",
            "totalAmount": total,
            "currency": currency,
            "shippingName": shipping["shipping_name"],
            "shippingPhone": shipping["shipping_phone"],
            "shippingAddress": shipping["shipping_address"],
            "note": shipping["note"],
            "paymentMethod": shipping["payment_method"],
            "createdAt": "2026-09-28T00:00:00",
            "items": [
                {
                    "productId": item["productId"],
                    "productName": f"Product {item['productId']}",
                    "quantity": item["quantity"],
                    "unitPrice": prices[item["productId"]],
                }
                for item in items
            ],
        }
        self.orders.append(order)
        return order

    def list_orders(self, *, user_id=None):
        if user_id is None:
            return list(self.orders)
        return [order for order in self.orders if order["userId"] == user_id]

    def get_preferences(self, user_id):
        return self.preferences.get(
            user_id,
            {
                "skinType": None,
                "skinConcerns": [],
                "careGoals": [],
                "preferredCategories": [],
                "preferredBrands": [],
                "avoidIngredients": [],
                "budgetMin": None,
                "budgetMax": None,
                "currency": "USD",
                "completed": False,
            },
        )

    def save_preferences(self, user_id, preferences):
        stored = {**preferences, "completed": True}
        self.preferences[user_id] = stored
        return stored


@unittest.skipUnless(FASTAPI_AVAILABLE, "fastapi is not installed")
class CommerceApiTest(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        from recommendation_service.api import create_app

        products = [
            Product(1, "P1", "Cleanser", "COSRX", "cleanser", 15, "USD"),
            Product(2, "P2", "Serum", "COSRX", "serum", 30, "USD"),
        ]
        self.repository = FakeCommerceRepository()
        self.client = TestClient(
            create_app(
                catalog_repository=CatalogRepository(products),
                database_override=None,
                commerce_repository_override=self.repository,
                auth_settings_override=AuthSettings(
                    jwt_secret="commerce-test-secret", token_ttl_seconds=3600
                ),
            )
        )

    def _register(self):
        return self.client.post(
            "/auth/register",
            json={
                "fullName": "Lumi Customer",
                "email": "customer@lumi.test",
                "password": "Secret123",
            },
        )

    def test_register_login_and_profile_flow(self):
        registered = self._register()
        self.assertEqual(registered.status_code, 201)
        token = registered.json()["accessToken"]
        self.assertEqual(registered.json()["user"]["role"], "CUSTOMER")

        duplicate = self._register()
        self.assertEqual(duplicate.status_code, 409)

        profile = self.client.get(
            "/auth/profile", headers={"Authorization": f"Bearer {token}"}
        )
        self.assertEqual(profile.status_code, 200)
        self.assertEqual(profile.json()["email"], "customer@lumi.test")

        login = self.client.post(
            "/auth/login",
            json={"email": "customer@lumi.test", "password": "Secret123"},
        )
        self.assertEqual(login.status_code, 200)

        wrong_password = self.client.post(
            "/auth/login",
            json={"email": "customer@lumi.test", "password": "incorrect"},
        )
        self.assertEqual(wrong_password.status_code, 401)

    def test_customer_can_save_and_restore_beauty_preferences(self):
        token = self._register().json()["accessToken"]
        headers = {"Authorization": f"Bearer {token}"}
        saved = self.client.put(
            "/users/me/preferences",
            headers=headers,
            json={
                "skinType": "oily",
                "skinConcerns": ["acne", "oiliness"],
                "careGoals": ["anti_acne", "oil_control"],
                "preferredCategories": ["serum"],
                "budgetMin": 10,
                "budgetMax": 40,
                "budgetCurrency": "USD",
                "currency": "USD",
            },
        )

        self.assertEqual(saved.status_code, 200)
        self.assertTrue(saved.json()["completed"])
        restored = self.client.get("/users/me/preferences", headers=headers)
        self.assertEqual(restored.status_code, 200)
        self.assertEqual(restored.json()["skinType"], "oily")

    def test_customer_can_create_and_list_authoritative_order(self):
        token = self._register().json()["accessToken"]
        headers = {"Authorization": f"Bearer {token}"}
        response = self.client.post(
            "/orders",
            headers=headers,
            json={
                "items": [{"productId": 1, "quantity": 2}],
                "currency": "USD",
                "shippingName": "Lumi Customer",
                "shippingPhone": "0900000000",
                "shippingAddress": "1 Beauty Street",
                "paymentMethod": "COD",
            },
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["totalAmount"], 30.0)
        self.assertEqual(response.json()["status"], "PENDING")

        listing = self.client.get("/orders", headers=headers)
        self.assertEqual(listing.status_code, 200)
        self.assertEqual(listing.json()["total"], 1)

    def test_currency_mismatch_and_admin_authorization(self):
        customer_token = self._register().json()["accessToken"]
        customer_headers = {"Authorization": f"Bearer {customer_token}"}
        mismatch = self.client.post(
            "/orders",
            headers=customer_headers,
            json={
                "items": [{"productId": 1, "quantity": 1}],
                "currency": "VND",
                "shippingName": "Lumi Customer",
                "shippingPhone": "0900000000",
                "shippingAddress": "1 Beauty Street",
                "paymentMethod": "COD",
            },
        )
        self.assertEqual(mismatch.status_code, 422)
        self.assertEqual(
            self.client.get("/admin/orders", headers=customer_headers).status_code,
            403,
        )

        admin_login = self.client.post(
            "/auth/login",
            json={"email": "admin@lumi.test", "password": "Admin123"},
        )
        admin_headers = {
            "Authorization": f"Bearer {admin_login.json()['accessToken']}"
        }
        self.assertEqual(
            self.client.get("/admin/orders", headers=admin_headers).status_code,
            200,
        )


if __name__ == "__main__":
    unittest.main()
