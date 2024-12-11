{
  lib,
  pkgs,
  config,
  inputs,
  secrets,
  ...
}:
{
  # imports = [ inputs.attic.nixosModules.atticd ];

  services.minio = {
    enable = true;
    dataDir = [ "/var/pub-cache" ];
    rootCredentialsFile = (
      pkgs.writeText "minio-root-credentials" ''
        MINIO_ROOT_USER=${secrets.minio.accessKey}
        MINIO_ROOT_PASSWORD=${secrets.minio.secretKey}
      ''
    );
  };

  services.atticd = {
    enable = true;

    # Replace with absolute path to your environment file
    environmentFile = "${../.secrets/keys/atticd.env}";

    settings = {
      listen = "[::]:8080";

      jwt = { };

      # Data chunking
      #
      # Warning: If you change any of the values here, it will be
      # difficult to reuse existing chunks for newly-uploaded NARs
      # since the cutpoints will be different. As a result, the
      # deduplication ratio will suffer for a while after the change.
      chunking = {
        # The minimum NAR size to trigger chunking
        #
        # If 0, chunking is disabled entirely for newly-uploaded NARs.
        # If 1, all NARs are chunked.
        nar-size-threshold = 64 * 1024; # 64 KiB

        # The preferred minimum size of a chunk, in bytes
        min-size = 16 * 1024; # 16 KiB

        # The preferred average size of a chunk, in bytes
        avg-size = 64 * 1024; # 64 KiB

        # The preferred maximum size of a chunk, in bytes
        max-size = 256 * 1024; # 256 KiB
      };
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."10.0.0.101" = {
      locations."/".proxyPass = "http://${config.services.atticd.settings.listen}";
    };
  };
}
