{ config, ... }:

{
  # Decrypt using nectar's own SSH host key (already exists, no extra key
  # management needed) so secrets are available automatically at boot.
  # Claudio's personal key is also a recipient in .sops.yaml, so `sops
  # secrets.yaml` can be edited directly from his own machine too.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.defaultSopsFile = ../secrets.yaml;

  sops.secrets.ubiblio_admin_username = {};
  sops.secrets.ubiblio_admin_password = {};

  # Renders a plain KEY=VALUE env file at runtime (decrypted, root-only,
  # never touches the git repo or the Nix store) that ubiblio.nix points
  # its systemd EnvironmentFile at.
  sops.templates."ubiblio.env" = {
    content = ''
      CREATE_ADMIN_USER=true
      ADMIN_USERNAME=${config.sops.placeholder.ubiblio_admin_username}
      ADMIN_PASSWORD=${config.sops.placeholder.ubiblio_admin_password}
    '';
    restartUnits = [ "ubiblio.service" ];
  };
}
