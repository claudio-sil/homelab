{ pkgs, ... }:

{
  # 1. Enable Podman container engine
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # 2. Configure persistent storage directory for uBiblio data & database
  systemd.tmpfiles.rules = [
    "d /var/lib/ubiblio 0755 root root -"
  ];

  # 3. Define the uBiblio OCI Container
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.ubiblio = {
    image = "seanboyce/ubiblio:latest";
    autoStart = true;
    ports = [
      "8080:8000" # Maps http://nectar.local:8080 to internal port 8000
    ];
    volumes = [
      "/var/lib/ubiblio:/app/data" # Persists database and uploaded book assets
    ];
    environment = {
      LANGUAGE = "EN"; # Change to "FR" if you prefer French
    };
  };

  # 4. Open firewall port for uBiblio web access
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
