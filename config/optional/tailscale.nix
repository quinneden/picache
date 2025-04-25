{ config, ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets."tailscale_auth_keys/picache".path;
    authKeyParameters.preauthorized = true;
    extraUpFlags = [
      "--accept-dns=true"
      "--accept-routes=true"
    ];
  };
}
