{ self, inputs, ... }:

{
  flake.nixosModules.nectarConfiguration =
    { config, lib, pkgs, ... }:
    {
      imports = [
        self.nixosModules.nectarHardware
        self.nixosModules.core
        self.nixosModules.tailscale
      ];

      # 1. System Hostname & State Version
      networking.hostName = "nectar";

      # State version for 25.11 release
      system.stateVersion = "25.11";

      # 2. Localization & Timezone
      time.timeZone = "Asia/Tel_Aviv";
      i18n.defaultLocale = "en_US.UTF-8";

      # 3. Host-specific Packages
      environment.systemPackages = with pkgs; [
        # Host-specific tools can go here
      ];
    };
}
