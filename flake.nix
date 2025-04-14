{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0-3.tar.gz";
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
      lib = nixpkgs.lib.extend (self: super: { custom = import ./lib { inherit (nixpkgs) lib; }; });

      forEachSystem =
        f:
        lib.genAttrs [ "aarch64-darwin" "aarch64-linux" ] (
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
        rec {
          default = deploy;
          deploy = pkgs.callPackage ./scripts/deploy.nix { };
          diskImage = self.nixosConfigurations.picache.config.system.build.diskImage;
        }
      );

      nixosConfigurations.picache = lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit inputs lib self;
          pubkeys = import ./pubkeys.nix;
        };
        modules = [ ./config ];
      };

      overlays = {
        default =
          final: prev:
          prev.lib.packagesFromDirectoryRecursive {
            callPackage = prev.lib.callPackageWith final;
            directory = ./pkgs;
          };
      };
    };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
