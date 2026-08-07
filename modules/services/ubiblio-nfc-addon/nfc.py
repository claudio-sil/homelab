from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from ..database import SessionLocal
from ..dependencies import (
    get_rate_limiter,
    templates,
    current_user,
)
from .circulation import BookNotFoundError, toggle_book


router = APIRouter()


@router.get(
    "/nfc/{bookId}",
    dependencies=[get_rate_limiter(times=1, seconds=1)],
    response_class=HTMLResponse,
)
async def nfc_toggle(bookId: int, request: Request, user: current_user):
    db = SessionLocal()

    try:
        result = toggle_book(
            db=db,
            book_id=bookId,
            username=user.username,
        )
    except BookNotFoundError:
        context = {
            "user": user,
            "request": request,
            "message": "No such book.",
            "location": [],
        }

        return templates.TemplateResponse(
            request,
            "nfc_result.html",
            context,
            status_code=404,
        )
    finally:
        db.close()

    context = {
        "user": user,
        "request": request,
        "message": result["message"],
        "location": result["location"],
    }

    return templates.TemplateResponse(
        request,
        "nfc_result.html",
        context,
    )
