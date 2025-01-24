{ lib, ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" ];
  hardware.enableRedistributableFirmware = true;

  raspberry-pi-nix.board = "bcm2711";

  hardware.raspberry-pi = {
    config = {
      pi4 = {
        options.arm_boost = {
          enable = true;
          value = true;
        };
      };

      all = {
        base-dt-params = {
          BOOT_UART = {
            value = 1;
            enable = true;
          };
          uart_2ndstage = {
            value = 1;
            enable = true;
          };
        };

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

  networking.useDHCP = lib.mkDefault false;
  networking.interfaces.end0.useDHCP = lib.mkDefault true;
  networking.interfaces.wlan0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
