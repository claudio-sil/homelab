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

    serviceConfig = {
      Type = "simple";
      User = "ubiblio";
      Group = "ubiblio";
      WorkingDirectory = "${ubiblio-src}";
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

  # 3. Open firewall port for web access (LAN only for now)
  networking.firewall.allowedTCPPorts = [ 8000 ];
}
