{
  inputs,
  pkgs,
  pubkeys,
  ...
}:
{
  imports = [
    ./core
    ./optional/time-machine.nix
    ./optional/zsh.nix
    inputs.lix-module.nixosModules.default
  ];

  hardware.enableRedistributableFirmware = true;

  boot = {
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd.availableKernelModules = [ "xhci_pci" ];
  };

  nixpkgs = {
    overlays = [
      # Workaround: https://github.com/NixOS/nixpkgs/issues/154163
      (final: super: {
        makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
      })
    ];
  };

  zramSwap = {
    enable = true;
    memoryPercent = 200;
  };

  users.users.qeden = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    bat
    btrfs-progs
    cachix
    eza
    fd
    fzf
    git
    git-crypt
    gnupg
    gptfdisk
    libraspberrypi
    micro
    raspberrypi-eeprom
    ripgrep
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
      access-tokens = [ "github=${inputs.secrets.git.token}" ];
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [ "https://nix-community.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = [
        "qeden"
        "nix-ssh"
      ];
      warn-dirty = false;
    };
    sshServe = {
      enable = true;
      keys = [ pubkeys."quinn@macmini-m4" ];
      protocol = "ssh-ng";
      write = true;
    };
  };

  system.stateVersion = "25.05";
}
