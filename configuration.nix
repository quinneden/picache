{
  lib,
  pkgs,
  inputs,
  secrets,
  ...
}:
{
  imports = [ inputs.nixos-hardware.nixosModules.raspberry-pi-4 ];

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    supportedFilesystems.zfs = lib.mkForce false;
    # postBootCommands = ''
    #   if [[ ! -f /etc/nix/flake.nix ]]; then
    #     ${lib.getExe pkgs.git} clone https://github.com/quinneden/picache /etc/nixos
    #   else
    #     cd /etc/nixos; ${lib.getExe pkgs.git} pull
    #   fi
    # '';
  };

  hardware.enableRedistributableFirmware = true;

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
    #   networks = {
    #     "${secrets.wifi.ssid}".passphrase = "${secrets.wifi.password}";
    #   };
    # };
  };

  environment.systemPackages = with pkgs; [
    git
    git-crypt
    gptfdisk
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
      trusted-users = [ "quinn" ];
      auto-optimise-store = true;
      warn-dirty = false;
    };
  };

  system.stateVersion = "25.05";
}
