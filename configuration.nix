{
  pkgs,
  secrets,
  ...
}:
{
  nixpkgs.overlays = [
    # Workaround: https://github.com/NixOS/nixpkgs/issues/154163
    # modprobe: FATAL: Module sun4i-drm not found in directory
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  users.users.qeden = {
    isNormalUser = true;
    initialPassword = "${secrets.passwords.qeden}";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  users.users.root.initialPassword = "${secrets.passwords.root}";

  security.sudo.wheelNeedsPassword = false;

  networking = {
    hostName = "picache";
    useDHCP = false;
    interfaces.wlan0.useDHCP = true;
    wireless = {
      enable = true;
      networks = {
        "${secrets.wifi.ssid}".psk = "${secrets.wifi.password}";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    eza
    fzf
    git
    git-crypt
    cachix
    gptfdisk
    libraspberrypi
    raspberrypi-eeprom
    zoxide
  ];

  documentation.nixos.enable = false;

  nix = {
    channel.enable = false;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1d";
    };

    optimise = {
      automatic = true;
      dates = [ "daily" ];
    };

    settings = {
      access-tokens = [ "github=${secrets.github.token}" ];
      experimental-features = "nix-command flakes";
      extra-substituters = [
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      secret-key-files = /var/picache-secret-key-1.pem;
      trusted-users = [ "qeden" ];
      auto-optimise-store = true;
      warn-dirty = false;
    };
  };

  system.stateVersion = "25.05";
}
