
    def nli_by_title(self, title: str) -> tuple[dict[str, str], int | None]:
        """
        Title-based lookup against the National Library of Israel. Used
        as a fallback for books identified by Israeli Danacode, which
        has no public reverse-lookup service of its own (confirmed by
        hand against both NLI's and Simania's APIs: both store Danacode
        as metadata on a record you already found some other way,
        neither lets you search BY it). Given a title instead, this gets
        much better hit rates on Hebrew/Israeli books than Google Books,
        Open Library, or Wikipedia.
        """
        import re
        import xml.etree.ElementTree as ET

        from ...vars import NLI_API_KEY

        if not NLI_API_KEY:
            return {}, None

        dc_ns = "http://purl.org/dc/elements/1.1/"
        marc_ns = "{http://www.loc.gov/MARC21/slim}"

        response = requests.get(
            "https://api.nli.org.il/openlibrary/search",
            params={
                "api_key": NLI_API_KEY,
                "query": f"title,contains,{title}",
                "output_format": "json",
            },
            headers={"User-Agent": self.USER_AGENT},
        )
        if not response.ok:
            return {}, response.status_code

        results = response.json()
        if not results:
            return {}, 404

        record = results[0]

        raw_title = record.get(dc_ns + "title", [{}])[0].get("@value", "")
        # NLI titles come as "Title / author statement." -- keep only the
        # title part (matches MARC 245 $a, before the $c author statement).
        clean_title = raw_title.split(" / ")[0].strip().rstrip(",.")

        raw_creator = record.get(dc_ns + "creator", [{}])[0].get("@value", "")
        # Typical shape: "Last, First, 1985- author$$QLast, First, 1985-"
        # Take the part before the $$Q duplicate, strip the trailing
        # birth-year/role annotation.
        creator_head = raw_creator.split("$$Q")[0]
        clean_author = re.sub(r",?\s*\d{4}-\s*\S*$", "", creator_head).strip().rstrip(",")

        summary = ""
        marc_links = record.get(dc_ns + "linkToMarc", [{}])
        marc_url = marc_links[0].get("@id", "") if marc_links else ""
        if marc_url:
            try:
                marc_response = requests.get(marc_url, headers={"User-Agent": self.USER_AGENT})
                if marc_response.ok:
                    root = ET.fromstring(marc_response.content)
                    for datafield in root.iter(marc_ns + "datafield"):
                        if datafield.get("tag") == "520":
                            for subfield in datafield.iter(marc_ns + "subfield"):
                                if subfield.get("code") == "a":
                                    summary = subfield.text or ""
                                    break
                            break
            except Exception:
                pass  # summary is a nice-to-have -- never block the lookup on it

        if not clean_title:
            return {}, 404

        book = {
            "Title": clean_title,
            "Author": clean_author,
            "Summary": summary,
        }
        return book, 200
