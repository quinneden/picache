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
    postBootCommands = ''
      if [[ ! -f /etc/nix/flake.nix ]]; then
        ${lib.getExe pkgs.git} clone https://github.com/quinneden/picache /etc/nixos
      else
        cd /etc/nixos; ${lib.getExe pkgs.git} pull
      fi
    '';
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
    initialPassword = "${secrets.defaultUserPassword}";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJyLtibXqcDXRQ8DzDUbVw71YA+k+L7fH7H3oPYyjFII"
    ];
  };

  users.users.root.initialPassword = "${secrets.defaultRootPassword}";

  security.sudo.wheelNeedsPassword = false;

  networking = {
    hostName = "picache";
    wireless.enable = true;
    useDHCP = false;
    interfaces.wlan0.useDHCP = true;
    wireless.networks = {
      "${secrets.wifi.ssid}".psk = "${secrets.wifi.password}";
    };
  };

  programs.ssh.startAgent = true;
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  environment.systemPackages = with pkgs; [
    git
    git-crypt
    gptfdisk
    micro
  ];

  documentation.nixos.enable = false;

  nix.settings = {
    access-tokens = [ "github=${secrets.github.token}" ];
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    warn-dirty = false;
  };

  system.stateVersion = "25.05";
}
