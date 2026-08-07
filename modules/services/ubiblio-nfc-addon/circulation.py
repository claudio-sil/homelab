from .. import crud, schemas


class BookNotFoundError(Exception):
    pass


def book_location(book) -> list[tuple[str, str]]:
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


def toggle_book(db, book_id: int, username: str) -> dict:
    book = crud.getBookById(db, book_id)

    if not book:
        raise BookNotFoundError(f"Book {book_id} does not exist")

    now_withdrawn = not book.withdrawn

    updated = schemas.Book(
        id=book_id,
        title=book.title,
        author=book.author,
        summary=book.summary,
        genre=book.genre,
        library=book.library,
        shelf=book.shelf,
        collection=book.collection,
        notes=book.notes,
        ISBN=book.ISBN,
        owned=book.owned,
        ebook=book.ebook,
        withdrawnBy=username if now_withdrawn else None,
        customField1=book.customField1,
        customField2=book.customField2,
        withdrawn=now_withdrawn,
    )

    if now_withdrawn:
        crud.bookWithdraw(db, updated)

        return {
            "book_id": book_id,
            "title": book.title,
            "action": "withdrawn",
            "username": username,
            "message": f"'{book.title}' withdrawn by {username}.",
            "location": [],
        }

    crud.bookReturn(db, updated)

    return {
        "book_id": book_id,
        "title": book.title,
        "action": "returned",
        "username": username,
        "message": f"'{book.title}' returned.",
        "location": book_location(book),
    }
