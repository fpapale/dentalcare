import time

import jwt
import pytest
from fastapi import HTTPException

from app.config import get_settings
from app.security import decode_token

SECRET = get_settings().jwt_secret


def _token(claims: dict, secret: str = SECRET) -> str:
    return jwt.encode(claims, secret, algorithm="HS256")


def test_decode_valid_token_returns_claims():
    token = _token({"sub": "u1", "schemaName": "t_9d754153", "exp": int(time.time()) + 60})
    claims = decode_token(token)
    assert claims["sub"] == "u1"
    assert claims["schemaName"] == "t_9d754153"


def test_decode_expired_token_raises_401():
    token = _token({"sub": "u1", "exp": int(time.time()) - 10})
    with pytest.raises(HTTPException) as exc:
        decode_token(token)
    assert exc.value.status_code == 401


def test_decode_wrong_secret_raises_401():
    token = _token({"sub": "u1", "exp": int(time.time()) + 60}, secret="wrong-secret-value")
    with pytest.raises(HTTPException) as exc:
        decode_token(token)
    assert exc.value.status_code == 401
