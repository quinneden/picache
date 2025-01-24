{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."10.0.0.101" = {
      locations."/" = {
        root = "/var/keys";
        proxyPass = "http://0.0.0.0:2515";
      };
    };
  };
}
