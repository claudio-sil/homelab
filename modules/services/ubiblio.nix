{ pkgs, config, ... }:

let
  py = pkgs.python3Packages;

  # fastapi-limiter is not packaged in nixpkgs, so we build it ourselves.
  # It's a small pure-python package (poetry-core build backend).
  fastapi-limiter = py.buildPythonPackage rec {
    pname = "fastapi-limiter";
    version = "0.1.6";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/7f/99/c7903234488d4dca5f9bccb4f88c2f582a234f0dca33348781c9cf8a48c6/fastapi_limiter-0.1.6.tar.gz";
      hash = "sha256-b1/ejv6+Euszhhvf+5EAn2mTaaPChizcfB2az5Ev9EM=";
    };

    nativeBuildInputs = [ py.poetry-core ];
    propagatedBuildInputs = [ py.redis py.fastapi ];
    pythonImportsCheck = [ "fastapi_limiter" ];
  };

  # Pinned upstream source (replaces the old runtime `git clone` in preStart,
  # so the exact code running is reproducible and content-addressed).
  ubiblio-src = pkgs.fetchFromGitHub {
    owner = "seanboyce";
    repo = "ubiblio";
    rev = "7b135056e405044458bbe71eb5883205316100bf"; # main, 2026-07-29 — bump deliberately
    hash = "sha256-wmVZXNQS3g1lIygW8VuMe8H7XAudetZhcLnPgSlkwCc=";
  };

  # NFC withdraw/return addon: adds one new route (GET /nfc/{bookId}) that
  # a phone tapping an NFC sticker on the physical book hits directly (via
  # an NDEF URI record written to the tag) — no companion app needed. It
  # toggles withdrawn/returned using uBiblio's own existing crud functions,
  # same ones the manual /withdraw and /return pages already use.
  #
  # Danacode fallback addon: Israeli Danacode barcodes aren't valid ISBNs,
  # so the existing Google Books/Open Library/Wikipedia chain never finds
  # them. Neither Danacode's own operator (D.A.N.A Systems) nor Simania
  # nor NLI's search API expose a way to look a book up BY its Danacode —
  # confirmed by hand against all three; it's only ever stored as metadata
  # on a record you already found some other way. So instead: when a scan
  # fails ISBN lookup, the UI offers a "look up by title" fallback that
  # queries the National Library of Israel by title (much better hit rate
  # on Hebrew/Israeli books than the existing providers), and the scanned
  # code gets stored on the new book's customField1 for reference.
  #
  # Both applied as an overlay on top of the pinned source rather than
  # editing ubiblio-src directly, since fetched store paths are immutable.
  ubiblio-src-patched = pkgs.runCommand "ubiblio-src-patched" { } ''
    cp -r ${ubiblio-src} $out
    chmod -R u+w $out

    cp ${./ubiblio-nfc-addon/nfc.py} $out/ubiblio/routers/nfc.py
    cp ${./ubiblio-nfc-addon/nfc_result.html} $out/templates/nfc_result.html

    # Wire the new router into main.py the same way the other five are.
    substituteInPlace $out/ubiblio/main.py \
      --replace-fail \
        "from .routers import auth, books, reading_lists, files, admin, federation" \
        "from .routers import auth, books, reading_lists, files, admin, federation, nfc" \
      --replace-fail \
        "app.include_router(federation.router)" \
        "app.include_router(federation.router)
app.include_router(nfc.router)"

    # NLI_API_KEY env var, same pattern as the existing GOOGLE_BOOKS_API_KEY.
    substituteInPlace $out/ubiblio/vars.py \
      --replace-fail \
        'GOOGLE_BOOKS_API_KEY = os.environ.get("GB_API", "")' \
        'GOOGLE_BOOKS_API_KEY = os.environ.get("GB_API", "")
NLI_API_KEY = os.environ.get("NLI_API_KEY", "")'

    # New provider method + service functions + route, each appended to
    # their existing file (avoids fragile mid-file insertion).
    cat ${./ubiblio-nfc-addon/nli_by_title_method.py} >> $out/ubiblio/routers/books/book_metadata_client.py
    cat ${./ubiblio-nfc-addon/service_nli_additions.py} >> $out/ubiblio/routers/books/service.py
    cat ${./ubiblio-nfc-addon/api_nli_route.py} >> $out/ubiblio/routers/books/api.py

    # Carry the scanned code forward on ISBN-lookup failure so the
    # title-fallback form (added to the templates below) knows what to
    # tag the eventual book with.
    substituteInPlace $out/ubiblio/routers/books/api.py \
      --replace-fail \
        'errors = ["ISBN " + str(isbn) + " not found -- try another."]
        context = {
            "errors": errors,
            "user": user,
            "request": request,
        }' \
        'errors = ["ISBN " + str(isbn) + " not found -- try another."]
        context = {
            "errors": errors,
            "code": isbn,
            "user": user,
            "request": request,
        }'

    # Title-fallback form + its JS, inserted into both the manual-add and
    # camera-scan templates (only rendered when "code" is present in the
    # template context, i.e. after a failed ISBN lookup).
    for tmpl in addisbn.html scanIsbn.html; do
      substituteInPlace $out/templates/$tmpl \
        --replace-fail \
          '    {% for error in errors %}
    <p style="color: red">{{ error }}</p>
    {% endfor %}' \
          "    {% for error in errors %}
    <p style=\"color: red\">{{ error }}</p>
    {% endfor %}
$(cat ${./ubiblio-nfc-addon/nli_fallback_form.html})" \
        --replace-fail \
          '{% endblock %}' \
          "$(cat ${./ubiblio-nfc-addon/nli_fallback_script.html})
{% endblock %}"
    done
  '';

  # Dedicated Python environment with uBiblio's actual runtime dependencies
  # (per its requirements.txt + the undeclared `ecdsa` import in vars.py).
  ubiblio-python = pkgs.python3.withPackages (ps: with ps; [
    fastapi
    uvicorn
    jinja2
    python-multipart
    pydantic
    requests
    aiofiles
    passlib
    python-jose
    sqlalchemy
    pymysql
    pillow
    redis
    rich
    ecdsa
    fastapi-limiter
  ]);
in
{
  # uBiblio's federation feature hard-requires `ecdsa` at startup (signing
  # self-test runs unconditionally), but nixpkgs flags it insecure due to
  # CVE-2024-23342 (ECDSA signing timing side-channel). Explicitly allowing
  # just this package rather than disabling the insecure-package check
  # globally. Revisit if/when this box is exposed to the internet.
  nixpkgs.config.permittedInsecurePackages = [
    "python3.14-ecdsa-0.19.2"
  ];

  # 1. Dedicated system user and persistent directory
  users.users.ubiblio = {
    isSystemUser = true;
    group = "ubiblio";
    home = "/var/lib/ubiblio";
    createHome = true;
  };
  users.groups.ubiblio = {};

  # Writable state lives entirely under /var/lib/ubiblio/data;
  # the app source itself is an immutable, read-only Nix store path.
  systemd.tmpfiles.rules = [
    "d /var/lib/ubiblio 0750 ubiblio ubiblio -"
    "d /var/lib/ubiblio/data 0750 ubiblio ubiblio -"
    "d /var/lib/ubiblio/data/run 0750 ubiblio ubiblio -"
  ];

  # 2. Native systemd service running straight from the Nix store
  systemd.services.ubiblio = {
    description = "uBiblio Personal Library Manager";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      # Empty string = English (root templates/ dir). Only other value
      # supported upstream right now is "FR" (templates/FR/). "EN" is NOT
      # a valid value here - there is no templates/EN directory.
      LANGUAGE = "";
      USE_REDIS = "false";
      DB_LOCATION = "/var/lib/ubiblio/data/sql_app.db";
      SECRET_KEY_FILE = "/var/lib/ubiblio/data/secret_key.txt";
      SIGNING_KEY_FILE = "/var/lib/ubiblio/data/sign_key.txt";
      VERIFY_KEY_FILE = "/var/lib/ubiblio/data/verify_key.txt";
      # CREATE_ADMIN_USER / ADMIN_USERNAME / ADMIN_PASSWORD come from the
      # sops-nix template (see EnvironmentFile below) — not plaintext here.
    };

    # uBiblio shells out to `openssl rand -hex 32` as a fallback for
    # generating its secret/signing keys on first run.
    path = [ pkgs.openssl ];

    # uBiblio writes covers, ebook files, thumbnails, and DB exports using
    # paths relative to its CWD (e.g. `./static/bookImages/...`,
    # `./static/eBooks/...`, `export/...`). Since the app source is an
    # immutable, read-only store path, we build a writable "run" directory
    # each start: read-only pieces (the Python package, templates, bundled
    # static assets) are symlinked/copied in, while bookImages/, eBooks/,
    # and export/ are real directories under /var/lib/ubiblio that
    # persist across restarts and rebuilds.
    preStart = ''
      RUN_DIR=/var/lib/ubiblio/data/run

      ln -sfn ${ubiblio-src-patched}/ubiblio "$RUN_DIR/ubiblio"
      ln -sfn ${ubiblio-src-patched}/templates "$RUN_DIR/templates"

      mkdir -p "$RUN_DIR/static"
      # cp -r preserves the SOURCE directory's permission bits, and
      # everything in /nix/store is read-only by design -- so a copied-in
      # bundled-asset directory (assets/, images/, etc.) ends up read-only
      # too. Left alone, that breaks *future* re-copies on the next
      # rebuild (cp can't overwrite files inside a read-only directory).
      # Force the whole tree writable before copying so this can't recur.
      chmod -R u+w "$RUN_DIR/static" 2>/dev/null || true
      find ${ubiblio-src-patched}/static -mindepth 1 -maxdepth 1 ! -name bookImages ! -name eBooks \
        -exec cp -rf {} "$RUN_DIR/static/" \;
      mkdir -p "$RUN_DIR/static/bookImages" "$RUN_DIR/static/eBooks" "$RUN_DIR/export"
      # mkdir -p is a no-op if these already exist, which means a stale
      # read-only mode from an earlier preStart version (e.g. one that
      # copied these in from the read-only /nix/store instead of
      # creating them fresh) would silently persist. Force them writable
      # every start so that can't happen again.
      chmod u+rwx "$RUN_DIR/static/bookImages" "$RUN_DIR/static/eBooks" "$RUN_DIR/export"
    '';

    serviceConfig = {
      Type = "simple";
      User = "ubiblio";
      Group = "ubiblio";
      WorkingDirectory = "/var/lib/ubiblio/data/run";
      ExecStart = "${ubiblio-python}/bin/uvicorn ubiblio.main:app --host 0.0.0.0 --port 8000 --forwarded-allow-ips '*' --proxy-headers";
      Restart = "always";
      RestartSec = "10s";
      EnvironmentFile = config.sops.templates."ubiblio.env".path;

      # Security & sandboxing — the store path is read-only regardless,
      # this just also locks down the rest of the filesystem.
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "/var/lib/ubiblio/data" ];
      NoNewPrivileges = true;
    };
  };

  # Port 8000 is no longer opened directly — traffic now goes through
  # Caddy (modules/services/caddy.nix) on :8443, which gets you HTTPS
  # (needed for camera access) and loopback-proxies to this service.
}
