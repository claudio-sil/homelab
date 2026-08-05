
    def nli_by_title(self, title: str, author: str = "") -> tuple[dict[str, str], int | None]:
        """Look up a book by title and optional author at the NLI.

        NLI search results are ranked locally so an author can disambiguate
        similarly titled books without depending on undocumented compound
        query syntax. The selected record's MARC 520 field is used as the
        summary when available.
        """
        import difflib
        import re
        import unicodedata
        import xml.etree.ElementTree as ET

        from ...vars import NLI_API_KEY

        if not NLI_API_KEY:
            return {}, None

        dc_ns = "http://purl.org/dc/elements/1.1/"
        marc_ns = "{http://www.loc.gov/MARC21/slim}"

        def first_value(record: dict, key: str) -> str:
            values = record.get(dc_ns + key, [])
            if not values:
                return ""
            value = values[0]
            if isinstance(value, dict):
                return str(value.get("@value", ""))
            return str(value)

        def normalize(value: str) -> str:
            # Remove Hebrew niqqud and other combining marks, punctuation,
            # and repeated whitespace before comparing search candidates.
            value = "".join(
                char for char in unicodedata.normalize("NFKD", value)
                if not unicodedata.combining(char)
            ).casefold()
            value = re.sub(r"[^\w\s]", " ", value, flags=re.UNICODE)
            return " ".join(value.split())

        def clean_record_title(raw_title: str) -> str:
            return raw_title.split(" / ")[0].strip().rstrip(",.")

        def clean_record_author(raw_creator: str) -> str:
            creator_head = raw_creator.split("$$Q")[0]
            return re.sub(
                r",?\s*\d{4}-\s*(?:author|מחבר)?\s*$",
                "",
                creator_head,
                flags=re.IGNORECASE,
            ).strip().rstrip(",")

        response = requests.get(
            "https://api.nli.org.il/openlibrary/search",
            params={
                "api_key": NLI_API_KEY,
                "query": f"title,contains,{title.strip()}",
                "output_format": "json",
            },
            headers={"User-Agent": self.USER_AGENT},
            timeout=(5, 20),
        )
        if not response.ok:
            return {}, response.status_code

        results = response.json()
        if not isinstance(results, list) or not results:
            return {}, 404

        wanted_title = normalize(title)
        wanted_author = normalize(author)

        def candidate_score(record: dict) -> float:
            candidate_title = normalize(clean_record_title(first_value(record, "title")))
            candidate_author = normalize(clean_record_author(first_value(record, "creator")))

            title_score = difflib.SequenceMatcher(None, wanted_title, candidate_title).ratio()
            if wanted_author:
                author_score = difflib.SequenceMatcher(None, wanted_author, candidate_author).ratio()
                return (title_score * 0.7) + (author_score * 0.3)
            return title_score

        record = max(results, key=candidate_score)
        clean_title = clean_record_title(first_value(record, "title"))
        clean_author = clean_record_author(first_value(record, "creator"))

        if not clean_title:
            return {}, 404

        summary = ""
        marc_links = record.get(dc_ns + "linkToMarc", [])
        marc_url = ""
        if marc_links:
            first_link = marc_links[0]
            if isinstance(first_link, dict):
                marc_url = str(first_link.get("@id", ""))

        if marc_url:
            try:
                marc_response = requests.get(
                    marc_url,
                    headers={"User-Agent": self.USER_AGENT},
                    timeout=(5, 20),
                )
                if marc_response.ok:
                    root = ET.fromstring(marc_response.content)
                    summary_parts = []
                    for datafield in root.iter(marc_ns + "datafield"):
                        if datafield.get("tag") == "520":
                            for subfield in datafield.iter(marc_ns + "subfield"):
                                if subfield.get("code") in {"a", "b"} and subfield.text:
                                    summary_parts.append(subfield.text.strip())
                            if summary_parts:
                                break
                    summary = " ".join(summary_parts)
            except (requests.RequestException, ET.ParseError):
                pass

        return {
            "Title": clean_title,
            "Author": clean_author,
            "Summary": summary,
        }, 200
