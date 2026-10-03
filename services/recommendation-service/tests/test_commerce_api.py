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
        self.reviews: dict[tuple[int, int], dict] = {}
        self.preferences: dict[int, dict] = {}
        self.products: dict[int, dict] = {
            1: {
                "productId": 1,
                "sku": "P1",
                "name": "Cleanser",
                "brand": "COSRX",
                "category": "cleanser",
                "price": 15.0,
                "currency": "USD",
                "stockQuantity": 8,
                "description": "Gentle cleanser",
                "benefits": "Cleanses skin",
                "inciIngredients": "Water",
                "keyIngredients": "Water",
                "skinTypes": ["oily"],
                "skinConcerns": ["acne"],
                "careGoals": ["oil_control"],
                "texture": "gel",
                "usageInstruction": "Use daily",
                "warnings": "",
                "imageUrl": "https://example.test/p1.jpg",
                "sourceUrl": "https://example.test/p1",
                "status": "ACTIVE",
                "aiReady": True,
                "createdAt": "2026-09-28T00:00:00",
                "updatedAt": "2026-09-28T00:00:00",
            }
        }

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

    def list_product_reviews(
        self, *, product_id, viewer_user_id=None, limit=20, offset=0
    ):
        items = [
            {**review, "isMine": review["userId"] == viewer_user_id}
            for (review_product_id, _), review in self.reviews.items()
            if review_product_id == product_id
        ]
        ratings = [item["rating"] for item in items]
        return {
            "items": items[offset : offset + limit],
            "total": len(items),
            "averageRating": sum(ratings) / len(ratings) if ratings else None,
            "limit": limit,
            "offset": offset,
        }

    def save_product_review(self, *, user_id, product_id, rating, comment):
        if product_id not in self.products:
            raise CommerceValidationError("Product not found")
        review = {
            "reviewId": len(self.reviews) + 1,
            "productId": product_id,
            "userId": user_id,
            "authorName": self.users[user_id].full_name,
            "rating": rating,
            "comment": comment,
            "createdAt": "2026-09-30T00:00:00",
            "updatedAt": "2026-09-30T00:00:00",
            "isMine": True,
        }
        self.reviews[(product_id, user_id)] = review
        return review

    def get_order(self, *, order_id):
        return next((order for order in self.orders if order["orderId"] == order_id), None)

    def update_order_status(self, order_id, status):
        order = self.get_order(order_id=order_id)
        if order is None:
            raise CommerceValidationError("Order not found")
        allowed = {
            "PENDING": {"CONFIRMED", "CANCELED"},
            "CONFIRMED": {"PROCESSING", "CANCELED"},
            "PROCESSING": {"SHIPPING", "CANCELED"},
            "SHIPPING": {"COMPLETED"},
        }
        if status not in allowed.get(order["status"], set()):
            raise CommerceValidationError("Invalid order status transition")
        order["status"] = status
        return order

    def get_admin_metrics(self):
        return {"totalProducts": len(self.products), "aiReadyProducts": 1, "productionCandidates": 1, "orders": len(self.orders), "users": len(self.users), "recommendationRequests": 0}

    def get_admin_dashboard(self):
        return {"totalProducts": len(self.products), "aiReadyProducts": 1, "lowStockProducts": 1, "users": 1, "orders": len(self.orders), "pendingOrders": len([order for order in self.orders if order["status"] == "PENDING"]), "ordersToday": 0, "recommendationRequests": 0, "orderStatuses": {}, "revenueByCurrency": {}}

    def get_admin_data_quality(self):
        return {"totalProducts": 1, "inciComplete": 1, "skinTypeComplete": 1, "concernComplete": 1, "careGoalComplete": 1, "imageComplete": 1, "priceComplete": 1, "aiReadyProducts": 1}

    def get_admin_reports(self):
        return {"revenueTrend": [], "bestSellers": [], "lowStock": []}

    def get_admin_behavior_analytics(self):
        return {"totalEvents": 0, "uniqueUsers": 0, "uniqueSessions": 0, "events": []}

    def get_admin_recommendation_analytics(self):
        return {"totalRequests": 0, "totalResults": 0, "algorithms": [], "clickThroughRate": None}

    def list_active_promotions(self):
        return {"items": [], "promotions": []}

    def list_admin_products(self, *, search=None, status=None, limit=25, offset=0):
        items = list(self.products.values())
        if search:
            term = search.lower()
            items = [item for item in items if term in item["name"].lower() or term in item["sku"].lower()]
        if status:
            items = [item for item in items if item["status"] == status]
        return {"items": items[offset:offset + limit], "total": len(items), "limit": limit, "offset": offset}

    def get_admin_product(self, product_id):
        return self.products.get(product_id)

    def save_admin_product(self, *, payload, product_id=None):
        product_id = product_id or max(self.products) + 1
        product = {"productId": product_id, **payload, "createdAt": "2026-09-30T00:00:00", "updatedAt": "2026-09-30T00:00:00"}
        self.products[product_id] = product
        return product

    def update_product_status(self, product_id, status):
        product = self.products.get(product_id)
        if product is None:
            raise CommerceValidationError("Product not found")
        product["status"] = status
        return product

    def update_product_stock(self, product_id, stock):
        product = self.products.get(product_id)
        if product is None:
            raise CommerceValidationError("Product not found")
        product["stockQuantity"] = stock
        return product

    def list_admin_users(self, *, search=None):
        users = [{"userId": user.id, "fullName": user.full_name, "email": user.email, "role": user.role, "skinType": user.skin_type, "orderCount": len(self.list_orders(user_id=user.id)), "createdAt": "2026-09-28T00:00:00"} for user in self.users.values()]
        if search:
            term = search.lower()
            users = [user for user in users if term in user["fullName"].lower() or term in user["email"].lower()]
        return users

    def get_admin_user(self, user_id):
        user = next((item for item in self.list_admin_users() if item["userId"] == user_id), None)
        if user is None:
            return None
        return {**user, "preferences": self.get_preferences(user_id), "orders": self.list_orders(user_id=user_id)}

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

    def test_customer_can_create_update_and_read_product_review(self):
        empty = self.client.get("/products/1/reviews")
        self.assertEqual(empty.status_code, 200)
        self.assertEqual(empty.json()["total"], 0)

        token = self._register().json()["accessToken"]
        headers = {"Authorization": f"Bearer {token}"}
        created = self.client.post(
            "/products/1/reviews",
            headers=headers,
            json={"rating": 5, "comment": "Dịu nhẹ và dễ sử dụng."},
        )
        self.assertEqual(created.status_code, 201)
        self.assertEqual(created.json()["rating"], 5)

        updated = self.client.post(
            "/products/1/reviews",
            headers=headers,
            json={"rating": 4, "comment": "Dùng tốt, tôi sẽ tiếp tục theo dõi."},
        )
        self.assertEqual(updated.status_code, 201)
        self.assertEqual(len(self.repository.reviews), 1)

        listing = self.client.get("/products/1/reviews", headers=headers)
        self.assertEqual(listing.json()["total"], 1)
        self.assertEqual(listing.json()["averageRating"], 4)
        self.assertTrue(listing.json()["items"][0]["isMine"])

    def test_product_review_requires_login_and_valid_content(self):
        guest = self.client.post(
            "/products/1/reviews",
            json={"rating": 5, "comment": "Sản phẩm tốt."},
        )
        self.assertEqual(guest.status_code, 401)

        token = self._register().json()["accessToken"]
        headers = {"Authorization": f"Bearer {token}"}
        invalid = self.client.post(
            "/products/1/reviews",
            headers=headers,
            json={"rating": 6, "comment": "  "},
        )
        self.assertEqual(invalid.status_code, 422)

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

    def test_admin_operational_endpoints_are_protected_and_functional(self):
        customer_token = self._register().json()["accessToken"]
        customer_headers = {"Authorization": f"Bearer {customer_token}"}
        for path in ("/admin/dashboard", "/admin/data-quality", "/admin/reports", "/admin/behavior-analytics", "/admin/recommendation-analytics", "/admin/products", "/admin/inventory", "/admin/users"):
            self.assertEqual(self.client.get(path, headers=customer_headers).status_code, 403)

        admin_login = self.client.post("/auth/login", json={"email": "admin@lumi.test", "password": "Admin123"})
        admin_headers = {"Authorization": f"Bearer {admin_login.json()['accessToken']}"}
        self.assertEqual(self.client.get("/admin/dashboard", headers=admin_headers).status_code, 200)
        self.assertEqual(self.client.get("/admin/data-quality", headers=admin_headers).json()["inciComplete"], 1)
        self.assertEqual(self.client.get("/admin/reports", headers=admin_headers).json()["bestSellers"], [])
        self.assertEqual(self.client.get("/admin/behavior-analytics", headers=admin_headers).json()["totalEvents"], 0)
        self.assertEqual(self.client.get("/admin/recommendation-analytics", headers=admin_headers).json()["totalRequests"], 0)
        self.assertEqual(self.client.get("/promotions/active").json()["items"], [])
        products = self.client.get("/admin/products", headers=admin_headers)
        self.assertEqual(products.status_code, 200)
        self.assertEqual(products.json()["total"], 1)
        stock = self.client.patch("/admin/products/1/stock", headers=admin_headers, json={"stockQuantity": 4})
        self.assertEqual(stock.status_code, 200)
        self.assertEqual(stock.json()["stockQuantity"], 4)
        self.assertEqual(self.client.get("/admin/users", headers=admin_headers).status_code, 200)

    def test_admin_order_status_transition(self):
        customer_token = self._register().json()["accessToken"]
        order = self.client.post(
            "/orders",
            headers={"Authorization": f"Bearer {customer_token}"},
            json={"items": [{"productId": 1, "quantity": 1}], "currency": "USD", "shippingName": "Lumi Customer", "shippingPhone": "0900000000", "shippingAddress": "1 Beauty Street", "paymentMethod": "COD"},
        ).json()
        admin_login = self.client.post("/auth/login", json={"email": "admin@lumi.test", "password": "Admin123"})
        headers = {"Authorization": f"Bearer {admin_login.json()['accessToken']}"}
        updated = self.client.patch(f"/admin/orders/{order['orderId']}/status", headers=headers, json={"status": "CONFIRMED"})
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.json()["status"], "CONFIRMED")
        invalid = self.client.patch(f"/admin/orders/{order['orderId']}/status", headers=headers, json={"status": "COMPLETED"})
        self.assertEqual(invalid.status_code, 409)


if __name__ == "__main__":
    unittest.main()
