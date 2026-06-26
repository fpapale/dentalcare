import time

import jwt
import pytest
from fastapi import HTTPException

from app.config import get_settings
from app.security import decode_token, require_jwt

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


def test_alg_none_rejected():
    import base64
    import json

    header = (
        base64.urlsafe_b64encode(json.dumps({"alg": "none", "typ": "JWT"}).encode())
        .rstrip(b"=")
        .decode()
    )
    payload = (
        base64.urlsafe_b64encode(
            json.dumps({"sub": "u1", "exp": int(time.time()) + 60}).encode()
        )
        .rstrip(b"=")
        .decode()
    )
    token = f"{header}.{payload}."
    with pytest.raises(HTTPException) as exc:
        decode_token(token)
    assert exc.value.status_code == 401


def test_require_jwt_missing_header_raises_401():
    with pytest.raises(HTTPException) as exc:
        require_jwt(None)
    assert exc.value.status_code == 401


def test_require_jwt_no_bearer_prefix_raises_401():
    with pytest.raises(HTTPException) as exc:
        require_jwt("Token abc123")
    assert exc.value.status_code == 401


def test_require_jwt_valid_bearer_returns_claims():
    token = _token({"sub": "u1", "exp": int(time.time()) + 60})
    claims = require_jwt(f"Bearer {token}")
    assert claims["sub"] == "u1"


@pytest.mark.parametrize("algo", ["HS256", "HS384", "HS512"])
def test_decode_valid_token_all_hmac_algorithms(algo):
    token = jwt.encode({"sub": "u1", "exp": int(time.time()) + 60}, SECRET, algorithm=algo)
    claims = decode_token(token)
    assert claims["sub"] == "u1"
