{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0-2.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      url = "git+ssh://git@github.com/quinneden/secrets.git?ref=main&shallow=1";
      inputs = { };
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      self,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      forEachSystem =
        f:
        lib.genAttrs
          [
            "aarch64-darwin"
            "aarch64-linux"
          ]
          (
            system:
            f {
              pkgs = import nixpkgs {
                inherit system;
                overlays = [ self.overlays.default ];
              };
            }
          );
    in
    {
      packages = forEachSystem (
        { pkgs }:
        {
          sdImage =
            let
              imageConfig = self.nixosConfigurations.picache.extendModules {
                modules = [ inputs.raspberry-pi-nix.nixosModules.sd-image ];
              };
            in
            imageConfig.config.system.build.sdImage;

          deploy = pkgs.callPackage ./scripts/deploy.nix { };

          rpi4-uefi-firmware-images = pkgs.callPackage ./pkgs/rpi4-uefi-firmware-images.nix { };
        }
      );

      nixosConfigurations.picache = lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit inputs lib;
          pubkeys = import ./pubkeys.nix;
        };
        modules = [ ./config ];
      };

      overlays = {
        default = final: prev: {
          rpi4-uefi-firmware-images = prev.callPackage ./pkgs/rpi4-uefi-firmware-images.nix { };
        };
      };
    };

  nixConfig = {
    extra-substituters = [
      "ssh-ng://nix-ssh@picache"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
