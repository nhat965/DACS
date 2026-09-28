import time
import unittest

from recommendation_service.auth import (
    AuthSettings,
    InvalidTokenError,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)


class AuthTest(unittest.TestCase):
    def test_password_hash_is_salted_and_verifiable(self):
        first = hash_password("Secret123")
        second = hash_password("Secret123")

        self.assertNotEqual(first, second)
        self.assertTrue(verify_password("Secret123", first))
        self.assertFalse(verify_password("wrong-password", first))

    def test_jwt_round_trip_and_signature_validation(self):
        settings = AuthSettings(jwt_secret="test-secret", token_ttl_seconds=60)
        token = create_access_token(
            user_id=7,
            email="customer@example.com",
            role="CUSTOMER",
            settings=settings,
        )

        payload = decode_access_token(token, settings=settings)
        self.assertEqual(payload["sub"], "7")
        self.assertEqual(payload["role"], "CUSTOMER")

        with self.assertRaises(InvalidTokenError):
            decode_access_token(token + "broken", settings=settings)

    def test_expired_jwt_is_rejected(self):
        settings = AuthSettings(jwt_secret="test-secret", token_ttl_seconds=-1)
        token = create_access_token(
            user_id=1,
            email="a@example.com",
            role="CUSTOMER",
            settings=settings,
        )
        time.sleep(0.01)

        with self.assertRaises(InvalidTokenError):
            decode_access_token(token, settings=settings)


if __name__ == "__main__":
    unittest.main()
