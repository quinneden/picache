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

    useDHCP = false;
    interfaces.wlan0.useDHCP = true;

    networkmanager.enable = true;
    networkmanager.wifi.backend = "iwd";

    wireless.iwd = {
      enable = true;
      settings.General.EnableNetworkConfiguration = true;
    };
  };

  systemd.services.iwd.serviceConfig.Restart = "always";

  hardware = {
    enableRedistributableFirmware = true;
    firmware = [ pkgs.wireless-regdb ];
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  environment.systemPackages = with pkgs; [
    inputs.nix-shell-scripts.packages.${pkgs.system}.default
    git-crypt
    git
  ];

  documentation.nixos.enable = false;

  nix.settings = {
    access-tokens = [ "github=${secrets.github.token}" ];
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  system.stateVersion = "25.05";
}
