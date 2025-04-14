{ inputs, ... }:
let
  secretsPath = "${inputs.secrets}/sops";
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = "${secretsPath}/default.yaml";
    validateSopsFiles = false;

    age = {
      sshKeyPaths = [ "/home/qeden/.ssh/id_ed25519" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    secrets = {
      "github_token" = { };
      "tailscale_auth_keys/picache" = { };
    };
  };
}
