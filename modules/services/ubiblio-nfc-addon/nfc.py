from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from .. import crud, schemas
from ..database import SessionLocal
from ..dependencies import (
    get_rate_limiter, templates,
    current_user,
)

router = APIRouter()


def _book_location(book) -> list[tuple[str, str]]:
    """Return the non-empty physical-location fields in display order."""
    fields = (
        ("Library", book.library),
        ("Collection", book.collection),
        ("Shelf", book.shelf),
    )
    return [
        (label, str(value).strip())
        for label, value in fields
        if value is not None and str(value).strip()
    ]


# Single toggling endpoint meant to be launched by tapping an NFC sticker
# stuck to the physical book (an NDEF URI record pointing here — see the
# homelab docs for how each tag gets written). Whichever phone taps it
# just needs an existing logged-in uBiblio session in its browser; the
# tap itself performs the withdraw or return, whichever applies given the
# book's current state, using uBiblio's own existing crud logic.
@router.get("/nfc/{bookId}", dependencies=[get_rate_limiter(times=1, seconds=1)], response_class=HTMLResponse)
async def nfc_toggle(bookId, request: Request, user: current_user):
    db = SessionLocal()
    location = []
    try:
        book = crud.getBookById(db, bookId)
        if not book:
            context = {
                "user": user,
                "request": request,
                "message": "No such book.",
                "location": [],
            }
            return templates.TemplateResponse(
                request, "nfc_result.html", context, status_code=404
            )

        now_withdrawn = not book.withdrawn
        updated = schemas.Book(
            id=bookId, title=book.title, author=book.author, summary=book.summary,
            genre=book.genre, library=book.library, shelf=book.shelf, collection=book.collection,
            notes=book.notes, ISBN=book.ISBN, owned=book.owned, ebook=book.ebook,
            withdrawnBy=(user.username if now_withdrawn else None),
            customField1=book.customField1, customField2=book.customField2,
            withdrawn=now_withdrawn,
        )

        if now_withdrawn:
            crud.bookWithdraw(db, updated)
            message = f"'{book.title}' withdrawn by {user.username}."
        else:
            crud.bookReturn(db, updated)
            message = f"'{book.title}' returned."
            location = _book_location(book)
    finally:
        db.close()

    context = {
        "user": user,
        "request": request,
        "message": message,
        "location": location,
    }
    return templates.TemplateResponse(request, "nfc_result.html", context)
