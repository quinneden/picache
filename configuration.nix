{
  pkgs,
  inputs,
  secrets,
  ...
}:
{
  users.users.qeden = {
    isNormalUser = true;
    initialPassword = "${secrets.defaultUserPassword}";
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  networking = {
    hostName = "picache";

    networkmanager.enable = true;
    networkmanager.wifi.backend = "iwd";

    wireless.iwd = {
      enable = true;
      settings.General.EnableNetworkConfiguration = true;
    };
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  environment.systemPackages = [
    inputs.nix-shell-scripts.packages.${pkgs.system}.default
    pkgs.git
  ];

  documentation.nixos.enable = false;

  nix.settings = {
    access-tokens = [ "github=${secrets.github.token}" ];
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  system.stateVersion = "25.05";
}
