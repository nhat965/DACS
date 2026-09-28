from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import time
from dataclasses import dataclass
from typing import Any


PASSWORD_ITERATIONS = 310_000


class InvalidTokenError(ValueError):
    pass


@dataclass(frozen=True)
class AuthSettings:
    jwt_secret: str
    token_ttl_seconds: int = 8 * 60 * 60

    @classmethod
    def from_env(cls) -> "AuthSettings":
        return cls(
            jwt_secret=os.getenv("JWT_SECRET", "lumi-local-development-secret"),
            token_ttl_seconds=int(os.getenv("JWT_TTL_SECONDS", str(8 * 60 * 60))),
        )


def hash_password(password: str, *, salt: bytes | None = None) -> str:
    if len(password) < 8:
        raise ValueError("Password must contain at least 8 characters")
    actual_salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), actual_salt, PASSWORD_ITERATIONS
    )
    return "$".join(
        (
            "pbkdf2_sha256",
            str(PASSWORD_ITERATIONS),
            _b64encode(actual_salt),
            _b64encode(digest),
        )
    )


def verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, iterations, salt, expected = encoded.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            _b64decode(salt),
            int(iterations),
        )
        return hmac.compare_digest(digest, _b64decode(expected))
    except (TypeError, ValueError):
        return False


def create_access_token(
    *, user_id: int, email: str, role: str, settings: AuthSettings
) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(user_id),
        "email": email,
        "role": role,
        "iat": now,
        "exp": now + settings.token_ttl_seconds,
    }
    signing_input = (
        f"{_json_segment(header)}.{_json_segment(payload)}".encode("ascii")
    )
    signature = hmac.new(
        settings.jwt_secret.encode("utf-8"), signing_input, hashlib.sha256
    ).digest()
    return f"{signing_input.decode('ascii')}.{_b64encode(signature)}"


def decode_access_token(token: str, *, settings: AuthSettings) -> dict[str, Any]:
    try:
        header_segment, payload_segment, signature_segment = token.split(".", 2)
        signing_input = f"{header_segment}.{payload_segment}".encode("ascii")
        expected = hmac.new(
            settings.jwt_secret.encode("utf-8"), signing_input, hashlib.sha256
        ).digest()
        if not hmac.compare_digest(expected, _b64decode(signature_segment)):
            raise InvalidTokenError("Invalid token signature")
        header = json.loads(_b64decode(header_segment))
        payload = json.loads(_b64decode(payload_segment))
        if header.get("alg") != "HS256":
            raise InvalidTokenError("Unsupported token algorithm")
        if int(payload.get("exp", 0)) <= int(time.time()):
            raise InvalidTokenError("Token has expired")
        if not payload.get("sub") or payload.get("role") not in {"CUSTOMER", "ADMIN"}:
            raise InvalidTokenError("Token payload is invalid")
        return payload
    except InvalidTokenError:
        raise
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        raise InvalidTokenError("Malformed token") from exc


def _json_segment(value: dict[str, Any]) -> str:
    return _b64encode(
        json.dumps(value, separators=(",", ":"), sort_keys=True).encode("utf-8")
    )


def _b64encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _b64decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)
