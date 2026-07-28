{ self, ... }: {

  # Expose as self.nixosModules.core so host configs can import it
  flake.nixosModules.core = { pkgs, ... }: {
    
    # 1. Bootloader Configuration (EFI / systemd-boot)
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # 2. Networking & mDNS Resolution (.local domain)
    networking.networkmanager.enable = true;
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # 3. Networking
    networking.networkmanager.enable = true;

    # 4. Disable GUI / X11 completely for a pure headless setup
    services.xserver.enable = false;

    # 5. Passwordless Sudo (Allows desktop to run remote nixos-rebuild switch)
    security.sudo.wheelNeedsPassword = false;

    # 6. SSH Daemon Settings
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false; # Keys only for security
        PermitRootLogin = "prohibit-password";
      };
    };

    # 7. User Account Setup
    users.users.mayordomo = {
      isNormalUser = true;
      extraGroups = [ "wheel" "disk" "networkmanager" ];
      openssh.authorizedKeys.keys = [
        # PASTE YOUR DESKTOP'S SSH PUBLIC KEY HERE (~/.ssh/id_ed25519.pub from mictlan)
        " ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOuCLnuBe4jS9FefBnQpg8liL2CQbVR2Afh2Q5KOZaG claudio@dio-olamot.com"
      ];
    };

    # 8. Enable Flakes on target nodes
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # 9. Essential Headless Server Tools
    environment.systemPackages = with pkgs; [
      wget
      curl
      git
      vim
      btop
      bat
      tree
      htop
    ];
  };
}
