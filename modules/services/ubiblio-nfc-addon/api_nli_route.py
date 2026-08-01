

# --------------------------------------------------------------------------
# Danacode / non-ISBN title fallback (via National Library of Israel)
# --------------------------------------------------------------------------
@router.get("/nliTitle/{code}", dependencies=[get_rate_limiter(times=2, seconds=2)], response_class=HTMLResponse)
def new_by_title_nli(code, title: str, request: Request, user: admin_user):
    try:
        book = service.lookup_book_metadata_by_title_nli(title)
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
    except Exception:
        errors = ["Title '" + str(title) + "' not found on NLI -- try a different title."]
        context = {
            "errors": errors,
            "code": code,
            "user": user,
            "request": request,
        }
        return templates.TemplateResponse(request, "addisbn.html", context)
