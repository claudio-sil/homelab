{ ... }:

{
  # Shared reverse proxy for services on nectar. Uses Caddy's built-in
  # "internal" TLS issuer — a locally-trusted CA it generates itself,
  # good enough for LAN use (browsers will show a one-time warning per
  # device until/unless you trust Caddy's root CA) without needing a
  # real domain or port-forwarding. This is what gets camera/microphone
  # access (getUserMedia) working for uBiblio's barcode scanner, which
  # browsers refuse to allow over plain HTTP.
  #
  # Each service gets its own port rather than name-based (SNI) routing,
  # since LAN mDNS (nectar.local) isn't reliably resolving on all client
  # devices yet — bare-IP HTTPS still works fine per-port.
  #
  # When Tailscale comes into the picture later, this can either stay
  # as-is (reachable only over the tailnet) or be swapped for Tailscale
  # Funnel/serve handling TLS instead — worth revisiting then rather
  # than pre-optimizing for it now.
  services.caddy = {
    enable = true;

    # Skip Caddy's attempt to install its self-signed root CA into the
    # OS-wide trust store — it was failing (missing `certutil`, and the
    # `tee` fallback also errored), which was breaking cert issuance
    # entirely. We don't want it installed server-side anyway; each
    # client device trusts it manually (or just clicks through the
    # browser warning) instead.
    globalConfig = ''
      pki {
        ca local {
          install_trust false
        }
      }
    '';

    virtualHosts = {
      ":8443" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8000
        '';
      };
      ":8444" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8123
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8443 8444 ];
}
