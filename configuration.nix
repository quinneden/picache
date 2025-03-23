{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./modules/ssh.nix
    ./modules/rpi.nix
    ./modules/sops.nix
    ./modules/hardware.nix
    ./modules/zsh.nix
  ];

  nixpkgs.overlays = [
    # Workaround: https://github.com/NixOS/nixpkgs/issues/154163
    # modprobe: FATAL: Module sun4i-drm not found in directory
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  boot.postBootCommands = with pkgs; ''
    set -Eeuf -o pipefail

    if [ -f /nix-path-registration ]; then
      rootPart=$(${pkgs.util-linux}/bin/findmnt -nvo SOURCE /)
      firmwareDevice=$(lsblk -npo PKNAME $rootPart)
      partNum=$(
        lsblk -npo MAJ:MIN "$rootPart" |
        ${gawk}/bin/awk -F: '{print $2}' |
        tr -d '[:space:]'
      )

      echo ',+,' | sfdisk -N"$partNum" --no-reread "$firmwareDevice"
      ${parted}/bin/partprobe
      ${btrfs-progs}/bin/btrfs filesystem resize max /

      # Register the contents of the initial Nix store
      ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

      rm -f /nix-path-registration
    fi
  '';

  users.users.qeden = {
    isNormalUser = true;
    passwordFile = config.sops.secrets."passwords/quinn".path;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  users.users.root.passwordFile = config.sops.secrets."passwords/root".path;

  security.sudo.wheelNeedsPassword = false;

  networking = {
    hostName = "picache";
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = true;
      end0.useDHCP = true;
    };

    wireless = {
      enable = true;
      networks = {
        ${inputs.secrets.wifi.ssid}.psk = inputs.secrets.wifi.password;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    cachix
    eza
    fd
    fzf
    git
    git-crypt
    gnupg
    gptfdisk
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
      access-tokens = [ "github=@${config.sops.secrets.github_token.path}" ];
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

  system.build.btrfsImage = import ./lib/make-btrfs-disk-image.nix {
    inherit config pkgs;
  };
}
