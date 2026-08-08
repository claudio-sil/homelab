import hmac
import json
import os

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer


bearer_scheme = HTTPBearer(auto_error=False)


def _device_tokens() -> dict:
    raw = os.environ.get("NFC_DEVICE_TOKENS", "")

    if not raw:
        return {}

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {}

    return parsed if isinstance(parsed, dict) else {}


def authenticate_device(
    credentials: HTTPAuthorizationCredentials | None,
) -> dict:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail="Missing device token",
        )

    supplied_token = credentials.credentials
    tokens = _device_tokens()

    for configured_token, device in tokens.items():
        if hmac.compare_digest(supplied_token, configured_token):
            if not isinstance(device, dict):
                break

            username = device.get("user")
            if not username:
                break

            return {
                "user": username,
                "device": device.get("device", "unknown"),
            }

    raise HTTPException(
        status_code=401,
        detail="Invalid device token",
    )
