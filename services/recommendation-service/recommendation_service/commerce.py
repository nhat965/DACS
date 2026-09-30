from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from .database import RecommendationDatabase


class DuplicateEmailError(ValueError):
    pass


class CommerceValidationError(ValueError):
    pass


ORDER_TRANSITIONS = {
    "PENDING": {"CONFIRMED", "CANCELED"},
    "CONFIRMED": {"PROCESSING", "CANCELED"},
    "PROCESSING": {"SHIPPING", "CANCELED"},
    "SHIPPING": {"COMPLETED"},
    "COMPLETED": set(),
    "CANCELED": set(),
}


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

    def list_product_reviews(
        self,
        *,
        product_id: int,
        viewer_user_id: int | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT id FROM products WHERE id = %s", (product_id,))
            if cursor.fetchone() is None:
                raise CommerceValidationError("Product not found")
            cursor.execute(
                """
                SELECT COUNT(*) AS total, AVG(rating) AS average_rating
                FROM product_reviews
                WHERE product_id = %s
                """,
                (product_id,),
            )
            summary = cursor.fetchone() or {}
            cursor.execute(
                """
                SELECT pr.id, pr.product_id, pr.user_id, u.full_name,
                       pr.rating, pr.comment, pr.created_at, pr.updated_at
                FROM product_reviews pr
                JOIN users u ON u.id = pr.user_id
                WHERE pr.product_id = %s
                ORDER BY pr.updated_at DESC, pr.id DESC
                LIMIT %s OFFSET %s
                """,
                (product_id, limit, offset),
            )
            items = [
                _serialize_review(row, viewer_user_id=viewer_user_id)
                for row in cursor.fetchall()
            ]
            return {
                "items": items,
                "total": int(summary.get("total") or 0),
                "averageRating": float(summary["average_rating"])
                if summary.get("average_rating") is not None
                else None,
                "limit": limit,
                "offset": offset,
            }
        finally:
            conn.close()

    def save_product_review(
        self, *, user_id: int, product_id: int, rating: int, comment: str
    ) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT id FROM products WHERE id = %s", (product_id,))
            if cursor.fetchone() is None:
                raise CommerceValidationError("Product not found")
            cursor.execute(
                """
                INSERT INTO product_reviews (product_id, user_id, rating, comment)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    rating = VALUES(rating),
                    comment = VALUES(comment),
                    updated_at = CURRENT_TIMESTAMP
                """,
                (product_id, user_id, rating, comment.strip()),
            )
            conn.commit()
            cursor.execute(
                """
                SELECT pr.id, pr.product_id, pr.user_id, u.full_name,
                       pr.rating, pr.comment, pr.created_at, pr.updated_at
                FROM product_reviews pr
                JOIN users u ON u.id = pr.user_id
                WHERE pr.product_id = %s AND pr.user_id = %s
                LIMIT 1
                """,
                (product_id, user_id),
            )
            row = cursor.fetchone()
            if row is None:
                raise RuntimeError("Saved review could not be loaded")
            return _serialize_review(row, viewer_user_id=user_id)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

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

    def get_admin_dashboard(self) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM products) AS total_products,
                    (SELECT COUNT(*) FROM products WHERE ai_ready = TRUE) AS ai_ready_products,
                    (SELECT COUNT(*) FROM products WHERE stock_quantity BETWEEN 1 AND 10) AS low_stock,
                    (SELECT COUNT(*) FROM users WHERE role = 'CUSTOMER') AS users,
                    (SELECT COUNT(*) FROM orders) AS orders,
                    (SELECT COUNT(*) FROM orders WHERE status = 'PENDING') AS pending_orders,
                    (SELECT COUNT(*) FROM orders WHERE DATE(created_at) = CURRENT_DATE) AS orders_today,
                    (SELECT COALESCE(SUM(total_amount), 0) FROM orders
                     WHERE status = 'COMPLETED') AS completed_revenue,
                    (SELECT COUNT(*) FROM recommendation_logs) AS recommendation_requests
                """
            )
            row = cursor.fetchone() or {}
            cursor.execute(
                """
                SELECT status, COUNT(*) AS count
                FROM orders
                GROUP BY status
                """
            )
            statuses = {
                str(item["status"]): int(item["count"])
                for item in cursor.fetchall()
            }
            cursor.execute(
                """
                SELECT currency, COALESCE(SUM(total_amount), 0) AS revenue
                FROM orders
                WHERE status = 'COMPLETED'
                GROUP BY currency
                """
            )
            revenue_by_currency = {
                str(item["currency"]): float(item["revenue"])
                for item in cursor.fetchall()
            }
            return {
                "totalProducts": int(row.get("total_products") or 0),
                "aiReadyProducts": int(row.get("ai_ready_products") or 0),
                "lowStockProducts": int(row.get("low_stock") or 0),
                "users": int(row.get("users") or 0),
                "orders": int(row.get("orders") or 0),
                "pendingOrders": int(row.get("pending_orders") or 0),
                "ordersToday": int(row.get("orders_today") or 0),
                "recommendationRequests": int(row.get("recommendation_requests") or 0),
                "orderStatuses": statuses,
                "revenueByCurrency": revenue_by_currency,
            }
        finally:
            conn.close()

    def get_admin_data_quality(self) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT
                    COUNT(*) AS total,
                    SUM(CASE WHEN COALESCE(TRIM(inci_ingredients), '') <> '' THEN 1 ELSE 0 END) AS inci,
                    SUM(CASE WHEN COALESCE(TRIM(skin_types), '') <> '' THEN 1 ELSE 0 END) AS skin_types,
                    SUM(CASE WHEN COALESCE(TRIM(skin_concerns), '') <> '' THEN 1 ELSE 0 END) AS concerns,
                    SUM(CASE WHEN COALESCE(TRIM(care_goals), '') <> '' THEN 1 ELSE 0 END) AS goals,
                    SUM(CASE WHEN COALESCE(TRIM(image_url), '') <> '' THEN 1 ELSE 0 END) AS images,
                    SUM(CASE WHEN price > 0 AND COALESCE(TRIM(currency), '') <> '' THEN 1 ELSE 0 END) AS prices,
                    SUM(CASE WHEN ai_ready = TRUE THEN 1 ELSE 0 END) AS ai_ready
                FROM products
                """
            )
            row = cursor.fetchone() or {}
            return {
                "totalProducts": int(row.get("total") or 0),
                "inciComplete": int(row.get("inci") or 0),
                "skinTypeComplete": int(row.get("skin_types") or 0),
                "concernComplete": int(row.get("concerns") or 0),
                "careGoalComplete": int(row.get("goals") or 0),
                "imageComplete": int(row.get("images") or 0),
                "priceComplete": int(row.get("prices") or 0),
                "aiReadyProducts": int(row.get("ai_ready") or 0),
            }
        finally:
            conn.close()

    def list_admin_products(
        self,
        *,
        search: str | None = None,
        status: str | None = None,
        limit: int = 25,
        offset: int = 0,
    ) -> dict[str, Any]:
        conditions = ["1 = 1"]
        params: list[Any] = []
        if search:
            conditions.append("(p.name LIKE %s OR p.sku LIKE %s OR b.name LIKE %s)")
            term = f"%{search.strip()}%"
            params.extend([term, term, term])
        if status:
            conditions.append("p.status = %s")
            params.append(status)
        where_clause = " AND ".join(conditions)
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                f"""
                SELECT COUNT(*) AS total
                FROM products p
                JOIN brands b ON b.id = p.brand_id
                WHERE {where_clause}
                """,
                tuple(params),
            )
            total = int((cursor.fetchone() or {}).get("total") or 0)
            cursor.execute(
                f"""
                SELECT p.*, b.name AS brand, c.name AS category
                FROM products p
                JOIN brands b ON b.id = p.brand_id
                JOIN categories c ON c.id = p.category_id
                WHERE {where_clause}
                ORDER BY p.updated_at DESC, p.id DESC
                LIMIT %s OFFSET %s
                """,
                (*params, limit, offset),
            )
            return {
                "items": [_serialize_admin_product(dict(row)) for row in cursor.fetchall()],
                "total": total,
                "limit": limit,
                "offset": offset,
            }
        finally:
            conn.close()

    def get_admin_product(self, product_id: int) -> dict[str, Any] | None:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT p.*, b.name AS brand, c.name AS category
                FROM products p
                JOIN brands b ON b.id = p.brand_id
                JOIN categories c ON c.id = p.category_id
                WHERE p.id = %s
                LIMIT 1
                """,
                (product_id,),
            )
            row = cursor.fetchone()
            return _serialize_admin_product(dict(row)) if row else None
        finally:
            conn.close()

    def save_admin_product(
        self, *, payload: dict[str, Any], product_id: int | None = None
    ) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            brand_id = _lookup_id(cursor, "brands", payload["brand"])
            category_id = _lookup_id(cursor, "categories", payload["category"])
            values = (
                payload["sku"].strip(), payload["name"].strip(), brand_id,
                category_id, payload["price"], payload["currency"],
                payload["stockQuantity"], payload.get("description"),
                payload.get("benefits"), payload.get("inciIngredients"),
                payload.get("keyIngredients"), _join_terms(payload.get("skinTypes")),
                _join_terms(payload.get("skinConcerns")),
                _join_terms(payload.get("careGoals")), payload.get("texture"),
                payload.get("usageInstruction"), payload.get("warnings"),
                payload.get("imageUrl"), payload.get("sourceUrl"),
                payload["status"], bool(payload.get("aiReady")),
            )
            if product_id is None:
                cursor.execute(
                    """
                    INSERT INTO products (
                        sku, name, brand_id, category_id, price, currency,
                        stock_quantity, description, benefits, inci_ingredients,
                        key_ingredients, skin_types, skin_concerns, care_goals,
                        texture, usage_instruction, warnings, image_url, source_url,
                        status, ai_ready
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                    """,
                    values,
                )
                product_id = int(cursor.lastrowid)
            else:
                cursor.execute("SELECT id FROM products WHERE id = %s", (product_id,))
                if cursor.fetchone() is None:
                    raise CommerceValidationError("Product not found")
                cursor.execute(
                    """
                    UPDATE products SET
                        sku=%s, name=%s, brand_id=%s, category_id=%s,
                        price=%s, currency=%s, stock_quantity=%s,
                        description=%s, benefits=%s, inci_ingredients=%s,
                        key_ingredients=%s, skin_types=%s, skin_concerns=%s,
                        care_goals=%s, texture=%s, usage_instruction=%s,
                        warnings=%s, image_url=%s, source_url=%s,
                        status=%s, ai_ready=%s
                    WHERE id=%s
                    """,
                    (*values, product_id),
                )
            conn.commit()
        except Exception as exc:
            conn.rollback()
            if getattr(exc, "errno", None) == 1062:
                raise CommerceValidationError("SKU already exists") from exc
            raise
        finally:
            conn.close()
        product = self.get_admin_product(product_id)
        if product is None:
            raise RuntimeError("Saved product could not be loaded")
        return product

    def update_product_status(self, product_id: int, status: str) -> dict[str, Any]:
        return self._update_product_field(product_id, "status", status)

    def update_product_stock(self, product_id: int, stock: int) -> dict[str, Any]:
        return self._update_product_field(product_id, "stock_quantity", stock)

    def _update_product_field(
        self, product_id: int, column: str, value: Any
    ) -> dict[str, Any]:
        if column not in {"status", "stock_quantity"}:
            raise ValueError("Unsupported product field")
        conn = self.database.connect()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM products WHERE id = %s", (product_id,))
            if cursor.fetchone() is None:
                raise CommerceValidationError("Product not found")
            cursor.execute(f"UPDATE products SET {column} = %s WHERE id = %s", (value, product_id))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
        product = self.get_admin_product(product_id)
        if product is None:
            raise RuntimeError("Updated product could not be loaded")
        return product

    def update_order_status(self, order_id: int, status: str) -> dict[str, Any]:
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT status FROM orders WHERE id = %s FOR UPDATE", (order_id,))
            row = cursor.fetchone()
            if row is None:
                raise CommerceValidationError("Order not found")
            current = str(row["status"])
            if status not in ORDER_TRANSITIONS.get(current, set()):
                raise CommerceValidationError(
                    f"Invalid order status transition: {current} -> {status}"
                )
            cursor.execute("UPDATE orders SET status = %s WHERE id = %s", (status, order_id))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
        order = self.get_order(order_id=order_id)
        if order is None:
            raise RuntimeError("Updated order could not be loaded")
        return order

    def list_admin_users(self, *, search: str | None = None) -> list[dict[str, Any]]:
        params: list[Any] = []
        where = "1 = 1"
        if search:
            term = f"%{search.strip()}%"
            where = "(u.full_name LIKE %s OR u.email LIKE %s)"
            params.extend([term, term])
        conn = self.database.connect()
        try:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                f"""
                SELECT u.id, u.full_name, u.email, u.role, u.skin_type,
                       u.created_at, u.updated_at, COUNT(o.id) AS order_count
                FROM users u
                LEFT JOIN orders o ON o.user_id = u.id
                WHERE {where}
                GROUP BY u.id, u.full_name, u.email, u.role, u.skin_type,
                         u.created_at, u.updated_at
                ORDER BY u.created_at DESC, u.id DESC
                """,
                tuple(params),
            )
            return [_serialize_admin_user(dict(row)) for row in cursor.fetchall()]
        finally:
            conn.close()

    def get_admin_user(self, user_id: int) -> dict[str, Any] | None:
        users = [item for item in self.list_admin_users() if item["userId"] == user_id]
        if not users:
            return None
        result = dict(users[0])
        result["preferences"] = self.get_preferences(user_id)
        result["orders"] = self.list_orders(user_id=user_id)
        return result

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


def _serialize_review(
    row: dict[str, Any], *, viewer_user_id: int | None = None
) -> dict[str, Any]:
    def timestamp(value: Any) -> str:
        return value.isoformat() if hasattr(value, "isoformat") else str(value)

    return {
        "reviewId": int(row["id"]),
        "productId": int(row["product_id"]),
        "userId": int(row["user_id"]),
        "authorName": str(row.get("full_name") or "Khách hàng Lumi"),
        "rating": int(row["rating"]),
        "comment": str(row.get("comment") or ""),
        "createdAt": timestamp(row["created_at"]),
        "updatedAt": timestamp(row["updated_at"]),
        "isMine": viewer_user_id is not None
        and int(row["user_id"]) == viewer_user_id,
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


def _lookup_id(cursor, table: str, name: str) -> int:
    if table not in {"brands", "categories"}:
        raise ValueError("Unsupported lookup table")
    cursor.execute(f"SELECT id FROM {table} WHERE name = %s LIMIT 1", (name.strip(),))
    row = cursor.fetchone()
    if row is None:
        raise CommerceValidationError(f"Unknown {table[:-1]}: {name}")
    return int(row["id"])


def _serialize_admin_product(row: dict[str, Any]) -> dict[str, Any]:
    def timestamp(value: Any) -> str | None:
        return value.isoformat() if hasattr(value, "isoformat") else str(value) if value else None

    return {
        "productId": int(row["id"]),
        "sku": str(row.get("sku") or ""),
        "name": str(row.get("name") or ""),
        "brand": str(row.get("brand") or ""),
        "category": str(row.get("category") or ""),
        "price": float(row.get("price") or 0),
        "currency": str(row.get("currency") or "USD"),
        "stockQuantity": int(row.get("stock_quantity") or 0),
        "description": str(row.get("description") or ""),
        "benefits": str(row.get("benefits") or ""),
        "inciIngredients": str(row.get("inci_ingredients") or ""),
        "keyIngredients": str(row.get("key_ingredients") or ""),
        "skinTypes": _split_terms(row.get("skin_types")),
        "skinConcerns": _split_terms(row.get("skin_concerns")),
        "careGoals": _split_terms(row.get("care_goals")),
        "texture": str(row.get("texture") or ""),
        "usageInstruction": str(row.get("usage_instruction") or ""),
        "warnings": str(row.get("warnings") or ""),
        "imageUrl": str(row.get("image_url") or ""),
        "sourceUrl": str(row.get("source_url") or ""),
        "status": str(row.get("status") or "DRAFT"),
        "aiReady": bool(row.get("ai_ready")),
        "createdAt": timestamp(row.get("created_at")),
        "updatedAt": timestamp(row.get("updated_at")),
    }


def _serialize_admin_user(row: dict[str, Any]) -> dict[str, Any]:
    def timestamp(value: Any) -> str | None:
        return value.isoformat() if hasattr(value, "isoformat") else str(value) if value else None

    return {
        "userId": int(row["id"]),
        "fullName": str(row.get("full_name") or ""),
        "email": str(row.get("email") or ""),
        "role": str(row.get("role") or "CUSTOMER"),
        "skinType": row.get("skin_type"),
        "orderCount": int(row.get("order_count") or 0),
        "createdAt": timestamp(row.get("created_at")),
        "updatedAt": timestamp(row.get("updated_at")),
    }
