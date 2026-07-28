{ pkgs, ... }:

let
  # Dedicated Python environment with uBiblio dependencies
  ubiblio-python = pkgs.python3.withPackages (ps: with ps; [
    fastapi
    uvicorn
    jinja2
    python-multipart
    pydantic
    requests
    aiofiles
    sqlite3
    passlib
    pyjwt
  ]);
in
{
  # 1. Dedicated system user and persistent directory
  users.users.ubiblio = {
    isSystemUser = true;
    group = "ubiblio";
    home = "/var/lib/ubiblio";
    createHome = true;
  };
  users.groups.ubiblio = {};

  # Ensure storage directories exist with proper permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/ubiblio 0755 ubiblio ubiblio -"
    "d /var/lib/ubiblio/app 0755 ubiblio ubiblio -"
    "d /var/lib/ubiblio/data 0755 ubiblio ubiblio -"
  ];

  # 2. Native Systemd Service (replaces virtualisation.oci-containers)
  systemd.services.ubiblio = {
    description = "uBiblio Personal Library Manager";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      LANGUAGE = "EN";
      DATA_DIR = "/var/lib/ubiblio/data";
    };

    serviceConfig = {
      Type = "simple";
      User = "ubiblio";
      Group = "ubiblio";
      WorkingDirectory = "/var/lib/ubiblio/app";
      ExecStart = "${ubiblio-python}/bin/uvicorn main:app --host 0.0.0.0 --port 8000";
      Restart = "always";
      RestartSec = "10s";

      # Security & sandboxing
      ProtectSystem = "full";
      ProtectHome = true;
      PrivateTmp = true;
    };

    # Clone/update source code on start if not already cloned
    preStart = ''
      if [ ! -f "/var/lib/ubiblio/app/main.py" ]; then
        ${pkgs.git}/bin/git clone https://github.com/seanboyce/ubiblio.git /var/lib/ubiblio/app
      fi
    '';
  };

  # 3. Open firewall port for web access
  networking.firewall.allowedTCPPorts = [ 8000 ];
}
