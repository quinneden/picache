{
  lib,
  pkgs,
  inputs,
  secrets,
  ...
}:
{
  imports = [
    inputs.lix-module.nixosModules.default
  ];

  raspberry-pi-nix = {
    board = "bcm2711";
  };

  hardware.enableRedistributableFirmware = true;

  hardware.raspberry-pi = {
    config = {
      pi4 = {
        options.arm_boost = {
          enable = true;
          value = true;
        };
      };

      all = {
        dt-overlays = {
          disable-bt = {
            enable = true;
            params = { };
          };
        };
      };
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 200;
  };

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
    # wireless.iwd = {
    #   enable = true;
    #   settings = {
    #     General.EnableNetworkConfiguration = true;
    #     Settings.AutoConnect = true;
    #   };
    # };
  };

  environment.systemPackages = with pkgs; [
    git
    git-crypt
    gptfdisk
    libraspberrypi
    raspberrypi-eeprom
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
      extra-substituters = [ "https://nix-community.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = [ "quinn" ];
      auto-optimise-store = true;
      warn-dirty = false;
    };
  };

  system.stateVersion = "25.05";
}
