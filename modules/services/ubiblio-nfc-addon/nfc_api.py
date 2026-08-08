from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from ..database import SessionLocal

from .circulation import BookNotFoundError, toggle_book
from .device_auth import authenticate_device, bearer_scheme


router = APIRouter(prefix="/api/nfc", tags=["nfc-api"])


def current_device(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict:
    return authenticate_device(credentials)


@router.get("/ping")
def nfc_ping(device: dict = Depends(current_device)):
    return {
        "status": "ok",
        "user": device["user"],
        "device": device["device"],
    }


@router.post("/{book_id}")
def nfc_toggle_api(
    book_id: int,
    device: dict = Depends(current_device),
):
    db = SessionLocal()

    try:
        result = toggle_book(
            db=db,
            book_id=book_id,
            username=device["user"],
        )
    except BookNotFoundError:
        raise HTTPException(
            status_code=404,
            detail="No such book",
        )
    finally:
        db.close()

    return {
        **result,
        "device": device["device"],
    }
