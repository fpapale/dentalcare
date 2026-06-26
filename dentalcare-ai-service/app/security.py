import jwt
from fastapi import Header, HTTPException

from app.config import get_settings

_ALGORITHMS = ["HS256", "HS384", "HS512"]


def decode_token(token: str) -> dict:
    settings = get_settings()
    options = {"verify_aud": bool(settings.jwt_audience)}
    kwargs = {}
    if settings.jwt_audience:
        kwargs["audience"] = settings.jwt_audience
    if settings.jwt_issuer:
        kwargs["issuer"] = settings.jwt_issuer
    try:
        return jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=_ALGORITHMS,
            options=options,
            **kwargs,
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc


def require_jwt(authorization: str = Header(default=None)) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    return decode_token(token)
