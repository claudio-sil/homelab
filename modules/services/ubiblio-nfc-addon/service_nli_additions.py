

# --------------------------------------------------------------------------
# External metadata (title lookup via NLI -- Danacode / non-ISBN fallback)
# --------------------------------------------------------------------------
def lookup_book_metadata_by_title_nli(title: str) -> dict[str, Any]:
    """
    Resolve a title (typically for a book identified by Israeli Danacode
    rather than a valid ISBN) to Title/Author/Summary via the National
    Library of Israel. Raises LookupError if not found.
    """
    from .book_metadata_client import BookMetadataClient

    client = BookMetadataClient()
    book, response = client.nli_by_title(title.strip())
    if len(book) == 0:
        raise LookupError(f"Book with title {title} not found on NLI!")
    return book


def book_create_from_nli_metadata(book: dict[str, Any], code: str) -> schemas.BookCreate:
    return schemas.BookCreate(
        title=book["Title"],
        author=book["Author"],
        summary=book["Summary"],
        customField1=code,
    )
