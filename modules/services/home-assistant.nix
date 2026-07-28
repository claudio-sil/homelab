{ pkgs, ... }:

{
  # 1. Enable Home Assistant Service
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Frequently used integrations
      "default_config"
      "met"
      "esphome"
      "shelly"
      "zha" # Zigbee Home Automation (if you use a USB dongle later)
    ];

    # Configuration written to configuration.yaml
    config = {
      # Basic setup
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "Asia/Tel_Aviv"; # Change to your local timezone (e.g. "America/New_York")
      };

      # Enables basic web UI features
      frontend = {};
      http = {
        # Allow connections from your local subnet
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" "::1" ];
      };
    };
  };

  # 2. Open firewall port for Home Assistant
  networking.firewall.allowedTCPPorts = [ 8123 ];
}
