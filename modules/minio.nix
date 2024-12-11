{
  pkgs,
  secrets,
  config,
  ...
}:
{
  services.minio = {
    enable = true;
    dataDir = [ "/var/pub-cache" ];
    listenAddress = "0.0.0.0:9898";
    consoleAddress = ":9899";
    rootCredentialsFile = (
      pkgs.writeText "minio-root-credentials" ''
        MINIO_ROOT_USER=${secrets.minio.accessKey}
        MINIO_ROOT_PASSWORD=${secrets.minio.secretKey}
      ''
    );
  };

  # services.nginx = {
  #   virtualHosts."picache.qeden.me" = {
  #     locations."/" = {
  #       root = "/var/pub-cache";
  #       proxyPass = "http://${config.services.minio.listenAddress}";
  #     };
  #   };
  # };

  # networking.firewall.allowedTCPPorts = [
  #   config.services.nginx.defaultHTTPListenPort
  #   9898
  #   9899
  # ];
}
