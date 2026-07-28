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

  # 3. Disable GUI / X11 completely for a pure headless setup
  services.xserver.enable = false;

  # 4. Passwordless Sudo
  security.sudo.wheelNeedsPassword = false;

  # 5. SSH Daemon Settings
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # 6. User Account Setup
  users.users.mayordomo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "disk" "networkmanager" ];
    openssh.authorizedKeys.keys = [

    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOuCLnuBe4jS9FefBnQpg8liL2CQbVR2Afh2Q5KOZaG claudio@dio-olamot.com"
    ];
  };

  # 7. Enable Flakes on target nodes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 8. Essential Headless Server Tools
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
}
