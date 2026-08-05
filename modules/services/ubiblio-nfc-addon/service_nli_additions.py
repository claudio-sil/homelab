

# --------------------------------------------------------------------------
# External metadata (title/author lookup via NLI)
# --------------------------------------------------------------------------
def lookup_book_metadata_by_title_nli(title: str, author: str = "") -> dict[str, Any]:
    """Resolve a title and optional author through the National Library of Israel."""
    from .book_metadata_client import BookMetadataClient

    clean_title = title.strip()
    clean_author = author.strip()
    if not clean_title:
        raise LookupError("A title is required for NLI lookup")

    client = BookMetadataClient()
    book, response = client.nli_by_title(clean_title, clean_author)
    if len(book) == 0:
        raise LookupError(f"Book with title {clean_title} not found on NLI")
    return book


def book_create_from_nli_metadata(book: dict[str, Any], code: str = "") -> schemas.BookCreate:
    return schemas.BookCreate(
        title=book["Title"],
        author=book.get("Author", ""),
        summary=book.get("Summary", ""),
        customField1=code,
    )
