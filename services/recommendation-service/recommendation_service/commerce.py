from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from .database import RecommendationDatabase


class DuplicateEmailError(ValueError):
    pass


class CommerceValidationError(ValueError):
    pass


@dataclass(frozen=True)
class UserRecord:
    id: int
    full_name: str
    email: str
    password_hash: str
    role: str
    skin_type: str | None = None


class MySQLCommerceRepository:
    def __init__(self, database: RecommendationDatabase):
        self.database = database

    def create_user(self, *, full_name: str, email: str, password_hash: str) -> UserRecord:
        conn = self.database.connect()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO users (full_name, email, password_hash, role)
                VALUES (%s, %s, %s, 'CUSTOMER')
                """,
                (full_name.strip(), email.strip().lower(), password_hash),
            )
            user_id = int(cursor.lastrowid)
            conn.commit()
        except Exception as exc:
            conn.rollback()
            if getattr(exc, "errno", None) == 1062:
                raise DuplicateEmailError(email) from exc
            raise
        finally:
            conn.close()
        user = self.get_user_by_id(user_id)
        if user is None:
            raise RuntimeError("Created user could not be loaded")
        return user

    def ensure_admin(
        self, *, full_name: str, email: str, password_hash: str
    ) -> UserRecord:
        existing = self.get_user_by_email(email)
        if existing is not None:
            if existing.role != "ADMIN":
                raise CommerceValidationError(
                    "ADMIN_EMAIL belongs to a non-admin account; refusing automatic privilege escalation"
                )
            return existing
        conn = self.database.connect()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO users (full_name, email, password_hash, role)
                VALUES (%s, %s, %s, 'ADMIN')
                """,
                (full_name.strip(), email.strip().lower(), password_hash),
            )
            user_id = int(cursor.lastrowid)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
        user = self.get_user_by_id(user_id)
        if user is None:
            raise RuntimeError("Created admin could not be loaded")
        return user

    def get_preferences(self, user_id: int) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT skin_type, skin_concerns, care_goals, preferred_categories,
                       preferred_brands, avoid_ingredients, budget_min, budget_max,
                       budget_currency
                FROM user_profiles
                WHERE user_id = %s
                LIMIT 1
                """,
                (user_id,),
            )
            row = cursor.fetchone() or {}
            return _serialize_preferences(row)
        finally:
            conn.close()

    def save_preferences(self, user_id: int, preferences: dict[str, Any]) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO user_profiles (
                    user_id, skin_type, skin_concerns, care_goals,
                    preferred_categories, preferred_brands, avoid_ingredients,
                    budget_min, budget_max, budget_currency, profile_confidence
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 1)
                ON DUPLICATE KEY UPDATE
                    skin_type = VALUES(skin_type),
                    skin_concerns = VALUES(skin_concerns),
                    care_goals = VALUES(care_goals),
                    preferred_categories = VALUES(preferred_categories),
                    preferred_brands = VALUES(preferred_brands),
                    avoid_ingredients = VALUES(avoid_ingredients),
                    budget_min = VALUES(budget_min),
                    budget_max = VALUES(budget_max),
                    budget_currency = VALUES(budget_currency),
                    profile_confidence = 1
                """,
                (
                    user_id,
                    preferences.get("skinType"),
                    _join_terms(preferences.get("skinConcerns")),
                    _join_terms(preferences.get("careGoals")),
                    _join_terms(preferences.get("preferredCategories")),
                    _join_terms(preferences.get("preferredBrands")),
                    _join_terms(preferences.get("avoidIngredients")),
                    preferences.get("budgetMin"),
                    preferences.get("budgetMax"),
                    preferences.get("currency"),
                ),
            )
            cursor.execute(
                "UPDATE users SET skin_type = %s WHERE id = %s",
                (preferences.get("skinType"), user_id),
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
        return self.get_preferences(user_id)

    def get_user_by_email(self, email: str) -> UserRecord | None:
        return self._get_user("u.email = %s", (email.strip().lower(),))

    def get_user_by_id(self, user_id: int) -> UserRecord | None:
        return self._get_user("u.id = %s", (user_id,))

    def _get_user(self, where_clause: str, params: tuple[Any, ...]) -> UserRecord | None:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                f"""
                SELECT u.id, u.full_name, u.email, u.password_hash, u.role, u.skin_type
                FROM users u
                WHERE {where_clause}
                LIMIT 1
                """,
                params,
            )
            row = cursor.fetchone()
            return _row_to_user(row) if row else None
        finally:
            conn.close()

    def create_order(
        self,
        *,
        user_id: int,
        items: list[dict[str, int]],
        currency: str,
        shipping_name: str,
        shipping_phone: str,
        shipping_address: str,
        note: str | None,
        payment_method: str,
    ) -> dict[str, Any]:
        if not items:
            raise CommerceValidationError("Order must contain at least one item")
        requested_currency = currency.strip().upper()
        quantities: dict[int, int] = {}
        for item in items:
            product_id = int(item["productId"])
            quantity = int(item["quantity"])
            if quantity < 1 or quantity > 99:
                raise CommerceValidationError("Item quantity must be between 1 and 99")
            quantities[product_id] = quantities.get(product_id, 0) + quantity

        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            placeholders = ", ".join(["%s"] * len(quantities))
            cursor.execute(
                f"""
                SELECT id, name, price, currency, stock_quantity, status
                FROM products
                WHERE id IN ({placeholders})
                FOR UPDATE
                """,
                tuple(quantities),
            )
            products = {int(row["id"]): row for row in cursor.fetchall()}
            if set(products) != set(quantities):
                raise CommerceValidationError("One or more products do not exist")

            total = Decimal("0")
            for product_id, quantity in quantities.items():
                product = products[product_id]
                product_currency = str(product.get("currency") or "").upper()
                if product.get("status") != "ACTIVE":
                    raise CommerceValidationError(f"Product {product_id} is not active")
                if not product_currency or product_currency != requested_currency:
                    raise CommerceValidationError("All products must use the checkout currency")
                if int(product.get("stock_quantity") or 0) < quantity:
                    raise CommerceValidationError(
                        f"Insufficient stock for product {product_id}"
                    )
                total += Decimal(str(product["price"])) * quantity

            cursor.execute(
                """
                INSERT INTO orders (
                    user_id, status, total_amount, currency, shipping_name,
                    shipping_phone, shipping_address, note, payment_method
                )
                VALUES (%s, 'PENDING', %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    user_id,
                    total,
                    requested_currency,
                    shipping_name.strip(),
                    shipping_phone.strip(),
                    shipping_address.strip(),
                    note.strip() if note else None,
                    payment_method,
                ),
            )
            order_id = int(cursor.lastrowid)
            for product_id, quantity in quantities.items():
                product = products[product_id]
                cursor.execute(
                    """
                    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (order_id, product_id, quantity, product["price"]),
                )
                cursor.execute(
                    """
                    UPDATE products
                    SET stock_quantity = stock_quantity - %s
                    WHERE id = %s
                    """,
                    (quantity, product_id),
                )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
        order = self.get_order(order_id=order_id, user_id=user_id)
        if order is None:
            raise RuntimeError("Created order could not be loaded")
        return order

    def get_order(self, *, order_id: int, user_id: int | None = None) -> dict[str, Any] | None:
        orders = self._load_orders(
            "o.id = %s" + (" AND o.user_id = %s" if user_id is not None else ""),
            (order_id, user_id) if user_id is not None else (order_id,),
        )
        return orders[0] if orders else None

    def list_orders(self, *, user_id: int | None = None) -> list[dict[str, Any]]:
        if user_id is None:
            return self._load_orders("1 = 1", ())
        return self._load_orders("o.user_id = %s", (user_id,))

    def get_admin_metrics(self) -> dict[str, int]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM products) AS total_products,
                    (SELECT COUNT(*) FROM products WHERE ai_ready = TRUE) AS ai_ready_products,
                    (SELECT COUNT(*) FROM products
                     WHERE ai_ready = TRUE AND status = 'ACTIVE' AND stock_quantity > 0)
                        AS production_candidates,
                    (SELECT COUNT(*) FROM orders) AS orders,
                    (SELECT COUNT(*) FROM users) AS users,
                    (SELECT COUNT(*) FROM recommendation_logs) AS recommendation_requests
                """
            )
            row = cursor.fetchone() or {}
            return {
                "totalProducts": int(row.get("total_products") or 0),
                "aiReadyProducts": int(row.get("ai_ready_products") or 0),
                "productionCandidates": int(row.get("production_candidates") or 0),
                "orders": int(row.get("orders") or 0),
                "users": int(row.get("users") or 0),
                "recommendationRequests": int(row.get("recommendation_requests") or 0),
            }
        finally:
            conn.close()

    def _load_orders(self, where_clause: str, params: tuple[Any, ...]) -> list[dict[str, Any]]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                f"""
                SELECT
                    o.id, o.user_id, o.status, o.total_amount, o.currency,
                    o.shipping_name, o.shipping_phone, o.shipping_address,
                    o.note, o.payment_method, o.created_at
                FROM orders o
                WHERE {where_clause}
                ORDER BY o.created_at DESC, o.id DESC
                """,
                params,
            )
            orders = [dict(row) for row in cursor.fetchall()]
            for order in orders:
                cursor.execute(
                    """
                    SELECT
                        oi.product_id, p.name AS product_name, oi.quantity, oi.unit_price
                    FROM order_items oi
                    JOIN products p ON p.id = oi.product_id
                    WHERE oi.order_id = %s
                    ORDER BY oi.id
                    """,
                    (order["id"],),
                )
                order["items"] = [dict(row) for row in cursor.fetchall()]
            return [_serialize_order(order) for order in orders]
        finally:
            conn.close()


def _row_to_user(row: dict[str, Any]) -> UserRecord:
    return UserRecord(
        id=int(row["id"]),
        full_name=str(row["full_name"]),
        email=str(row["email"]),
        password_hash=str(row["password_hash"]),
        role=str(row["role"]),
        skin_type=str(row["skin_type"]) if row.get("skin_type") else None,
    )


def _serialize_order(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "orderId": int(row["id"]),
        "userId": int(row["user_id"]),
        "status": str(row["status"]),
        "totalAmount": float(row["total_amount"]),
        "currency": str(row["currency"]),
        "shippingName": str(row["shipping_name"]),
        "shippingPhone": str(row["shipping_phone"]),
        "shippingAddress": str(row["shipping_address"]),
        "note": row.get("note"),
        "paymentMethod": str(row["payment_method"]),
        "createdAt": row["created_at"].isoformat()
        if hasattr(row["created_at"], "isoformat")
        else str(row["created_at"]),
        "items": [
            {
                "productId": int(item["product_id"]),
                "productName": str(item["product_name"]),
                "quantity": int(item["quantity"]),
                "unitPrice": float(item["unit_price"]),
            }
            for item in row.get("items", [])
        ],
    }


def _join_terms(values: Any) -> str | None:
    terms = [str(value).strip() for value in (values or []) if str(value).strip()]
    return ",".join(terms) or None


def _split_terms(value: Any) -> list[str]:
    if not value:
        return []
    return [term.strip() for term in str(value).replace("|", ",").split(",") if term.strip()]


def _serialize_preferences(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "skinType": row.get("skin_type"),
        "skinConcerns": _split_terms(row.get("skin_concerns")),
        "careGoals": _split_terms(row.get("care_goals")),
        "preferredCategories": _split_terms(row.get("preferred_categories")),
        "preferredBrands": _split_terms(row.get("preferred_brands")),
        "avoidIngredients": _split_terms(row.get("avoid_ingredients")),
        "budgetMin": float(row["budget_min"]) if row.get("budget_min") is not None else None,
        "budgetMax": float(row["budget_max"]) if row.get("budget_max") is not None else None,
        "currency": str(row.get("budget_currency") or "USD"),
        "completed": bool(row),
    }
