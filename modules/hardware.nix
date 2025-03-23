{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  nixpkgs.overlays =
    let
      ubootWithBtrfsAndZstd = oldAttrs: {
        extraConfig = ''
          CONFIG_CMD_BTRFS=y
          CONFIG_ZSTD=y

          CONFIG_BOOTCOMMAND="setenv boot_prefixes /@boot/ /@/ /boot/ /; run distro_bootcmd;"
        '';
      };
    in
    [
      (self: super: {
        ubootRaspberryPi3_64bit = super.ubootRaspberryPi3_64bit.overrideAttrs ubootWithBtrfsAndZstd;
        ubootRaspberryPi4_64bit = super.ubootRaspberryPi4_64bit.overrideAttrs ubootWithBtrfsAndZstd;
      })
    ];

  boot = {
    # console=ttyAMA0 seems necessary for kernel boot messages in qemu
    kernelParams = [
      "console=ttyS0,115200n8"
      "console=ttyAMA0,115200n8"
      "console=tty0"
      "root=/dev/disk/by-label/NIXOS_SD"
      "rootfstype=btrfs"
      "rootflags=subvol=@"
      "rootwait"
    ];
    initrd.kernelModules = [
      "zstd"
      "btrfs"
    ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = 20;
      };
    };
  };

  fileSystems =
    let
      opts = [
        "noatime"
        "ssd_spread"
        "autodefrag"
        "discard=async"
        "compress-force=zstd"
      ];
      fsType = "btrfs";
      device = "/dev/disk/by-label/nixos";
    in
    {
      "/" = {
        inherit fsType device;
        options = opts ++ [ "subvol=@" ];
      };
      "/boot" = {
        inherit fsType device;
        options = opts ++ [ "subvol=@boot" ];
      };
      "/gnu" = {
        inherit fsType device;
        options = opts ++ [ "subvol=@gnu" ];
      };
      "/nix" = {
        inherit fsType device;
        options = opts ++ [ "subvol=@nix" ];
      };
      "/var" = {
        inherit fsType device;
        options = opts ++ [ "subvol=@var" ];
      };
      "/home" = {
        inherit fsType device;
        options = opts ++ [ "subvol=@home" ];
      };
      "/.snapshots" = {
        inherit fsType device;
        options = opts ++ [ "subvol=@snapshots" ];
      };
      "/boot/firmware" = {
        device = "/dev/disk/by-label/FIRMWARE";
        fsType = "vfat";
        options = [
          "nofail"
          "noauto"
        ];
      };
    };

  zramSwap = {
    enable = true;
    memoryPercent = 200;
    algorithm = "zstd";
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
