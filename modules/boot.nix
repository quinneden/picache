{ pkgs, ... }:
{
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
      "usb_storage"
    ];

    loader = {
      timeout = 0;
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    # loader = {
    # timeout = 1;
    # systemd-boot.enable = true;
    # efi.canTouchEfiVariables = true;
    # };

    # extraModprobeConfig = ''
    #   options cfg80211 ieee80211_regdom="US"
    # '';
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    "/nix" = {
      device = "/dev/disk/by-label/nix";
      fsType = "ext4";
      neededForBoot = true;
      options = [ "noatime" ];
    };
  };
}
