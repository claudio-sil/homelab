

# --------------------------------------------------------------------------
# Title/author lookup via the National Library of Israel
# --------------------------------------------------------------------------
@router.get("/nliTitle", dependencies=[get_rate_limiter(times=2, seconds=2)], response_class=HTMLResponse)
def new_by_title_nli(request: Request, user: admin_user, title: str, author: str = "", code: str = ""):
    try:
        book = service.lookup_book_metadata_by_title_nli(title, author)
        book_schema = service.book_create_from_nli_metadata(book, code.strip())
        db = SessionLocal()
        config = crud.getConfig(db)
        db.close()
        context = {
            "config": config,
            "user": user,
            "addISBN": [0],
            "book": book_schema,
            "request": request,
        }
        return templates.TemplateResponse(request, "newBook.html", context)
    except LookupError:
        searched_for = title if not author else f"{title} — {author}"
        errors = [f"'{searched_for}' was not found on NLI. Try a shorter title or omit the author."]
        context = {
            "errors": errors,
            "code": code,
            "user": user,
            "request": request,
        }
        return templates.TemplateResponse(request, "addisbn.html", context)
    except Exception:
        errors = ["The NLI lookup failed unexpectedly. Check the uBiblio service log and try again."]
        context = {
            "errors": errors,
            "code": code,
            "user": user,
            "request": request,
        }
        return templates.TemplateResponse(request, "addisbn.html", context)


# Keep old bookmarked/scanner-generated URLs working.
@router.get("/nliTitle/{code}", dependencies=[get_rate_limiter(times=2, seconds=2)], response_class=HTMLResponse)
def new_by_title_nli_legacy(code: str, title: str, request: Request, user: admin_user, author: str = ""):
    return new_by_title_nli(request=request, user=user, title=title, author=author, code=code)
