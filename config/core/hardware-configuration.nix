{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "uas" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3ebfc6a7-9b43-4553-b823-30625c774fea";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "subvol=@"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/3ebfc6a7-9b43-4553-b823-30625c774fea";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "subvol=@home"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/3ebfc6a7-9b43-4553-b823-30625c774fea";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "subvol=@nix"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/12CE-A600";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
